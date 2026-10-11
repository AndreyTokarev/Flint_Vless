# The two lists of state files must stay in step, or a setting silently stops travelling: a backup
# carries kit/state-files, the panel's settings file carries /usr/share/flint/settings-files.
# Usage: sh settings.sh <kit dir>
. "$(dirname "$0")/lib.sh"
KIT="${1:?kit dir}"
echo "== settings: the backup list and the settings-file list agree"

# One list name per line, without comments and empty lines.
names() { grep -v -E '^[[:space:]]*(#|$)' "$1"; }

backup_list="$(names "$KIT/state-files")"
check "the backup list is not empty" [ -n "$backup_list" ]

# flint.env holds the PIN and the network: it is in the backup and deliberately not in the settings file.
check "flint.env is in the backup list" sh -c "printf '%s\n' \"$backup_list\" | grep -qx flint.env"
check "flint.env is not in the settings list" fails sh -c "names /usr/share/flint/settings-files | grep -qx flint.env"

# Everything the settings file carries, except the files that only exist on a router after use, must be
# known to /etc/xray: the check is that the file is either present or would be created by a tool.
known() { grep -qx "$1" /usr/share/flint/settings-files; }
missing=""
for n in $backup_list; do
	known "$n" || missing="$missing $n"
done
# The backup list may hold entries the settings file does not carry (it is the smaller list): at the
# moment that is only flint.env, which is checked above.
check "every other backup entry is in the settings list" [ "$missing" = " flint.env" ]

# A settings entry has to be a name the kit knows: not empty, no slashes outside nodes.d, no spaces.
bad=""
for n in $(names /usr/share/flint/settings-files); do
	case "$n" in
		nodes.d) continue ;;
		*/*|*" "*) bad="$bad $n" ;;
	esac
done
check "settings entries are plain names" [ -z "$bad" ]

# The most common mistake: a new state file is added to a tool but not to the settings list. The tools
# write into /etc/xray, so the files they create there have to be known to one of the two lists.
from_backup() { printf '%s\n' "$backup_list" | grep -qx "$1"; }
from_settings() { names /usr/share/flint/settings-files | grep -qx "$1"; }
unknown=""
for f in /etc/xray/*; do
	[ -e "$f" ] || continue
	n="${f##*/}"
	# Journal files: they say what happened, not what was chosen, so they are in neither list.
	# Generated files: the Xray config and its template are rebuilt by flint-node and install.sh, and
	# the probe file is written by flint-node probe-mode — none of them travel between routers.
	case "$n" in
		sub-status|sub-checked|watchdog-last|flint.env) continue ;;
		config.json|config.json.example|config.json.new|config.json.prev|template.json|probe) continue ;;
		*.sh|*.toml) continue ;;
	esac
	from_backup "$n" || from_settings "$n" || unknown="$unknown $n"
done
check "no state file outside both lists" [ -z "$unknown" ]
[ -z "$unknown" ] || echo "     outside both lists:$unknown"

finish
