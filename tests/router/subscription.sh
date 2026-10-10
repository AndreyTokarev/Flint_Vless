# From no servers: adding a subscription turns the VPN on, deleting the last one turns it off.
. "$(dirname "$0")/lib.sh"
echo "== subscription: add to an empty router, delete the last one"
save_state
url="$(first_sub_url)"
if [ -z "$url" ]; then echo "  skip: the router has no subscription"; finish; exit; fi
go_empty
flint-sub-update add "$url" > /tmp/flint-test-case.log 2>&1
check "subscription added" grep -q 'добавлена\|added' /tmp/flint-test-case.log
check "subscription listed" [ "$(flint-sub-update list | wc -l)" = 1 ]
check "servers imported" fails no_servers
check "subscription cron job" sub_cron
vpn_mode
id="$(flint-sub-update list | cut -f1)"
n="$(flint-node codes | wc -l)"
cp "/etc/xray/nodes.d/$id.conf" /etc/xray/nodes.d/zzorphan.conf
check "file of an unlisted subscription is ignored" [ "$(flint-node codes | wc -l)" = "$n" ]
flint-sub-update del "$id" > /tmp/flint-test-case.log 2>&1
check "last subscription deleted" grep -q 'удалена\|deleted' /tmp/flint-test-case.log
check "file of an unlisted subscription removed" fails [ -e /etc/xray/nodes.d/zzorphan.conf ]
direct_mode
check "no subscription cron job" fails sub_cron
rm -f /tmp/flint-test-case.log
finish
