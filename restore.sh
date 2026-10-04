#!/usr/bin/env bash
# Restore the router from a backup made by backup.sh (macOS/Linux).
# Usage: ./restore.sh [--full] [--yes] [backup/2026-10-03_1557] [router_ip] [user]
#   default: flint.env and the other config/ files (kit/state-files) come from the backup, deploy.sh installs
#            packages and the kit, then every panel setting from the backup is imported (flint-settings) -
#            works on a reset router too.
#   --full   also brings back network, Wi-Fi, firewall, DHCP, hosts, cron and SSH keys from the
#            backup and reboots. Only for the same router: these replace the current settings.
#   The backup defaults to the newest backup/<date> folder.
set -euo pipefail
FULL=0; YES=0
while [ $# -gt 0 ]; do
	case "$1" in
		--full) FULL=1; shift ;;
		--yes) YES=1; shift ;;
		*) break ;;
	esac
done
ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKUP="${1:-}"
ROUTER="${2:-192.168.8.1}"
USER_NAME="${3:-root}"
TARGET="$USER_NAME@$ROUTER"

if [ -z "$BACKUP" ]; then
	BACKUP="$(for d in "$ROOT"/backup/20*/; do if [ -f "$d/router-config.tar.gz" ]; then echo "${d%/}"; fi; done | sort | tail -n1)"
	[ -n "$BACKUP" ] || { echo "No backup/<date>/router-config.tar.gz found - run backup.sh first." >&2; exit 1; }
fi
ARCHIVE="$BACKUP/router-config.tar.gz"
[ -f "$ARCHIVE" ] || { echo "Missing $ARCHIVE" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tar -xzf "$ARCHIVE" -C "$TMP" etc/xray 2>/dev/null || true
# Backups made before the rename keep the settings in gru.env.
if [ -f "$TMP/etc/xray/gru.env" ] && [ ! -f "$TMP/etc/xray/flint.env" ]; then
	mv "$TMP/etc/xray/gru.env" "$TMP/etc/xray/flint.env"
fi
NAMES="$(grep -v -E '^(#|$)' "$ROOT/kit/state-files" | tr -d '\r')"
FOUND=""
for f in $NAMES; do
	if [ -e "$TMP/etc/xray/$f" ]; then FOUND="$FOUND $f"; fi
done

echo "Backup: $BACKUP"
echo "Settings from the backup:${FOUND:- none (current config/ is kept)}"
if [ "$FULL" = 1 ]; then echo "Full: network, Wi-Fi, firewall, DHCP, hosts, cron, SSH keys from the backup, then reboot"; fi
if [ "$YES" != 1 ]; then
	read -r -p "Restore to $TARGET? [y/N] " answer
	case "$answer" in y|Y) ;; *) echo "Cancelled"; exit 1 ;; esac
fi

if [ -n "$FOUND" ]; then
	KEEP="$ROOT/backup/config-before-restore-$(date +%Y-%m-%d_%H%M%S)"
	mkdir -p "$KEEP"
	for f in $NAMES; do
		if [ -e "$ROOT/config/$f" ]; then cp -R "$ROOT/config/$f" "$KEEP/"; fi
	done
	echo "Current config/ saved to $KEEP"
	for f in $FOUND; do
		rm -rf "${ROOT:?}/config/$f"
		cp -R "$TMP/etc/xray/$f" "$ROOT/config/$f"
	done
fi

ssh "$TARGET" "rm -rf /tmp/flint-restore && mkdir -p /tmp/flint-restore && tar -xzf - -C /tmp/flint-restore" < "$ARCHIVE"
if [ "$FULL" = 1 ]; then
	ssh "$TARGET" 'R=/tmp/flint-restore
for f in etc/config/network etc/config/wireless etc/config/firewall etc/config/dhcp etc/hosts etc/rc.local etc/crontabs/root etc/dropbear/authorized_keys; do
	if [ -f $R/$f ]; then mkdir -p /$(dirname $f) && cp $R/$f /$f && echo restored /$f; fi
done'
fi

bash "$ROOT/deploy.sh" "$ROUTER" "$USER_NAME"

# Panel settings outside config/ (modes, DNS, ad blocking, local names, intervals) come from the backup's /etc/xray.
ssh "$TARGET" 'R=/tmp/flint-restore; if [ -d $R/etc/xray ]; then flint-settings export $R/etc/xray > $R/settings.txt && flint-settings import $R/settings.txt; fi; rc=$?; rm -rf $R; exit $rc'

if [ "$FULL" = 1 ]; then
	echo "Rebooting the router to apply network and Wi-Fi settings..."
	ssh "$TARGET" reboot || true
fi
