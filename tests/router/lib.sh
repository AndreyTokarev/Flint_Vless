# Shared helpers for the router test scenarios (sourced by every scenario).
# A scenario snapshots /etc/xray first and puts it back at the end, also when it stops early.
# Output never contains subscription links, UUIDs or the PIN.
. /usr/share/flint/lib.sh
STATE=/tmp/flint-test-state.$$.tgz
LOCK=/tmp/flint-test.lock
PASS=0
FAIL=0

# One scenario at a time, and only with a good snapshot: restore_state replaces /etc/xray with it.
save_state() {
	mkdir "$LOCK" 2>/dev/null || { echo "  another test is running on the router ($LOCK), scenario skipped"; exit 1; }
	if ! { [ -s /etc/xray/flint.env ] && tar -C /etc -czf "$STATE" xray; }; then
		rmdir "$LOCK"; echo "  cannot snapshot /etc/xray, scenario skipped"; exit 1
	fi
	trap restore_state EXIT
}
restore_state() {
	trap - EXIT
	if [ -s "$STATE" ]; then rm -rf /etc/xray && tar -C /etc -xzf "$STATE" && rm -f "$STATE"
	else echo "  snapshot $STATE is gone, /etc/xray left as is"; fi
	rmdir "$LOCK" 2>/dev/null
	flint-sub-update interval "$(cat /etc/xray/sub-interval 2>/dev/null || echo 24h)" >/dev/null
	flint-node apply >/dev/null 2>&1
	echo "  restored; vpn: $(vpn_works && echo ok || echo FAIL)"
}
finish() {
	restore_state
	echo "  passed: $PASS, failed: $FAIL"
	[ "$FAIL" = 0 ]
}

# check <description> <command...>: the command's exit status decides.
check() {
	d="$1"; shift
	if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo "  ok    $d"
	else FAIL=$((FAIL + 1)); echo "  FAIL  $d"; fi
}
fails() { ! "$@"; }

# Router state probes.
xray_running() { pidof xray >/dev/null; }
redirect_on() { iptables -t nat -S PREROUTING | grep -q -- '-j XRAY'; }
quic_blocked() { iptables -S FORWARD | grep -q 'dport 443 -j DROP'; }
sub_cron() { grep -q flint-sub-update /etc/crontabs/root; }
no_servers() { [ -z "$(flint-node codes)" ]; }
current_is() { [ "$(flint-node current)" = "$1" ]; }
vpn_works() {
	for i in 1 2 3; do
		[ -n "$(curl -s -m 15 -x http://127.0.0.1:1087 https://ifconfig.me)" ] && return 0
		sleep 2
	done
	return 1
}
direct_works() { [ -n "$(curl -s -m 8 https://ifconfig.me)" ]; }
# panel_has <tab> <text>: the Russian panel page contains the text.
panel_has() {
	pin="$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')"
	wget -qO- "http://127.0.0.1:81/cgi-bin/panel.cgi?pass=$pin&lang=ru&tab=$1" | grep -q "$2"
}
# The no-servers state: devices online directly, nothing for Xray to run.
direct_mode() {
	check "no servers" no_servers
	check "xray stopped" fails xray_running
	check "no redirect into xray" fails redirect_on
	check "QUIC not blocked" fails quic_blocked
	check "internet works directly" direct_works
}
vpn_mode() {
	check "xray running" xray_running
	check "LAN redirected into xray" redirect_on
	check "QUIC blocked" quic_blocked
	check "vpn works" vpn_works
}

# Server lines and the first subscription link before a scenario empties the router.
first_node_line() { node_lines $(node_files) | head -n1; }
first_sub_url() { head -n1 /etc/xray/subscriptions 2>/dev/null | cut -f2; }
# Remove every server and subscription; an empty subscriptions file keeps SUB_URL from seeding it again.
go_empty() {
	rm -rf /etc/xray/nodes.conf /etc/xray/nodes.d /etc/xray/nodes-custom.conf /etc/xray/sub-status /etc/xray/current-node
	: > /etc/xray/subscriptions
	flint-node apply >/dev/null 2>&1
}
