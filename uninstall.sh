#!/usr/bin/env bash
# Remove Flint VPN from the router (macOS/Linux): back up with backup.sh first, then run kit/uninstall.sh there.
# Usage: ./uninstall.sh [--keep-xray] [--no-backup] [--yes] [router_ip] [user]
#   The firmware, network and Wi-Fi stay; LAN devices go online directly. restore.sh brings Flint back.
#   --keep-xray  keep the xray-core package.
#   --no-backup  skip the backup (by default the settings go to backup/<date> and config/).
set -euo pipefail
OPTS=""; BACKUP=1; YES=0
while [ $# -gt 0 ]; do
	case "$1" in
		--keep-xray) OPTS=" --keep-xray"; shift ;;
		--no-backup) BACKUP=0; shift ;;
		--yes) YES=1; shift ;;
		*) break ;;
	esac
done
ROUTER="${1:-192.168.8.1}"
USER_NAME="${2:-root}"
TARGET="$USER_NAME@$ROUTER"
ROOT="$(cd "$(dirname "$0")" && pwd)"

if [ "$YES" != 1 ]; then
	read -r -p "Remove Flint VPN from $TARGET? [y/N] " answer
	case "$answer" in y|Y) ;; *) echo "Cancelled"; exit 1 ;; esac
fi
if [ "$BACKUP" = 1 ]; then bash "$ROOT/backup.sh" "$ROUTER" "$USER_NAME"; fi

tr -d '\r' < "$ROOT/kit/uninstall.sh" | ssh "$TARGET" "cat > /tmp/flint-uninstall.sh"
ssh "$TARGET" "sh /tmp/flint-uninstall.sh$OPTS; rc=\$?; rm -f /tmp/flint-uninstall.sh; exit \$rc"
