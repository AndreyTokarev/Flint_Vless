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

# User state (kit/state-files) as one archive, then unpacked over config/.
NAMES="$(grep -v -E '^(#|$)' "$ROOT/kit/state-files" | tr -d '\r' | tr '\n' ' ')"
if ssh "$TARGET" "cd /etc/xray && tar -czf - \$(ls -d $NAMES 2>/dev/null)" > "$DIR/state.tar.gz"; then
	for name in $(tar -tzf "$DIR/state.tar.gz" | cut -d/ -f1 | sort -u); do
		rm -rf "${ROOT:?}/config/$name"
		echo "Refreshed config/$name"
	done
	tar -xzf "$DIR/state.tar.gz" -C "$ROOT/config"
else
	echo "No user state on the router: config/ is kept"
fi

if [ "$WITH_BINARY" = 1 ]; then
	mkdir -p "$ROOT/backup/bin"
	ssh "$TARGET" "cat /usr/bin/xray" > "$ROOT/backup/bin/xray"
	echo "Saved backup/bin/xray"
fi
