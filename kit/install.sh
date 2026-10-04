#!/bin/sh
# Flint kit installer for GL.iNet GL-BE6500 (Flint), firmware 4.x.
# Run on the router from the unpacked kit dir: sh install.sh
# Expects config/flint.env next to this script (see config/*.example); servers are optional:
# without them LAN devices go online directly until a subscription is added in the panel.
set -e
KIT="$(cd "$(dirname "$0")" && pwd)"
say() { echo "== $*"; }
die() { echo "!! $*" >&2; exit 1; }
. "$KIT/migrate.sh"
VERSION="$(cat "$KIT/VERSION" 2>/dev/null || echo dev)"
echo "Flint VPN $VERSION (was: $(cat /usr/share/flint/version 2>/dev/null || echo none))"

[ -f "$KIT/config/flint.env" ] || die "missing $KIT/config/flint.env"
. "$KIT/config/flint.env"
[ -n "$UI_PIN" ] || die "UI_PIN is empty in flint.env"
DEFAULT_NODE="${DEFAULT_NODE:-auto}"

say "packages"
[ "$(uname -m)" = aarch64 ] || die "kit expects an aarch64 router, got $(uname -m)"
# GL firmware arch is aarch64_cortex-a53_neon-vfpv4; xray-core in the feed is built for aarch64_cortex-a53.
for a in all noarch aarch64_cortex-a53 aarch64_cortex-a53_neon-vfpv4; do
	grep -q "^arch $a " /etc/opkg.conf || echo "arch $a 10" >> /etc/opkg.conf
done

missing() {
	command -v curl >/dev/null || echo curl
	[ -s /etc/ssl/certs/ca-certificates.crt ] || echo ca-bundle
	[ -x /usr/sbin/dnscrypt-proxy ] || echo dnscrypt-proxy2
	command -v iptables >/dev/null || echo "iptables-nft iptables-mod-nat-extra"
	command -v unzip >/dev/null || echo unzip
	command -v jsonfilter >/dev/null || echo jsonfilter
	command -v xray >/dev/null || echo xray-core
}
need="$(missing | tr '\n' ' ')"
if [ -n "${need% }" ]; then
	say "opkg install: $need"
	opkg update > /tmp/flint-opkg.log 2>&1 || echo "opkg update failed, see /tmp/flint-opkg.log"
	for p in $need; do
		opkg install "$p" >> /tmp/flint-opkg.log 2>&1 || echo "opkg install $p failed"
	done
fi

if ! command -v xray >/dev/null; then
	if [ -f "$KIT/bin/xray" ]; then
		say "xray from kit/bin/xray"
		cp "$KIT/bin/xray" /usr/bin/xray
	else
		XRAY_VERSION="${XRAY_VERSION:-v1.8.24}"
		say "xray $XRAY_VERSION from GitHub"
		curl -fL -m 300 -o /tmp/xray.zip \
			"https://github.com/XTLS/Xray-core/releases/download/$XRAY_VERSION/Xray-linux-arm64-v8a.zip" &&
			unzip -o -q /tmp/xray.zip xray -d /usr/bin || true
		rm -f /tmp/xray.zip
	fi
	if [ -f /usr/bin/xray ]; then chmod 755 /usr/bin/xray; fi
fi

left="$(missing | grep -v -x unzip | tr '\n' ' ')"
[ -z "${left% }" ] || die "still missing: $left (see /tmp/flint-opkg.log)"
echo "xray: $(xray version | head -n1)"

say "legacy cleanup"
migrate_legacy_files

say "files"
mkdir -p /etc/xray /etc/dnscrypt-proxy2 /etc/dnsmasq.d /www/flint/cgi-bin /usr/share/flint
cp "$KIT/files/etc/xray/template.json" /etc/xray/
cp "$KIT/files/usr/share/flint/vless.awk" "$KIT/files/usr/share/flint/lib.sh" /usr/share/flint/
echo "$VERSION" > /usr/share/flint/version
cp "$KIT/files/etc/init.d/xray" "$KIT/files/etc/init.d/flint-ui" "$KIT/files/etc/init.d/flint-doh" \
	"$KIT/files/etc/init.d/flint-adblock" /etc/init.d/
