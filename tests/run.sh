#!/usr/bin/env bash
# Upload the kit and the router test scenarios and run them on the router (macOS/Linux).
# The empty scenario installs this checkout's kit, so the router ends up with this code (its settings are kept).
# Usage: ./tests/run.sh [router_ip] [empty subscription own-server failover]
set -euo pipefail
ROUTER="${1:-192.168.8.1}"; shift || true
TARGET="root@$ROUTER"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$ROOT/kit" "$STAGING/kit"
cp -R "$ROOT/tests/router" "$STAGING/router"

COPYFILE_DISABLE=1 tar --format ustar -cf - -C "$STAGING" . |
	ssh "$TARGET" "cat > /tmp/flint-test.tar"

ssh "$TARGET" "rm -rf /tmp/flint-test && mkdir -p /tmp/flint-test && tar -xf /tmp/flint-test.tar -C /tmp/flint-test && rm -f /tmp/flint-test.tar && \
find /tmp/flint-test -type f -exec sed -i 's/\r\$//' {} + && \
sh /tmp/flint-test/router/all.sh /tmp/flint-test/kit $*; rc=\$?; rm -rf /tmp/flint-test; exit \$rc"
