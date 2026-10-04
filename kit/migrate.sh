# Migrations from older kits, sourced by install.sh. Each one does nothing on an up-to-date router;
# delete a migration once no router runs the version it comes from.

# Before 0.7.0 the kit used the gru- prefix (services, files, cron jobs, firewall rules); even older
# setups ran v2rayA, dnscrypt-proxy from rc.local, local-hosts files and /etc/xray/nodes.tsv.
migrate_legacy_files() {
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
	if [ -d /etc/gru-adguard ] && [ ! -e /etc/flint-adguard ]; then mv /etc/gru-adguard /etc/flint-adguard; fi
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
	sed -i '/dnscrypt-proxy -config/d' /etc/rc.local 2>/dev/null || true
	rm -f /etc/firewall.user.d-local-hosts /etc/firewall.user.d-upstream-lan \
		/etc/dnsmasq.d/local-hosts.conf /tmp/dnsmasq.d/local-hosts.conf /etc/xray/nodes.tsv
	rm -rf /etc/xray/nodes
	# Up to 1.3.0 the panel read flint.env through this link.
	rm -f /usr/share/flint/env
}

# 1.1.x kept every server in nodes.conf with "#@ <id>" group lines: split it into nodes.d/<id>.conf
# (unmarked lines go to the first subscription), keep nodes.conf.bak; existing nodes.d files win.
migrate_nodes_groups() {
	[ -f /etc/xray/nodes.conf ] && grep -q '^#@' /etc/xray/nodes.conf || return 0
	echo "== migrate nodes.conf groups into nodes.d/"
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
}
