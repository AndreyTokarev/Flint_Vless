#!/usr/bin/env bash
# Deploy this checkout (deploy.sh --keep-kit), upload the router test scenarios and run them on the router (macOS/Linux).
# The router ends up with this code and the settings from config/ (as after a deploy).
# Takes 5-10 minutes; some scenarios empty the router, so servers vanish and LAN goes direct until each restores the state.
# Usage: ./tests/run.sh [router_ip] [empty redeploy subscription own-server failover panel]
set -euo pipefail
ROUTER="${1:-192.168.8.1}"; shift || true
TARGET="root@$ROUTER"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

bash "$ROOT/deploy.sh" --keep-kit "$ROUTER"

COPYFILE_DISABLE=1 tar --format ustar -cf - -C "$ROOT/tests" router |
	ssh "$TARGET" "cat > /tmp/flint-test.tar"

ssh "$TARGET" "rm -rf /tmp/flint-test && mkdir -p /tmp/flint-test && tar -xf /tmp/flint-test.tar -C /tmp/flint-test && rm -f /tmp/flint-test.tar && \
find /tmp/flint-test -type f -exec sed -i 's/\r\$//' {} + && \
sh /tmp/flint-test/router/all.sh /tmp/flint-kit $*; rc=\$?; rm -rf /tmp/flint-test /tmp/flint-kit; exit \$rc"
