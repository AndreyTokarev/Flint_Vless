# Run the given scenarios (default: all) one after another; exit 1 if any failed.
# Usage: sh all.sh <kit dir> [empty|redeploy|subscription|own-server|failover|panel ...]
DIR="$(dirname "$0")"
KIT="${1:?kit dir}"; shift
[ $# -gt 0 ] || set -- empty redeploy subscription own-server failover panel
rc=0
for s in "$@"; do
	sh "$DIR/$s.sh" "$KIT" || rc=1
done
[ "$rc" = 0 ] && echo "ALL PASSED" || echo "SOME FAILED"
exit $rc
