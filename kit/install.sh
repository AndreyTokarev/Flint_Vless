#!/bin/sh
# Gru kit installer for GL.iNet GL-BE6500 (Flint), firmware 4.x.
# Run on the router from the unpacked kit dir: sh install.sh
# Expects config/gru.env and config/nodes.conf next to this script (see config/*.example).
set -e
KIT="$(cd "$(dirname "$0")" && pwd)"
say() { echo "== $*"; }
die() { echo "!! $*" >&2; exit 1; }

[ -f "$KIT/config/gru.env" ] || die "missing $KIT/config/gru.env"
[ -f "$KIT/config/nodes.conf" ] || die "missing $KIT/config/nodes.conf"
. "$KIT/config/gru.env"
[ -n "$VLESS_UUID" ] || die "VLESS_UUID is empty in gru.env"
[ -n "$UI_PIN" ] || die "UI_PIN is empty in gru.env"
DEFAULT_NODE="${DEFAULT_NODE:-auto}"
grep -q -E "^[[:space:]]*$DEFAULT_NODE[[:space:]]" "$KIT/config/nodes.conf" ||
	die "DEFAULT_NODE '$DEFAULT_NODE' not found in nodes.conf"

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
	command -v xray >/dev/null || echo xray-core
}
need="$(missing | tr '\n' ' ')"
if [ -n "${need% }" ]; then
	say "opkg install: $need"
	opkg update > /tmp/gru-opkg.log 2>&1 || echo "opkg update failed, see /tmp/gru-opkg.log"
	for p in $need; do
		opkg install "$p" >> /tmp/gru-opkg.log 2>&1 || echo "opkg install $p failed"
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
[ -z "${left% }" ] || die "still missing: $left (see /tmp/gru-opkg.log)"
echo "xray: $(xray version | head -n1)"

say "legacy cleanup"
if [ -x /etc/init.d/gru-ui81 ]; then
	/etc/init.d/gru-ui81 stop || true
	/etc/init.d/gru-ui81 disable || true
	rm -f /etc/init.d/gru-ui81
fi
if [ -x /etc/init.d/v2raya ]; then
	/etc/init.d/v2raya stop 2>/dev/null || true
	/etc/init.d/v2raya disable 2>/dev/null || true
fi
sed -i '/dnscrypt-proxy -config/d' /etc/rc.local
rm -f /etc/firewall.user.d-local-hosts /etc/firewall.user.d-upstream-lan \
	/etc/dnsmasq.d/local-hosts.conf /tmp/dnsmasq.d/local-hosts.conf \
	/etc/xray/nodes.tsv /etc/xray/gru-ui.pass
rm -rf /etc/xray/nodes
uci -q delete firewall.gru_ui81 || true
if [ -f /etc/nginx/conf.d/gru-ui.conf ]; then
	rm -f /etc/nginx/conf.d/gru-ui.conf
	/etc/init.d/nginx reload || true
fi

say "files"
mkdir -p /etc/xray /etc/dnscrypt-proxy2 /etc/dnsmasq.d /www/gru/cgi-bin /usr/share/gru
cp "$KIT/files/etc/xray/template.json" /etc/xray/
cp "$KIT/files/usr/share/gru/vless.awk" /usr/share/gru/
cp "$KIT/files/etc/init.d/xray" "$KIT/files/etc/init.d/gru-ui" "$KIT/files/etc/init.d/gru-doh" \
	"$KIT/files/etc/init.d/gru-adblock" /etc/init.d/
cp "$KIT/files/etc/dnscrypt-proxy2/gru-doh.toml" /etc/dnscrypt-proxy2/
cp "$KIT/files/etc/firewall.user" /etc/firewall.user
cp "$KIT/files/usr/bin/gru-node" "$KIT/files/usr/bin/gru-geo-update" "$KIT/files/usr/bin/gru-sub-update" \
	"$KIT/files/usr/bin/gru-custom" "$KIT/files/usr/bin/gru-watchdog" "$KIT/files/usr/bin/gru-adblock" /usr/bin/
cp "$KIT/files/www/gru/index.html" "$KIT/files/www/gru/logo.svg" "$KIT/files/www/gru/icon.svg" /www/gru/
cp "$KIT/files/www/gru/cgi-bin/panel.cgi" /www/gru/cgi-bin/
chmod 755 /etc/init.d/xray /etc/init.d/gru-ui /etc/init.d/gru-doh /etc/init.d/gru-adblock /usr/bin/gru-node \
	/usr/bin/gru-geo-update /usr/bin/gru-sub-update /usr/bin/gru-custom /usr/bin/gru-watchdog /usr/bin/gru-adblock \
	/www/gru/cgi-bin/panel.cgi

(umask 077; cp "$KIT/config/gru.env" /etc/xray/gru.env; cp "$KIT/config/nodes.conf" /etc/xray/nodes.conf)
# Optional: own nodes, custom sites and ad blocking lists/rules saved by backup; without them the router's copies stay.
for f in nodes-custom.conf custom-sites adblock-lists adblock-rules adblock-exclude; do
	if [ -f "$KIT/config/$f" ]; then (umask 077; cp "$KIT/config/$f" "/etc/xray/$f"); fi
done
case "${ROUTING:-ru}" in
	ru|global) echo "${ROUTING:-ru}" > /etc/xray/routing-mode ;;
	*) die "ROUTING must be ru or global" ;;
esac

LAN_IP="$(uci -q get network.lan.ipaddr || echo 192.168.8.1)"
LAN_IP="${LAN_IP%%/*}"
sed "s/__LAN_IP__/$LAN_IP/g" "$KIT/files/etc/dnsmasq.d/gru-names.conf" > /etc/dnsmasq.d/gru-names.conf
: > /etc/dnsmasq.d/gru-hosts.conf
for pair in $LOCAL_HOSTS; do
	name="${pair%%=*}"; ip="${pair#*=}"
	for n in "$name" "$name.lan" "$name.local"; do
		echo "address=/$n/$ip" >> /etc/dnsmasq.d/gru-hosts.conf
	done
