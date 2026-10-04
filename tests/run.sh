#!/usr/bin/env bash
# Test this checkout on the router (macOS/Linux): upload the kit (deploy.sh --upload-only) and the scenarios; install.sh
# and the scenarios then run in the background on the router (tests/router/job.sh), so a dropped connection does not stop them.
# The script follows the log until the run ends. Run it again after a drop: if the router already has this run (same
# commit, working-tree changes and scenarios), it follows that run instead of starting over. --force starts a new run.
# The router ends up with this code and the settings from config/ (as after a deploy).
# Takes 5-10 minutes; some scenarios empty the router, so servers vanish and LAN goes direct until each restores the state.
# Usage: ./tests/run.sh [--force] [router_ip] [empty redeploy subscription own-server failover panel]
set -uo pipefail
FORCE=0
if [ "${1:-}" = "--force" ]; then FORCE=1; shift; fi
ROUTER="${1:-192.168.8.1}"; shift || true
TARGET="root@$ROUTER"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 "$TARGET")
# The run id: the tree hash of the tracked files as they are now (with uncommitted changes) and the scenarios.
STASH="$(git -C "$ROOT" stash create 2>/dev/null)"
TREE="$(git -C "$ROOT" rev-parse "${STASH:-HEAD}^{tree}")"
ID="$TREE${*:+ $*}"
# "<running|done|none> <run id>": done = the log ends with the summary line of job.sh.
STATUS='id=$(cat /tmp/flint-test.run 2>/dev/null); if [ -f /tmp/flint-test.pid ] && kill -0 $(cat /tmp/flint-test.pid) 2>/dev/null; then s=running;
elif tail -n1 /tmp/flint-test.log 2>/dev/null | grep -qE "^(ALL PASSED|SOME FAILED)"; then s=done; else s=none; fi; echo $s $id'
run_state() { "${SSH[@]}" "$STATUS" 2>/dev/null; }

state="$(run_state)"
if [ "$FORCE" = 0 ] && [ -n "$state" ] && [ "${state#* }" = "$ID" ] && [ "${state%% *}" != none ]; then
	echo "The router already has this run (${state%% *}): following it instead of starting over"
else
	[ "${state%% *}" != running ] || { echo "Another test run is in progress on the router: wait for it to end" >&2; exit 1; }
	bash "$ROOT/deploy.sh" --upload-only "$ROUTER" || exit 1
	COPYFILE_DISABLE=1 tar --format ustar -cf - -C "$ROOT/tests" router | "${SSH[@]}" "cat > /tmp/flint-test.tar" || exit 1
	"${SSH[@]}" "rm -rf /tmp/flint-test && mkdir -p /tmp/flint-test && tar -xf /tmp/flint-test.tar -C /tmp/flint-test && rm -f /tmp/flint-test.tar && \
find /tmp/flint-test -type f -exec sed -i 's/\r\$//' {} + && echo $ID > /tmp/flint-test.run && rm -f /tmp/flint-test.log && \
sh -c 'sh /tmp/flint-test/router/job.sh /tmp/flint-kit $* </dev/null >/tmp/flint-test.log 2>&1 &'" || { echo "starting the tests failed" >&2; exit 1; }
	sleep 5
fi

shown=0; last=""; offline=0; deadline=$((SECONDS + 1800))
while :; do
	if state="$(run_state)" && [ -n "$state" ] && lines="$("${SSH[@]}" "tail -n +$((shown + 1)) /tmp/flint-test.log 2>/dev/null")"; then
		offline=0
		if [ -n "$lines" ]; then
			printf '%s\n' "$lines" | sed 's/pass=[^&[:space:]]*/pass=***/g'
			shown=$((shown + $(printf '%s\n' "$lines" | wc -l)))
			last="$(printf '%s\n' "$lines" | tail -n1)"
		fi
		[ "${state#* }" = "$ID" ] || { echo "The router log belongs to another run: ${state#* }" >&2; exit 1; }
		case "${state%% *}" in
			done) break ;;
			none) echo "The run stopped without a result (router rebooted?): see /tmp/flint-test.log" >&2; exit 1 ;;
		esac
	elif [ "$offline" = 0 ]; then
		echo "  (router unreachable; the run goes on there, retrying)"
		offline=1
	fi
	[ "$SECONDS" -lt "$deadline" ] || { echo "No result after 30 minutes" >&2; exit 1; }
	sleep 10
done
case "$last" in "ALL PASSED"*) ;; *) exit 1 ;; esac
