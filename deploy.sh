#!/usr/bin/env bash
# Upload the kit with config/flint.env (+ config/nodes.conf and other saved lists, if any) to the router and run install.sh (macOS/Linux).
# Usage: ./deploy.sh [router_ip] [user]
set -euo pipefail
ROUTER="${1:-192.168.8.1}"
USER_NAME="${2:-root}"
TARGET="$USER_NAME@$ROUTER"
ROOT="$(cd "$(dirname "$0")" && pwd)"

[ -f "$ROOT/config/flint.env" ] || {
	echo "Missing config/flint.env - copy config/flint.env.example and fill it in (or restore from backup)." >&2
	exit 1
}

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$ROOT/kit/." "$STAGING/"
mkdir -p "$STAGING/config"
for f in flint.env nodes.conf nodes-custom.conf custom-sites subscriptions adblock-lists adblock-rules adblock-exclude; do
	if [ -f "$ROOT/config/$f" ]; then cp "$ROOT/config/$f" "$STAGING/config/"; fi
done
if [ -f "$ROOT/backup/bin/xray" ]; then
	mkdir -p "$STAGING/bin"
	cp "$ROOT/backup/bin/xray" "$STAGING/bin/"
fi

# COPYFILE_DISABLE keeps macOS tar from adding ._* AppleDouble files.
COPYFILE_DISABLE=1 tar --format ustar -cf - -C "$STAGING" . |
	ssh "$TARGET" "cat > /tmp/flint-kit.tar"

ssh "$TARGET" "rm -rf /tmp/flint-kit && mkdir -p /tmp/flint-kit && tar -xf /tmp/flint-kit.tar -C /tmp/flint-kit && rm -f /tmp/flint-kit.tar && \
find /tmp/flint-kit -type f ! -path '/tmp/flint-kit/bin/*' -exec sed -i 's/\r\$//' {} + && \
sh /tmp/flint-kit/install.sh; rc=\$?; rm -rf /tmp/flint-kit; exit \$rc"
