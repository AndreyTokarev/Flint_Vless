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
for a in all noarch aarch64_cortex-a53 aarch64_cortex-a53_neon-vfpv4; do
	grep -q "^arch $a " /etc/opkg.conf || echo "arch $a 10" >> /etc/opkg.conf
done
need=""
command -v xray >/dev/null || need="$need xray-core"
[ -x /usr/sbin/dnscrypt-proxy ] || need="$need dnscrypt-proxy2"
command -v curl >/dev/null || need="$need curl"
if [ -n "$need" ]; then
	opkg update || true
	opkg install $need || true
fi
if ! command -v xray >/dev/null && [ -f "$KIT/bin/xray" ]; then
	cp "$KIT/bin/xray" /usr/bin/xray
	chmod 755 /usr/bin/xray
fi
command -v xray >/dev/null || die "xray not installed (opkg failed; put an arm64 binary into kit/bin/xray)"
[ -x /usr/sbin/dnscrypt-proxy ] || die "dnscrypt-proxy not installed"
command -v curl >/dev/null || die "curl not installed"

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
mkdir -p /etc/xray /etc/dnscrypt-proxy2 /etc/dnsmasq.d /www/gru/cgi-bin
cp "$KIT/files/etc/xray/template.json" /etc/xray/
cp "$KIT/files/etc/init.d/xray" "$KIT/files/etc/init.d/gru-ui" "$KIT/files/etc/init.d/gru-doh" /etc/init.d/
cp "$KIT/files/etc/dnscrypt-proxy2/gru-doh.toml" /etc/dnscrypt-proxy2/
cp "$KIT/files/etc/firewall.user" /etc/firewall.user
cp "$KIT/files/usr/bin/gru-node" /usr/bin/
cp "$KIT/files/www/gru/index.html" /www/gru/
cp "$KIT/files/www/gru/cgi-bin/panel.cgi" /www/gru/cgi-bin/
chmod 755 /etc/init.d/xray /etc/init.d/gru-ui /etc/init.d/gru-doh /usr/bin/gru-node /www/gru/cgi-bin/panel.cgi

(umask 077; cp "$KIT/config/gru.env" /etc/xray/gru.env; cp "$KIT/config/nodes.conf" /etc/xray/nodes.conf)

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
/etc/init.d/xray enable
gru-node "$DEFAULT_NODE"
/etc/init.d/gru-ui enable
/etc/init.d/gru-ui restart
/etc/init.d/firewall reload
sh /etc/firewall.user

say "check"
nslookup youtube.com 127.0.0.1 >/dev/null && echo "DNS: ok" || echo "DNS: FAIL"
ip="$(curl -s -m 15 -x http://127.0.0.1:1087 https://ifconfig.me || true)"
[ -n "$ip" ] && echo "VPN exit IP: $ip" || echo "VPN: FAIL (check nodes.conf / VLESS_UUID)"
echo "Panel: http://gru.lan:81/  (PIN from gru.env)"
