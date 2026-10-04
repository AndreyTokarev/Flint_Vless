#!/bin/sh
# Removes Flint VPN from the router: services, files, settings in /etc/xray, firewall rules, cron jobs,
# the DNS changes and the xray-core package. The firmware, its packages, network and Wi-Fi stay:
# LAN devices go online directly, DNS comes from the main router as on a fresh firmware.
# Usage: sh uninstall.sh [--keep-xray]     --keep-xray keeps the xray-core package and /usr/bin/xray
KEEP_XRAY=0
[ "$1" = --keep-xray ] && KEEP_XRAY=1
say() { echo "== $*"; }
# Deletes every copy of a rule.
del() { t=$1; c=$2; shift 2; while iptables -t "$t" -D "$c" "$@" 2>/dev/null; do :; done; }
# rom_dnsmasq <option>: the firmware default for a dnsmasq option, empty when unset.
rom_dnsmasq() { uci -q -c /rom/etc/config get "dhcp.@dnsmasq[0].$1"; }

echo "Flint VPN $(cat /usr/share/flint/version 2>/dev/null || echo "?"): uninstall"
# UPSTREAM_IF and UPSTREAM_NET name the rules for the main router's network.
# Ash aborts on a missing `.` file even without set -e, so check first.
[ -f /etc/xray/flint.env ] && . /etc/xray/flint.env

say "services"
for s in flint-ui flint-adblock flint-doh xray; do
	[ -x "/etc/init.d/$s" ] || continue
	"/etc/init.d/$s" stop >/dev/null 2>&1
	"/etc/init.d/$s" disable >/dev/null 2>&1
done

say "firewall"
for p in udp tcp; do del nat PREROUTING -i br-lan -p "$p" --dport 53 -j FLINT_DNS; done
del nat PREROUTING -i br-lan -p tcp -j XRAY
del filter FORWARD -i br-lan -p udp --dport 443 -j DROP
for ch in XRAY FLINT_DNS; do
	iptables -t nat -F "$ch" 2>/dev/null && iptables -t nat -X "$ch" 2>/dev/null
done
if [ -n "$UPSTREAM_IF" ] && [ -n "$UPSTREAM_NET" ]; then
	del nat POSTROUTING -o "$UPSTREAM_IF" -d "$UPSTREAM_NET" -j MASQUERADE
	del filter FORWARD -i br-lan -o "$UPSTREAM_IF" -d "$UPSTREAM_NET" -j ACCEPT
	del filter FORWARD -i "$UPSTREAM_IF" -o br-lan -s "$UPSTREAM_NET" -j ACCEPT
fi
for sec in flint_ui xray_socks xray_http flint_upstream_in flint_upstream_fwd; do uci -q delete "firewall.$sec"; done
while sec="$(uci -q show firewall | sed -n "s|^firewall\.\([^.]*\)\.path='/etc/firewall\.user'$|\1|p" | head -n1)" && [ -n "$sec" ]; do
	uci delete "firewall.$sec" || break
done
uci commit firewall
rm -f /etc/firewall.user

say "DNS: back to the firmware defaults"
uci -q delete dhcp.@dnsmasq[0].server
for s in $(uci -q -c /rom/etc/config get dhcp.@dnsmasq[0].server); do uci add_list "dhcp.@dnsmasq[0].server=$s"; done
for o in noresolv confdir rebind_protection; do
	v="$(rom_dnsmasq "$o")"
	if [ -n "$v" ]; then uci set "dhcp.@dnsmasq[0].$o=$v"; else uci -q delete "dhcp.@dnsmasq[0].$o"; fi
done
uci commit dhcp

say "files"
[ -f /etc/crontabs/root ] && sed -i '/\/usr\/bin\/flint-/d' /etc/crontabs/root
rm -rf /etc/xray /etc/flint-adguard /www/flint /usr/share/flint
rm -f /usr/bin/flint-* /etc/init.d/flint-ui /etc/init.d/flint-adblock /etc/init.d/flint-doh \
	/etc/dnsmasq.d/flint-*.conf /tmp/dnsmasq.d/flint-*.conf /etc/dnscrypt-proxy2/flint-doh.toml \
	/tmp/flint-*.log /tmp/flint-ip.* /tmp/flint-adblock.out*
rmdir /etc/dnsmasq.d 2>/dev/null || true

if [ "$KEEP_XRAY" = 1 ]; then
	say "xray: kept (--keep-xray)"
else
	say "xray"
	if opkg status xray-core 2>/dev/null | grep -q '^Status:.* installed'; then
		opkg remove xray-core >/dev/null 2>&1 && echo "xray-core removed" || echo "opkg remove xray-core failed"
	fi
	# Xray from kit/bin or GitHub has no package; geo files without an owning package came from flint-geo-update.
	rm -f /etc/init.d/xray /usr/bin/xray
	for f in /usr/share/xray/geoip.dat /usr/share/xray/geosite.dat; do
		[ -n "$(opkg search "$f" 2>/dev/null)" ] || rm -f "$f"
	done
	rmdir /usr/share/xray 2>/dev/null
fi

say "restart"
/etc/init.d/cron restart >/dev/null 2>&1
/etc/init.d/dnsmasq restart >/dev/null 2>&1
/etc/init.d/firewall reload >/dev/null 2>&1
sleep 2

say "check"
nslookup example.com 127.0.0.1 2>/dev/null | awk '/^Name:/ { n = 1 } n && /^Address/ { ok = 1 } END { exit !ok }' &&
	echo "DNS: ok" || echo "DNS: FAIL (check the main router's internet)"
left="$(
	[ -e /etc/xray ] && echo /etc/xray
	[ -e /www/flint ] && echo /www/flint
	ls /usr/bin/flint-* /etc/init.d/flint-* 2>/dev/null
	iptables -t nat -S 2>/dev/null | grep -E 'XRAY|FLINT_DNS' || true
)"
[ -z "$left" ] && echo "Flint VPN removed. LAN devices go online directly." || { echo "Left over:"; echo "$left"; exit 1; }
