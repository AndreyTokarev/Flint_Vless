#!/bin/sh
# Flint kit installer for GL.iNet GL-BE6500 (Flint), firmware 4.x.
# Run on the router from the unpacked kit dir: sh install.sh
# Expects config/flint.env next to this script (see config/*.example); servers are optional:
# without them LAN devices go online directly until a subscription is added in the panel.
set -e
KIT="$(cd "$(dirname "$0")" && pwd)"
say() { echo "== $*"; }
die() { echo "!! $*" >&2; exit 1; }
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
# Kits before the rename used the gru- prefix: services, files, cron jobs and firewall rules.
for s in gru-ui81 gru-ui gru-doh gru-adblock; do
	[ -x "/etc/init.d/$s" ] || continue
	"/etc/init.d/$s" stop >/dev/null 2>&1 || true
	"/etc/init.d/$s" disable >/dev/null 2>&1 || true
	rm -f "/etc/init.d/$s"
done
for p in udp tcp; do
	while iptables -t nat -D PREROUTING -i br-lan -p "$p" --dport 53 -j GRU_DNS 2>/dev/null; do :; done
done
iptables -t nat -F GRU_DNS 2>/dev/null && iptables -t nat -X GRU_DNS 2>/dev/null || true
[ -d /etc/gru-adguard ] && [ ! -e /etc/flint-adguard ] && mv /etc/gru-adguard /etc/flint-adguard
rm -rf /etc/gru-adguard /www/gru /usr/share/gru
rm -f /usr/bin/gru-* /etc/dnsmasq.d/gru-*.conf /tmp/dnsmasq.d/gru-*.conf \
	/etc/dnscrypt-proxy2/gru-doh.toml /etc/xray/gru.env /etc/xray/gru-ui.pass
sed -i '/\/usr\/bin\/gru-/d' /etc/crontabs/root 2>/dev/null || true
for sec in gru_ui81 gru_ui gru_upstream_in gru_upstream_fwd; do uci -q delete "firewall.$sec" || true; done
if [ -f /etc/nginx/conf.d/gru-ui.conf ]; then
	rm -f /etc/nginx/conf.d/gru-ui.conf
	/etc/init.d/nginx reload || true
fi
if [ -x /etc/init.d/v2raya ]; then
	/etc/init.d/v2raya stop 2>/dev/null || true
	/etc/init.d/v2raya disable 2>/dev/null || true
fi
sed -i '/dnscrypt-proxy -config/d' /etc/rc.local
rm -f /etc/firewall.user.d-local-hosts /etc/firewall.user.d-upstream-lan \
	/etc/dnsmasq.d/local-hosts.conf /tmp/dnsmasq.d/local-hosts.conf \
	/etc/xray/nodes.tsv
rm -rf /etc/xray/nodes

say "files"
mkdir -p /etc/xray /etc/dnscrypt-proxy2 /etc/dnsmasq.d /www/flint/cgi-bin /usr/share/flint
cp "$KIT/files/etc/xray/template.json" /etc/xray/
cp "$KIT/files/usr/share/flint/vless.awk" "$KIT/files/usr/share/flint/lib.sh" /usr/share/flint/
ln -sf /etc/xray/flint.env /usr/share/flint/env
echo "$VERSION" > /usr/share/flint/version
cp "$KIT/files/etc/init.d/xray" "$KIT/files/etc/init.d/flint-ui" "$KIT/files/etc/init.d/flint-doh" \
	"$KIT/files/etc/init.d/flint-adblock" /etc/init.d/
cp "$KIT/files/etc/dnscrypt-proxy2/flint-doh.toml" /etc/dnscrypt-proxy2/
cp "$KIT/files/etc/firewall.user" /etc/firewall.user
cp "$KIT/files/usr/bin/flint-node" "$KIT/files/usr/bin/flint-geo-update" "$KIT/files/usr/bin/flint-sub-update" \
	"$KIT/files/usr/bin/flint-custom" "$KIT/files/usr/bin/flint-watchdog" "$KIT/files/usr/bin/flint-adblock" /usr/bin/
cp "$KIT/files/www/flint/index.html" "$KIT/files/www/flint/logo.svg" "$KIT/files/www/flint/icon.svg" \
	"$KIT/files/www/flint/panel.css" /www/flint/
cp "$KIT/files/www/flint/cgi-bin/panel.cgi" /www/flint/cgi-bin/
chmod 755 /etc/init.d/xray /etc/init.d/flint-ui /etc/init.d/flint-doh /etc/init.d/flint-adblock /usr/bin/flint-node \
	/usr/bin/flint-geo-update /usr/bin/flint-sub-update /usr/bin/flint-custom /usr/bin/flint-watchdog /usr/bin/flint-adblock \
	/www/flint/cgi-bin/panel.cgi