cp "$KIT/files/etc/firewall.user" /etc/firewall.user
cp "$KIT/files/usr/bin/flint-node" "$KIT/files/usr/bin/flint-geo-update" "$KIT/files/usr/bin/flint-sub-update" \
	"$KIT/files/usr/bin/flint-custom" "$KIT/files/usr/bin/flint-watchdog" "$KIT/files/usr/bin/flint-adblock" \
	"$KIT/files/usr/bin/flint-settings" "$KIT/files/usr/bin/flint-dns" /usr/bin/
cp "$KIT/files/www/flint/index.html" "$KIT/files/www/flint/logo.svg" "$KIT/files/www/flint/icon.svg" \
	"$KIT/files/www/flint/panel.css" /www/flint/
cp "$KIT/files/www/flint/cgi-bin/panel.cgi" /www/flint/cgi-bin/
chmod 755 /etc/init.d/xray /etc/init.d/flint-ui /etc/init.d/flint-doh /etc/init.d/flint-adblock /usr/bin/flint-node \
	/usr/bin/flint-geo-update /usr/bin/flint-sub-update /usr/bin/flint-custom /usr/bin/flint-watchdog /usr/bin/flint-adblock \
	/usr/bin/flint-settings /usr/bin/flint-dns \
	/www/flint/cgi-bin/panel.cgi

# User state from config/ (names in state-files); an entry missing there keeps the router's copy.
# nodes.d only seeds a router without subscription servers: the router keeps its own list fresh.
grep -v -E '^(#|$)' "$KIT/state-files" | while read -r f; do
	[ -e "$KIT/config/$f" ] || continue
	if [ "$f" = nodes.d ] && [ -n "$(ls /etc/xray/nodes.d 2>/dev/null)" ]; then continue; fi
	rm -rf "/etc/xray/$f"
	(umask 077; cp -R "$KIT/config/$f" "/etc/xray/$f")
done
migrate_nodes_groups
case "${ROUTING:-ru}" in ru|global) ;; *) die "ROUTING must be ru or global" ;; esac
# The routing mode chosen in the panel survives a redeploy; ROUTING only seeds a fresh router.
[ -f /etc/xray/routing-mode ] || echo "${ROUTING:-ru}" > /etc/xray/routing-mode

LAN_IP="$(uci -q get network.lan.ipaddr || echo 192.168.8.1)"
LAN_IP="${LAN_IP%%/*}"
sed "s/__LAN_IP__/$LAN_IP/g" "$KIT/files/etc/dnsmasq.d/flint-names.conf" > /etc/dnsmasq.d/flint-names.conf
# Local names live in /etc/xray/dns-hosts (panel, DNS tab); LOCAL_HOSTS only seeds a router without the list.
if [ ! -f /etc/xray/dns-hosts ]; then
	: > /etc/xray/dns-hosts
	for pair in $LOCAL_HOSTS; do
		flint-dns hosts add "${pair%%=*}" "${pair#*=}" >/dev/null || echo "LOCAL_HOSTS: skipped $pair"
	done
fi
flint-dns hosts apply

say "DNS: $(flint-dns title)"
# The DNS mode and servers chosen in the panel survive a redeploy: flint-dns sets the dnsmasq upstream.
flint-dns config
uci -q batch <<EOF
set dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d'
set dhcp.@dnsmasq[0].rebind_protection='0'
commit dhcp
EOF

say "firewall"
if ! uci show firewall | grep -q "path='/etc/firewall.user'"; then
	sec="$(uci add firewall include)"
	uci set "firewall.$sec.path=/etc/firewall.user"
	uci set "firewall.$sec.fw4_compatible=1"
fi
uci -q batch <<EOF
set firewall.flint_ui=rule
set firewall.flint_ui.name='Allow-Flint-UI'
set firewall.flint_ui.src='lan'
set firewall.flint_ui.dest_port='81'
set firewall.flint_ui.proto='tcp'
set firewall.flint_ui.target='ACCEPT'
set firewall.xray_socks=rule
set firewall.xray_socks.name='Allow-Xray-SOCKS'
set firewall.xray_socks.src='lan'
set firewall.xray_socks.dest_port='1080'
set firewall.xray_socks.proto='tcp udp'
set firewall.xray_socks.target='ACCEPT'
set firewall.xray_http=rule
set firewall.xray_http.name='Allow-Xray-HTTP'
set firewall.xray_http.src='lan'
set firewall.xray_http.dest_port='1087'
set firewall.xray_http.proto='tcp'
set firewall.xray_http.target='ACCEPT'
delete firewall.flint_upstream_in
delete firewall.flint_upstream_fwd
EOF
# The main router's network reaches Flint and the devices behind it (after a change of UPSTREAM_NET: redeploy).
if [ -n "$UPSTREAM_NET" ]; then
	uci -q batch <<EOF
