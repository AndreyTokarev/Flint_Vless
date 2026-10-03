#!/bin/sh
# Run on the Flint router: allow the upstream LAN (TP-Link, 192.168.0.0/24) to reach
# the Flint itself (SSH, admin UI, panel) and devices behind it (192.168.8.0/24).
# The same rules are part of install.sh; this is the standalone version.
# Usage: sh upstream-access.sh [upstream_net]
set -e
NET="${1:-192.168.0.0/24}"

uci set firewall.gru_upstream_in=rule
uci set firewall.gru_upstream_in.name='Allow-Upstream-LAN-to-Router'
uci set firewall.gru_upstream_in.src='wan'
uci set firewall.gru_upstream_in.src_ip="$NET"
uci set firewall.gru_upstream_in.proto='all'
uci set firewall.gru_upstream_in.target='ACCEPT'

uci set firewall.gru_upstream_fwd=rule
uci set firewall.gru_upstream_fwd.name='Allow-Upstream-LAN-to-LAN'
uci set firewall.gru_upstream_fwd.src='wan'
uci set firewall.gru_upstream_fwd.dest='lan'
uci set firewall.gru_upstream_fwd.src_ip="$NET"
uci set firewall.gru_upstream_fwd.proto='all'
uci set firewall.gru_upstream_fwd.target='ACCEPT'

uci commit firewall
/etc/init.d/firewall reload
[ -f /etc/firewall.user ] && sh /etc/firewall.user

echo "Upstream IP of this router:"
ip -4 addr show dev sta1 2>/dev/null | sed -n 's/.*inet \([0-9.]*\).*/  \1/p'
echo "Zone of sta1: $(uci show firewall | sed -n "s/^firewall\.\([^.]*\)\.network=.*wwan.*/\1/p" | head -n1)"
