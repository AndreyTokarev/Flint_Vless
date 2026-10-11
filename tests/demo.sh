# Fills the panel with demonstration data and saves every tab as a file, in both languages, so the
# screenshots in the README can be refreshed in one go instead of by hand.
#
# Usage: sh demo.sh [directory]        (default: /tmp/flint-demo)
#
# It runs on the router and puts the real settings back at the end (the same snapshot mechanism the test
# scenarios use), so it is safe to run on a working router — but nothing is guaranteed if the router is
# rebooted in the middle: run it when you can re-deploy if something goes wrong.
#
# The data is made up on purpose: addresses come from the ranges reserved for documentation (RFC 5737:
# 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24), the keys and identifiers are invented, and the servers
# are named after countries the way a provider names them. Never put real subscription links here: the
# screenshots end up in the repository.
set -u
DIR="${1:-/tmp/flint-demo}"
HOST=http://127.0.0.1:81/cgi-bin/panel.cgi
. "$(dirname "$0")/router/lib.sh"
save_state

PIN="$(sed -n 's/^UI_PIN=//p' /etc/xray/flint.env | tr -d '"')"
[ -n "$PIN" ] || fail "the panel PIN is not set in /etc/xray/flint.env"

# A made-up provider list. The format is the one the kit writes: "code  address  sni  pbk  sid  uuid  port  net  service".
# Each server appears in exactly one file: the same code in two files makes its name show twice, because both
# lines are read and both comments count as a name for that code.
demo_sub() {
	cat <<'EOF'
# 🇳🇱 Нидерланды N1 — YouTube без рекламы
nl1  192.0.2.11   en3.findreplayfoals.com   0123456789abcdefghijklmnopqrstuvwxyzABCD  0123456789abcdef  11111111-2222-3333-4444-555555555555  443  tcp  -
# 🇩🇪 Германия N2
de2  192.0.2.12   de2.greenzone12.com       0123456789abcdefghijklmnopqrstuvwxyzABCD  0123456789abcdef  11111111-2222-3333-4444-666666666666  443  tcp  -
# 🇫🇮 Финляндия N3
fi3  198.51.100.13 fi3.spidermanshopping.com 0123456789abcdefghijklmnopqrstuvwxyzABCD 0123456789abcdef  11111111-2222-3333-4444-777777777777  443  tcp  -
EOF
}
demo_nodes() {
	cat <<'EOF'
# 🇹🇷 Турция N4
tr4  198.51.100.14 tr4.promocodiums.com     0123456789abcdefghijklmnopqrstuvwxyzABCD  0123456789abcdef  11111111-2222-3333-4444-888888888888  443  tcp  -
EOF
}
demo_own() {
	cat <<'EOF'
# Свой сервер в Амстердаме
ams  203.0.113.21  nl.example.com            0123456789abcdefghijklmnopqrstuvwxyzABCD  0123456789abcdef  11111111-2222-3333-4444-999999999999  443  tcp  -
EOF
}

mkdir -p "$DIR"
mkdir -p /etc/xray/nodes.d
umask 077
demo_nodes > /etc/xray/nodes.conf
demo_own > /etc/xray/nodes-custom.conf
demo_sub > /etc/xray/nodes.d/s1.conf
printf 's1\thttps://example.com/subscription\tdemo provider\n' > /etc/xray/subscriptions
printf 'proxy\tgosuslugi.ru\ndirect\t192.0.2.50\n' > /etc/xray/custom-sites
printf '2026-10-11 09:00 — серверов: 4\n' > /etc/xray/sub-checked
: > /etc/xray/direct-devices

# The config has to exist and name a server, or the panel shows "no servers yet". It is not rendered and the
# service is not restarted on purpose: the pages are only read, and a restart would interrupt the network of
# whoever is using the router right now. The current node is written directly instead of calling
# "flint-node use", which would restart Xray.
printf 'nl1\n' > /etc/xray/current-node