set firewall.flint_upstream_in=rule
set firewall.flint_upstream_in.name='Allow-Upstream-LAN-to-Router'
set firewall.flint_upstream_in.src='wan'
set firewall.flint_upstream_in.src_ip='$UPSTREAM_NET'
set firewall.flint_upstream_in.proto='all'
set firewall.flint_upstream_in.target='ACCEPT'
set firewall.flint_upstream_fwd=rule
set firewall.flint_upstream_fwd.name='Allow-Upstream-LAN-to-LAN'
set firewall.flint_upstream_fwd.src='wan'
set firewall.flint_upstream_fwd.dest='lan'
set firewall.flint_upstream_fwd.src_ip='$UPSTREAM_NET'
set firewall.flint_upstream_fwd.proto='all'
set firewall.flint_upstream_fwd.target='ACCEPT'
EOF
fi
uci commit firewall

say "services"
for pid in $(pidof dnscrypt-proxy); do
	grep -q flint-doh.toml /proc/$pid/cmdline 2>/dev/null || kill "$pid" 2>/dev/null || true
done
flint-dns services
sleep 2
/etc/init.d/dnsmasq restart
sleep 2
# Ad blocking: the state chosen in the panel survives a redeploy; ADBLOCK only seeds a fresh router.
[ -f /etc/xray/adblock ] || case "$ADBLOCK" in on|1) echo on ;; *) echo off ;; esac > /etc/xray/adblock
if [ "$(flint-adblock state)" = on ]; then
	flint-adblock on || true
else
	/etc/init.d/flint-adblock disable 2>/dev/null || true
fi
/etc/init.d/xray enable
# No servers yet but SUB_URL is set: fetch them now.
[ -n "$(flint-node codes)" ] || flint-sub-update >/dev/null 2>&1 || true
flint-node use "$DEFAULT_NODE" 2>/dev/null || flint-node apply
/etc/init.d/flint-ui enable
/etc/init.d/flint-ui restart
# fw4 warns ("[!] ...") about the firmware's own disabled or unused GL rules on every reload: not ours, hidden.
fw="$(/etc/init.d/firewall reload 2>&1)" || { echo "$fw"; die "firewall reload failed"; }
printf '%s\n' "$fw" | grep -v -e '^\[!\]' -e '^$' || true
sh /etc/firewall.user

say "geo files for RU routing (~25 MB)"
if [ -s /usr/share/xray/geoip.dat ] && [ -s /usr/share/xray/geosite.dat ]; then
	flint-node apply
else
	flint-geo-update
fi
grep -q flint-geo-update /etc/crontabs/root 2>/dev/null ||
	echo "30 4 * * 0 /usr/bin/flint-geo-update >/tmp/flint-geo-update.log 2>&1" >> /etc/crontabs/root
# The interval chosen in the panel survives a redeploy; SUB_INTERVAL only seeds a fresh router.
flint-sub-update interval "$(cat /etc/xray/sub-interval 2>/dev/null || echo "${SUB_INTERVAL:-24h}")"
grep -q flint-watchdog /etc/crontabs/root 2>/dev/null ||
	echo "*/2 * * * * /usr/bin/flint-watchdog >/tmp/flint-watchdog.log 2>&1" >> /etc/crontabs/root
/etc/init.d/cron enable
/etc/init.d/cron restart

say "check"
nslookup youtube.com 127.0.0.1 >/dev/null && echo "DNS: ok" || echo "DNS: FAIL"
if [ -z "$(flint-node codes)" ]; then
	echo "VPN: no servers yet, devices go online directly. Add a subscription in the panel (Subscriptions tab)."
else
	for try in 1 2 3; do
		ip="$(curl -s -m 15 -x http://127.0.0.1:1087 https://ifconfig.me || true)"
		[ -n "$ip" ] && break
		sleep 5
	done
	[ -n "$ip" ] && echo "VPN exit IP: $ip" || echo "VPN: FAIL (check the servers on the panel's Servers tab)"
fi
[ "$(flint-node vpn)" = off ] && echo "NOTE: VPN is switched off in the panel (flint-node vpn on to enable)"
echo "Flint VPN $VERSION. Panel: http://vpn.lan:81/  (PIN from flint.env)"
