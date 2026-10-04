# Shared helpers for Flint shell tools (sourced, not executed).
# The flint-* commands do not use set -e: errors are checked explicitly (fail); only install.sh stops on any error.
NODES=/etc/xray/nodes.conf
NODES_D=/etc/xray/nodes.d
CUSTOM=/etc/xray/nodes-custom.conf
SUBS=/etc/xray/subscriptions
CUR=/etc/xray/current-node
TAB="$(printf '\t')"
fail() { echo "$1"; exit 1; }
# Language: FLINT_LANG (panel), else UI_LANG (flint.env), else Russian.
t() { if [ "${FLINT_LANG:-${UI_LANG:-ru}}" = en ]; then echo "$2"; else echo "$1"; fi; }
# Server lines from the given files (missing files and a call with no args are fine).
node_lines() {
	files=
	for f in "$@"; do [ -f "$f" ] && files="$files$f "; done
	[ -n "$files" ] || return 0
	# shellcheck disable=SC2086
	cat $files | grep -v -E '^[[:space:]]*(#|$)'
}
# Server files: manual nodes.conf, nodes.d/<id>.conf of each listed subscription, own nodes-custom.conf.
node_files() {
	if [ -f "$NODES" ]; then echo "$NODES"; fi
	if [ -f "$SUBS" ]; then
		for id in $(cut -f1 "$SUBS"); do
			if [ -f "$NODES_D/$id.conf" ]; then echo "$NODES_D/$id.conf"; fi
		done
	fi
	if [ -f "$CUSTOM" ]; then echo "$CUSTOM"; fi
}
# "code name address port uuid sni pbk sid net service group" (TAB-separated) for every server in the
# given files (default: node_files), defaults filled in. The name is the comment line right above the server;
# group is the subscription id, "own" (nodes-custom.conf) or "-" (manual nodes.conf).
nodes_tsv() {
	[ $# -gt 0 ] || set -- $(node_files)
	for f in "$@"; do
		[ -f "$f" ] || continue
		case "$f" in
			"$CUSTOM") g=own ;;
			"$NODES_D"/*) g="${f##*/}"; g="${g%.conf}" ;;
			*) g=- ;;
		esac
		awk -v g="$g" -v u="$VLESS_UUID" -v OFS='\t' '
			/^[[:space:]]*#/ { sub(/^[[:space:]]*#[[:space:]]*/, ""); name = $0; next }
			/^[[:space:]]*$/ { next }
			{ print $1, ((name != "" && name !~ /^Generated/) ? name : $1), $2, ($7 != "" ? $7 : 443), ($6 != "" ? $6 : u),
				$3, $4, ($5 != "" ? $5 : "-"), ($8 != "" ? $8 : "tcp"), ($9 != "" ? $9 : "-"), g
			  name = "" }' "$f"
	done
}
host_of() { echo "$1" | sed -e 's|^[a-zA-Z]*://||' -e 's|[/:?#].*||'; }