# The external address the panel shows must not be the real one of whoever runs the demo: it would end up
# in a published screenshot. The panel asks $IP_LOOKUP (lib.sh), so the demo points the setting at a tiny
# local web server with one static file. It is uhttpd (already used by the panel) rather than nc, because
# the busybox nc on this firmware cannot listen, and it is stopped again at the end.
DEMO_IP="203.0.113.77"
# A fixed port is a trap: a server left behind by an earlier run keeps the port, the new one cannot bind, and
# the panel then asks the stale server (this firmware has no pkill, so a run that was interrupted leaves it).
# The port is picked free, and whatever is on it is stopped before the new server starts.
DEMO_HTTPD=/tmp/flint-demo-ip
mkdir -p "$DEMO_HTTPD"
printf '%s\n' "$DEMO_IP" > "$DEMO_HTTPD/index.html"
DEMO_PORT=""
for candidate in 18099 18100 18101 18102 18103; do
	if [ -z "$(netstat -ltn 2>/dev/null | awk -v p=":$candidate\$" '$4 ~ p')" ]; then
		DEMO_PORT="$candidate"
		break
	fi
	# Something is on this port: if it is our own leftover demo server, stop it.
	for pid in $(ps w | grep "[u]httpd -p $candidate" | awk '{ print $1 }'); do
		case "$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')" in
			*uhttpd*flint-demo-ip*) kill "$pid" 2>/dev/null ;;
		esac
	done
	sleep 1
	if [ -z "$(netstat -ltn 2>/dev/null | awk -v p=":$candidate\$" '$4 ~ p')" ]; then
		DEMO_PORT="$candidate"
		break
	fi
done
[ -n "$DEMO_PORT" ] || { echo "no free port for the demo IP server: the status page will show n/a"; }
uhttpd -p "$DEMO_PORT" -h "$DEMO_HTTPD" -f >/dev/null 2>&1 &
IP_SERVER_PID=$!
# The little server needs a moment, and on a busy router it needs more than one: the panel would show "n/a"
# instead of the invented address, which would be noticed only after the screenshots are taken.
i=0
while [ "$i" -lt 10 ]; do
	[ "$(curl -s -m 3 "http://127.0.0.1:$DEMO_PORT/")" = "$DEMO_IP" ] && break
	sleep 1
	i=$((i + 1))
done
# The setting is written into flint.env, which restore_state puts back with the rest of the state.
grep -v '^IP_LOOKUP=' /etc/xray/flint.env > /tmp/flint-env.tmp 2>/dev/null
printf 'IP_LOOKUP=http://127.0.0.1:%s/\n' "$DEMO_PORT" >> /tmp/flint-env.tmp
(umask 077; cp /tmp/flint-env.tmp /etc/xray/flint.env); rm -f /tmp/flint-env.tmp
if [ "$(curl -s -m 3 "http://127.0.0.1:$DEMO_PORT/")" != "$DEMO_IP" ]; then
	echo "  warning: the demo IP server did not answer, the status page will show n/a"
fi

# Devices without VPN on the routing tab come from the DHCP leases; the real ones are the household's
# addresses, so the demo writes its own file and puts the real one back at the end.
[ -f /tmp/dhcp.leases ] && cp /tmp/dhcp.leases /tmp/flint-dhcp.leases.bak
cat > /tmp/dhcp.leases <<'EOF'
1748000000  aa:bb:cc:00:00:01  192.0.2.101  tv-samsung  *
1748000001  aa:bb:cc:00:00:02  192.0.2.102  laptop      *
1748000002  aa:bb:cc:00:00:03  192.0.2.103  console     *
1748000003  aa:bb:cc:00:00:04  192.0.2.104  phone       *
EOF
printf 'aa:bb:cc:00:00:03\tconsole\n' > /etc/xray/direct-devices
printf 'nas01\t192.0.2.120\n' > /etc/xray/dns-hosts

# The Telegram tab shows the address a phone would use, taken from the main network's own address — which
# is the household's. The demo sets its own, along with the port and secret, so nothing real is published.
cat > /etc/xray/tgproxy <<'EOF'
secret=0123456789abcdef0123456789abcdef
state=on
remote=off
route=vpn
addr=example.org
port=443
EOF

# "Recently blocked" on the ad blocking tab is read from AdGuard Home's own query log and carries the names
# of the real devices; the addresses in it are masked below with the rest. Ad blocking is left alone on
# purpose: switching it off restarts AdGuard, and a demo has no business interrupting the network.

# Every saved page gets its stylesheet, logo and favicon inlined, so a page opens correctly from the disk
# (file://) without the router and without a web server: that is what a screenshot tool needs, and it also
# means the pages can be archived as they looked.
inline_assets() {
	page="$1"
	[ -s "$page" ] || return 0
	for pair in "panel.css|/www/flint/panel.css" "logo.svg|/www/flint/logo.svg" "icon.svg|/www/flint/icon.svg"; do
		name="${pair%%|*}"; src="${pair##*|}"
		[ -f "$src" ] || continue
		b64="$(base64 -w0 < "$src" 2>/dev/null || base64 < "$src" | tr -d '\n')"
		case "$name" in
			*.css) mime="text/css" ;;
			*.svg) mime="image/svg+xml" ;;
			*) mime="application/octet-stream" ;;
		esac
		# Both the absolute address the panel uses and the bare name a saved page may carry.
		sed -i "s|href=/$(basename $name)|href=\"data:$mime;base64,$b64\"|g; s|src=/$(basename $name)|src=\"data:$mime;base64,$b64\"|g" "$page"
		sed -i "s|href=\"$(basename $name)\"|href=\"data:$mime;base64,$b64\"|g; s|src=\"$(basename $name)\"|src=\"data:$mime;base64,$b64\"|g" "$page"
	done
}