# User state from config/ (names in state-files); an entry missing there keeps the router's copy.
# nodes.d only seeds a router without subscription servers: the router keeps its own list fresh.
grep -v -E '^(#|$)' "$KIT/state-files" | while read -r f; do
	[ -e "$KIT/config/$f" ] || continue
	if [ "$f" = nodes.d ] && [ -n "$(ls /etc/xray/nodes.d 2>/dev/null)" ]; then continue; fi
	rm -rf "/etc/xray/$f"
	(umask 077; cp -R "$KIT/config/$f" "/etc/xray/$f")
done
# Legacy nodes.conf with "#@ <id>" groups → nodes.d/<id>.conf (keeps nodes.conf.bak); existing nodes.d files win.
if [ -f /etc/xray/nodes.conf ] && grep -q '^#@' /etc/xray/nodes.conf; then
	say "migrate nodes.conf groups into nodes.d/"
	mkdir -p /etc/xray/nodes.d
	cp /etc/xray/nodes.conf /etc/xray/nodes.conf.bak
	first="$(head -n1 /etc/xray/subscriptions 2>/dev/null | cut -f1)"
	awk -v dir=/etc/xray/nodes.d -v first="$first" '
		/^#@/ { g = $2; next }
		{
			if (g == "") pend = pend $0 ORS
			else if (g == "-") manual = manual $0 ORS
			else { blocks[g] = blocks[g] $0 ORS; ids[g] = 1 }
		}
		END {
			if (pend != "") {
				if (first != "") { blocks[first] = pend blocks[first]; ids[first] = 1 }
				else manual = pend manual
			}
			for (id in ids) {
				if (id == "" || id == "-") continue
				f = dir "/" id ".conf"
				if (system("[ -s " f " ]") == 0) continue
				printf "%s", blocks[id] > f
				close(f)
			}
			printf "%s", manual > dir "/../nodes.conf.migrated"
		}' /etc/xray/nodes.conf
	mv /etc/xray/nodes.conf.migrated /etc/xray/nodes.conf
fi
case "${ROUTING:-ru}" in
	ru|global) echo "${ROUTING:-ru}" > /etc/xray/routing-mode ;;
	*) die "ROUTING must be ru or global" ;;
esac

LAN_IP="$(uci -q get network.lan.ipaddr || echo 192.168.8.1)"
LAN_IP="${LAN_IP%%/*}"
sed "s/__LAN_IP__/$LAN_IP/g" "$KIT/files/etc/dnsmasq.d/flint-names.conf" > /etc/dnsmasq.d/flint-names.conf
: > /etc/dnsmasq.d/flint-hosts.conf
for pair in $LOCAL_HOSTS; do
	name="${pair%%=*}"; ip="${pair#*=}"
	for n in "$name" "$name.lan" "$name.local"; do
		echo "address=/$n/$ip" >> /etc/dnsmasq.d/flint-hosts.conf
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
uci set firewall.flint_ui=rule
uci set firewall.flint_ui.name='Allow-Flint-UI'
uci set firewall.flint_ui.src='lan'
uci set firewall.flint_ui.dest_port='81'
uci set firewall.flint_ui.proto='tcp'
uci set firewall.flint_ui.target='ACCEPT'
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
uci -q delete firewall.flint_upstream_in || true
uci -q delete firewall.flint_upstream_fwd || true
if [ -n "$UPSTREAM_NET" ]; then
	uci set firewall.flint_upstream_in=rule
	uci set firewall.flint_upstream_in.name='Allow-Upstream-LAN-to-Router'
	uci set firewall.flint_upstream_in.src='wan'
	uci set firewall.flint_upstream_in.src_ip="$UPSTREAM_NET"
	uci set firewall.flint_upstream_in.proto='all'
	uci set firewall.flint_upstream_in.target='ACCEPT'
	uci set firewall.flint_upstream_fwd=rule
	uci set firewall.flint_upstream_fwd.name='Allow-Upstream-LAN-to-LAN'
	uci set firewall.flint_upstream_fwd.src='wan'
	uci set firewall.flint_upstream_fwd.dest='lan'
	uci set firewall.flint_upstream_fwd.src_ip="$UPSTREAM_NET"
	uci set firewall.flint_upstream_fwd.proto='all'
	uci set firewall.flint_upstream_fwd.target='ACCEPT'
fi
uci commit firewall

say "services"
for pid in $(pidof dnscrypt-proxy); do
	grep -q flint-doh.toml /proc/$pid/cmdline 2>/dev/null || kill "$pid" 2>/dev/null || true
done
/etc/init.d/flint-doh enable
/etc/init.d/flint-doh restart
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
/etc/init.d/firewall reload
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
