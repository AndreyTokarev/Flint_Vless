# Ad blocking survives a restore: the settings carry the filter lists and rules, the cached data under
# /etc/flint-adguard is rebuilt by AdGuard Home itself, so the blocking comes back without the user
# doing anything. This scenario throws the cache away on purpose and checks that it is rebuilt.
# Usage: sh adblock.sh <kit dir>
. "$(dirname "$0")/lib.sh"
KIT="${1:?kit dir}"
echo "== adblock: the filter cache is rebuilt after a restore"
save_state

if [ "$(flint-adblock state)" != on ]; then
	echo "  skip: ad blocking is off on this router (turn it on in the panel and run again)"
	finish
	exit
fi

# The lists and rules are what a backup carries: they live in /etc/xray and must be in place.
check "the filter list is configured" sh -c '[ -s /etc/xray/adblock-lists ]'
check "the filter list has a URL" sh -c 'grep -q "^http" /etc/xray/adblock-lists'
check "the data directory exists" [ -d /etc/flint-adguard/data ]

# Drop the cache the way a restore on a fresh router does, then let the service rebuild it.
mv /etc/flint-adguard/data /tmp/flint-test-adg-data
mkdir -p /etc/flint-adguard/data
/etc/init.d/flint-adblock stop >/dev/null 2>&1
flint-adblock config >/dev/null 2>&1
/etc/init.d/flint-adblock start >/dev/null 2>&1
rebuilt=
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
	if [ -d /etc/flint-adguard/data/filters ] || [ "$(ls /etc/flint-adguard/data 2>/dev/null | wc -l)" -gt 1 ]; then
		rebuilt=1
		break
	fi
	sleep 2
done
check "the cache is rebuilt by the service" [ -n "$rebuilt" ]
check "the running setup still blocks" flint-adblock check
ok_state="$(flint-adblock state)"
check "ad blocking is still on" [ "$ok_state" = on ]
check "the filter list is still configured" sh -c 'grep -q "^http" /etc/xray/adblock-lists'
check "the list is downloaded again" sh -c 'flint-adblock list 2>/dev/null | grep -q "^http"'

# Put the original cache back: it is the router's own data, not test material.
/etc/init.d/flint-adblock stop >/dev/null 2>&1
rm -rf /etc/flint-adguard/data
mv /tmp/flint-test-adg-data /etc/flint-adguard/data
/etc/init.d/flint-adblock start >/dev/null 2>&1
for i in 1 2 3 4 5 6 7 8 9 10; do
	flint-adblock check >/dev/null 2>&1 && break
	sleep 2
done
check "the original cache is back and answers" flint-adblock check

finish