done

say "dnsmasq -> DoH 127.0.0.1#5053"
uci set dhcp.@dnsmasq[0].noresolv='1'
uci -q delete dhcp.@dnsmasq[0].server || true
uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#5053'
uci set dhcp.@dnsmasq[0].confdir='/etc/dnsmasq.d'
uci set dhcp.@dnsmasq[0].rebind_protection='0'
uci commit dhcp

say "firewall"
if ! uci show firewall | grep -q "path='/etc/firewall.user'"; then
	sec="$(uci add firewall include)"
	uci set "firewall.$sec.path=/etc/firewall.user"
	uci set "firewall.$sec.fw4_compatible=1"
fi
uci set firewall.gru_ui=rule
uci set firewall.gru_ui.name='Allow-Gru-UI'
uci set firewall.gru_ui.src='lan'
uci set firewall.gru_ui.dest_port='81'
uci set firewall.gru_ui.proto='tcp'
uci set firewall.gru_ui.target='ACCEPT'
uci set firewall.xray_socks=rule
uci set firewall.xray_socks.name='Allow-Xray-SOCKS'
uci set firewall.xray_socks.src='lan'
uci set firewall.xray_socks.dest_port='1080'
uci set firewall.xray_socks.proto='tcp udp'
uci set firewall.xray_socks.target='ACCEPT'
uci set firewall.xray_http=rule
uci set firewall.xray_http.name='Allow-Xray-HTTP'
uci set firewall.xray_http.src='lan'
uci set firewall.xray_http.dest_port='1087'
uci set firewall.xray_http.proto='tcp'
uci set firewall.xray_http.target='ACCEPT'
uci -q delete firewall.gru_upstream_in || true
uci -q delete firewall.gru_upstream_fwd || true
if [ -n "$UPSTREAM_NET" ]; then
	uci set firewall.gru_upstream_in=rule
	uci set firewall.gru_upstream_in.name='Allow-Upstream-LAN-to-Router'
	uci set firewall.gru_upstream_in.src='wan'
	uci set firewall.gru_upstream_in.src_ip="$UPSTREAM_NET"
	uci set firewall.gru_upstream_in.proto='all'
	uci set firewall.gru_upstream_in.target='ACCEPT'
	uci set firewall.gru_upstream_fwd=rule
	uci set firewall.gru_upstream_fwd.name='Allow-Upstream-LAN-to-LAN'
	uci set firewall.gru_upstream_fwd.src='wan'
	uci set firewall.gru_upstream_fwd.dest='lan'
	uci set firewall.gru_upstream_fwd.src_ip="$UPSTREAM_NET"
	uci set firewall.gru_upstream_fwd.proto='all'
	uci set firewall.gru_upstream_fwd.target='ACCEPT'
fi
uci commit firewall

say "services"
for pid in $(pidof dnscrypt-proxy); do
	grep -q gru-doh.toml /proc/$pid/cmdline 2>/dev/null || kill "$pid" 2>/dev/null || true
done
/etc/init.d/gru-doh enable
/etc/init.d/gru-doh restart
sleep 2
/etc/init.d/dnsmasq restart
sleep 2
# Ad blocking: the state chosen in the panel survives a redeploy; ADBLOCK only seeds a fresh router.
[ -f /etc/xray/adblock ] || case "$ADBLOCK" in on|1) echo on ;; *) echo off ;; esac > /etc/xray/adblock
if [ "$(gru-adblock state)" = on ]; then
	gru-adblock on || true
else
	/etc/init.d/gru-adblock disable 2>/dev/null || true
fi
/etc/init.d/xray enable
gru-node use "$DEFAULT_NODE"
/etc/init.d/gru-ui enable
/etc/init.d/gru-ui restart
/etc/init.d/firewall reload
sh /etc/firewall.user

say "geo files for RU routing (~25 MB)"
if [ -s /usr/share/xray/geoip.dat ] && [ -s /usr/share/xray/geosite.dat ]; then
	gru-node apply
else
	gru-geo-update
fi
grep -q gru-geo-update /etc/crontabs/root 2>/dev/null ||
	echo "30 4 * * 0 /usr/bin/gru-geo-update >/tmp/gru-geo-update.log 2>&1" >> /etc/crontabs/root
# The interval chosen in the panel survives a redeploy; SUB_INTERVAL only seeds a fresh router.
gru-sub-update interval "$(cat /etc/xray/sub-interval 2>/dev/null || echo "${SUB_INTERVAL:-24h}")"
grep -q gru-watchdog /etc/crontabs/root 2>/dev/null ||
	echo "*/2 * * * * /usr/bin/gru-watchdog >/tmp/gru-watchdog.log 2>&1" >> /etc/crontabs/root
/etc/init.d/cron enable
/etc/init.d/cron restart

say "check"
nslookup youtube.com 127.0.0.1 >/dev/null && echo "DNS: ok" || echo "DNS: FAIL"
for try in 1 2 3; do
	ip="$(curl -s -m 15 -x http://127.0.0.1:1087 https://ifconfig.me || true)"
	[ -n "$ip" ] && break
	sleep 5
done
[ -n "$ip" ] && echo "VPN exit IP: $ip" || echo "VPN: FAIL (check nodes.conf / VLESS_UUID)"
[ "$(gru-node vpn)" = off ] && echo "NOTE: VPN is switched off in the panel (gru-node vpn on to enable)"
echo "Panel: http://vpn.lan:81/  (PIN from gru.env)"
