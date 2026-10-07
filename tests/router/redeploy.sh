# Redeploy with a stale pre-1.2 config/nodes.conf ("#@" groups): the router's nodes.d/ wins.
# Usage: sh redeploy.sh <kit dir>
. "$(dirname "$0")/lib.sh"
KIT="${1:?kit dir}"
echo "== redeploy: stale config/nodes.conf with #@ groups"
save_state
id="$(head -n1 /etc/xray/subscriptions 2>/dev/null | cut -f1)"
if [ -z "$id" ] || [ ! -s "/etc/xray/nodes.d/$id.conf" ]; then echo "  skip: the router has no subscription servers"; finish; exit; fi
line="$(node_lines "/etc/xray/nodes.d/$id.conf" | head -n1)"
mkdir -p "$KIT/config"
rm -rf "$KIT/config/"*
cp /etc/xray/flint.env "$KIT/config/flint.env"
printf '#@ %s\n# stale\nzzstale %s\n' "$id" "${line#* }" > "$KIT/config/nodes.conf"
sh "$KIT/install.sh" > /tmp/flint-test-install.log 2>&1
rc=$?
has_code() { flint-node codes | grep -qx "$1"; }
check "install succeeds" [ "$rc" = 0 ]
check "subscription file kept" fails grep -q '^zzstale' "/etc/xray/nodes.d/$id.conf"
check "stale server not listed" fails has_code zzstale
kept() { [ -n "$1" ] && sysupgrade -l 2>/dev/null | grep -qx "$1"; }
check "firmware upgrade keeps the settings" kept /etc/xray/flint.env
check "firmware upgrade keeps the panel" kept /www/flint/cgi-bin/panel.cgi
check "firmware upgrade keeps xray" kept /usr/bin/xray
check "firmware upgrade keeps xray autostart" kept "$(ls /etc/rc.d/S*xray 2>/dev/null | head -n1)"
check "firmware upgrade keeps its own list" kept /lib/upgrade/keep.d/flint
vpn_mode
rm -rf /tmp/flint-test-install.log "$KIT/config/"*
finish