# Two addresses cannot be redirected by a setting: the link on the Telegram tab takes the address the router
# itself has on the main network (flint-tg link upstream), and AdGuard's query log would carry device names.
# Ad blocking is therefore shown off, and the addresses that still appear are replaced with the ranges
# reserved for documentation. This is presentation-time masking of a saved page, and it says exactly what it
# does rather than pretending the network is made up.
mask_addresses() {
	page="$1"
	[ -s "$page" ] || return 0
	sed -i \
		-e "s|192\.168\.[0-9]\+\.[0-9]\+|192.0.2.10|g" \
		-e "s|10\.0\.[0-9]\+\.[0-9]\+|192.0.2.10|g" \
		"$page"
	# The external address comes from the demo's own little server. When that server did not answer (busy
	# port, slow start), the panel shows the answer text of whatever did — an error page in the middle of a
	# status card. It becomes "n/a", which is what the panel shows when the lookup fails honestly.
	sed -i "s|<b>[^<]*<h1>[^<]*</h1>[^<]*|<b>n/a|g; s|<b>[^<]*&lt;h1&gt;[^<]*|<b>n/a|g" "$page"
}

saved=0
for lang in ru en; do
	for tab in status subs servers own dns routing adblock telegram settings; do
		out="$DIR/$lang-$tab.html"
		wget -qO "$out" "$HOST?pass=$PIN&lang=$lang&tab=$tab" 2>/dev/null || true
		if [ -s "$out" ] && grep -q '</html>' "$out"; then
			inline_assets "$out"
			mask_addresses "$out"
			saved=$((saved + 1))
		else
			echo "  $lang/$tab: not saved"
		fi
	done
done

# The demo service and the borrowed leases file go back before the real state is restored.
kill "$IP_SERVER_PID" 2>/dev/null || true
rm -rf "$DEMO_HTTPD"
[ -f /tmp/flint-dhcp.leases.bak ] && { cp /tmp/flint-dhcp.leases.bak /tmp/dhcp.leases; rm -f /tmp/flint-dhcp.leases.bak; }
restore_state
echo "saved $saved of 18 pages to $DIR"
echo "open one in a browser to take a screenshot, for example: scp root@$(lan_ip):$DIR/ru-status.html ."
