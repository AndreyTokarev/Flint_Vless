# Install from the kit with no servers and no SUB_URL: devices go online directly.
# Usage: sh empty.sh <kit dir>
. "$(dirname "$0")/lib.sh"
KIT="${1:?kit dir}"
echo "== empty: install without servers"
save_state
go_empty
mkdir -p "$KIT/config"
rm -f "$KIT/config/"*
sed 's/^SUB_URL=.*/SUB_URL=/' /etc/xray/flint.env > "$KIT/config/flint.env"
sh "$KIT/install.sh" > /tmp/flint-test-install.log 2>&1
rc=$?
check "install succeeds" [ "$rc" = 0 ]
check "install reports no servers" grep -q 'VPN: no servers yet' /tmp/flint-test-install.log
direct_mode
check "no subscription cron job" fails sub_cron
/etc/init.d/xray restart >/dev/null 2>&1; sleep 1
check "xray stays down after a restart" fails xray_running
check "subscription update refuses without subscriptions" fails flint-sub-update
check "status tab says no servers" panel_has status 'Серверов пока нет'
check "servers tab says no servers" panel_has servers 'Серверов пока нет'
check "own tab hides copy form" fails panel_has own 'name=copy'
rm -f /tmp/flint-test-install.log
finish
