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
demo_nodes() {
	cat <<'EOF'
# 🇳🇱 Netherlands N1 — YouTube without ads
nl1  192.0.2.11   en3.findreplayfoals.com   0123456789abcdefghijklmnopqrstuvwxyzABCD  0123456789abcdef  11111111-2222-3333-4444-555555555555  443  tcp  -
# 🇩🇪 Germany N2
de2  192.0.2.12   de2.greenzone12.com       0123456789abcdefghijklmnopqrstuvwxyzABCD  0123456789abcdef  11111111-2222-3333-4444-666666666666  443  tcp  -
# 🇫🇮 Finland N3
fi3  198.51.100.13 fi3.spidermanshopping.com 0123456789abcdefghijklmnopqrstuvwxyzABCD 0123456789abcdef  11111111-2222-3333-4444-777777777777  443  tcp  -
# 🇹🇷 Turkey N4
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
demo_nodes > /etc/xray/nodes.d/s1.conf
printf 's1\thttps://example.com/subscription\tdemo provider\n' > /etc/xray/subscriptions
printf 'proxy\tgosuslugi.ru\ndirect\t192.0.2.50\n' > /etc/xray/custom-sites
printf '2026-10-11 09:00 — серверов: 4\n' > /etc/xray/sub-checked
: > /etc/xray/direct-devices

# The config has to exist and name a server, or the panel shows "no servers yet". It is not rendered and the
# service is not restarted on purpose: the pages are only read, and a restart would interrupt the network of
# whoever is using the router right now. The current node is written directly instead of calling
# "flint-node use", which would restart Xray.
printf 'nl1\n' > /etc/xray/current-node

saved=0
for lang in ru en; do
	for tab in status subs servers own dns routing adblock telegram settings; do
		out="$DIR/$lang-$tab.html"
		wget -qO "$out" "$HOST?pass=$PIN&lang=$lang&tab=$tab" 2>/dev/null || true
		if [ -s "$out" ] && grep -q '</html>' "$out"; then
			saved=$((saved + 1))
		else
			echo "  $lang/$tab: not saved"
		fi
	done
done

restore_state
echo "saved $saved of 18 pages to $DIR"
echo "open one in a browser to take a screenshot, for example: scp root@$(lan_ip):$DIR/ru-status.html ."
