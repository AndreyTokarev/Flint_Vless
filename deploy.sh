#!/usr/bin/env bash
# Upload the kit with config/gru.env + config/nodes.conf to the router and run install.sh (macOS/Linux).
# Usage: ./deploy.sh [router_ip] [user]
set -euo pipefail
ROUTER="${1:-192.168.8.1}"
USER_NAME="${2:-root}"
TARGET="$USER_NAME@$ROUTER"
ROOT="$(cd "$(dirname "$0")" && pwd)"

for f in gru.env nodes.conf; do
	[ -f "$ROOT/config/$f" ] || {
		echo "Missing config/$f - copy config/$f.example and fill it in (or restore from backup)." >&2
		exit 1
	}
done

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$ROOT/kit/." "$STAGING/"
mkdir -p "$STAGING/config"
for f in gru.env nodes.conf nodes-custom.conf custom-sites; do
	if [ -f "$ROOT/config/$f" ]; then cp "$ROOT/config/$f" "$STAGING/config/"; fi
done
if [ -f "$ROOT/backup/bin/xray" ]; then
	mkdir -p "$STAGING/bin"
	cp "$ROOT/backup/bin/xray" "$STAGING/bin/"
fi

# COPYFILE_DISABLE keeps macOS tar from adding ._* AppleDouble files.
COPYFILE_DISABLE=1 tar --format ustar -cf - -C "$STAGING" . |
	ssh "$TARGET" "cat > /tmp/gru-kit.tar"

ssh "$TARGET" "rm -rf /tmp/gru-kit && mkdir -p /tmp/gru-kit && tar -xf /tmp/gru-kit.tar -C /tmp/gru-kit && rm -f /tmp/gru-kit.tar && \
find /tmp/gru-kit -type f ! -path '/tmp/gru-kit/bin/*' -exec sed -i 's/\r\$//' {} + && \
sh /tmp/gru-kit/install.sh; rc=\$?; rm -rf /tmp/gru-kit; exit \$rc"
