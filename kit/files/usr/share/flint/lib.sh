# Shared helpers for Flint shell tools (sourced, not executed).
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
host_of() { echo "$1" | sed -e 's|^[a-zA-Z]*://||' -e 's|[/:?#].*||'; }
