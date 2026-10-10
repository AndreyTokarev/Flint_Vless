# The current server disappears after a subscription update: the router switches to the first one.
. "$(dirname "$0")/lib.sh"
echo "== failover: current server gone after an update"
save_state
if [ -z "$(first_sub_url)" ]; then echo "  skip: the router has no subscription"; finish; exit; fi
check "unknown server code is rejected" fails flint-node use no-such-server
first="$(flint-node codes | head -n1)"
# A fake server in the last subscription's block, so the next update drops it.
f="$(ls /etc/xray/nodes.d/*.conf 2>/dev/null | tail -n1)"
[ -n "$f" ] || f=/etc/xray/nodes.conf
line="$(grep -v -E '^[[:space:]]*(#|$)' "$f" | head -n1)"
echo "zzgone ${line#* }" >> "$f"
flint-node use zzgone >/dev/null 2>&1
check "fake server is current" current_is zzgone
flint-sub-update > /tmp/flint-test-case.log 2>&1
check "update reports the switch" grep -q 'больше нет\|is gone' /tmp/flint-test-case.log
# The fake server is gone; the router is on some real server of the list. Which one depends on the order
# of the files and, with probe-mode=fastest, on the measured times, so the exact code is not asserted.
echo "  (current после обновления: [$(flint-node current)], zzgone в списке: $(flint-node codes | grep -c zzgone))"
check "the fake server is no longer current" fails current_is zzgone
check "the router is on a server from the list" sh -c 'flint-node codes | grep -qx "$(flint-node current)"'
vpn_mode
rm -f /tmp/flint-test-case.log
finish
