#!/usr/bin/env bash
# Pull the live router setup into backup/<timestamp>/ and refresh config/ from the router (macOS/Linux).
# Usage: ./backup.sh [--with-binary] [router_ip] [user]
#   --with-binary also saves /usr/bin/xray to backup/bin/xray (used by deploy.sh if opkg fails).
set -euo pipefail
WITH_BINARY=0
if [ "${1:-}" = "--with-binary" ]; then WITH_BINARY=1; shift; fi
ROUTER="${1:-192.168.8.1}"
USER_NAME="${2:-root}"
TARGET="$USER_NAME@$ROUTER"
ROOT="$(cd "$(dirname "$0")" && pwd)"
DIR="$ROOT/backup/$(date +%Y-%m-%d_%H%M)"
mkdir -p "$DIR" "$ROOT/config"

PATHS="/etc/xray /etc/dnscrypt-proxy2 /etc/dnsmasq.d /etc/firewall.user* /etc/init.d/xray /etc/init.d/flint-* \
/usr/bin/flint-* /usr/share/flint /www/flint /etc/config/dhcp /etc/config/firewall /etc/config/network \
/etc/config/wireless /etc/rc.local /etc/hosts /etc/opkg.conf /etc/crontabs/root /etc/dropbear/authorized_keys"
ssh "$TARGET" "tar -czf - $PATHS 2>/dev/null" > "$DIR/router-config.tar.gz" || true
echo "Saved $DIR/router-config.tar.gz"

for f in flint.env nodes.conf nodes-custom.conf custom-sites adblock-lists adblock-rules adblock-exclude; do
	if ssh "$TARGET" "test -f /etc/xray/$f"; then
		ssh "$TARGET" "cat /etc/xray/$f" > "$ROOT/config/$f"
		cp "$ROOT/config/$f" "$DIR/"
		echo "Refreshed config/$f"
	fi
done

if [ "$WITH_BINARY" = 1 ]; then
	mkdir -p "$ROOT/backup/bin"
	ssh "$TARGET" "cat /usr/bin/xray" > "$ROOT/backup/bin/xray"
	echo "Saved backup/bin/xray"
fi
