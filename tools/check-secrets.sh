#!/bin/sh
# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# Checks that no secret is about to be committed: the files a user fills in (config/flint.env,
# config/subscriptions and the rest of kit/state-files) stay out of git, and the values that are on
# this machine must not appear in the index.
#
# Usage: sh tools/check-secrets.sh [--staged]
#        --staged  check the index (what a commit would include); the default checks the working tree
# Exit code 1 with the matching lines when something looks like a secret.
#
# Documentation and the examples are never scanned: they teach the formats on purpose. This script
# itself is skipped too, because it contains the patterns it looks for. Plain sh, no arrays: the router
# and the CI image both run it with a POSIX shell.
set -u
mode="${1:-worktree}"
[ "$mode" = --staged ] && mode=staged

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 2
fail=0
note() { echo "!! $*" >&2; fail=1; }
say() { echo "== $*"; }

# hits <pattern> <pathspec...>: matching lines, or nothing. The last argument is the file or directory to
# search, the ones before it are git pathspecs to leave out.
hits() {
	pattern="$1"
	shift
	if [ "$mode" = staged ]; then
		git grep --cached -n -I -E "$pattern" -- "$@" 2>/dev/null
	else
		git grep -n -I -E "$pattern" -- "$@" 2>/dev/null
	fi
}
# not_docs <file-or-dir>: the exclusions every search uses.
not_docs() { echo "$1"; }

# 1. The user files themselves must not be tracked. config/*.example are the samples and are meant to be.
say "the files a user fills in are not tracked"
for f in flint.env nodes.conf nodes-custom.conf subscriptions custom-sites adblock-lists adblock-rules adblock-exclude nodes.d; do
	git ls-files --error-unmatch "config/$f" >/dev/null 2>&1 && note "config/$f is tracked: it must stay in .gitignore"
done
# The private key of the router is not part of the project either.
git ls-files | grep -qE '(^|/)(id_rsa|id_ed25519)$' && note "a private key is tracked: remove it and rotate the key"

# 2. The values that are on this machine must not be in the index or the working tree.
say "no value from this machine appears in the tracked files"
if [ -f config/subscriptions ]; then
	while IFS="$(printf '\t')" read -r id url name; do
		[ -n "${url:-}" ] || continue
		host="$(printf '%s' "$url" | sed -e 's|^[a-zA-Z]*://||' -e 's|[/:?#].*||')"
		token="$(printf '%s' "$url" | sed -e 's|.*/||' -e 's|?.*||')"
		for value in "$url" "$token"; do
			[ "${#value}" -ge 12 ] || continue
			escaped="$(printf '%s' "$value" | sed 's/[][\\.*^$()+?{}|]/\\&/g')"
			found="$(hits "$escaped" . ':(exclude)docs/***' ':(exclude)*.md' ':(exclude)*.example' ':(exclude)tools/check-secrets.sh')"
			[ -n "$found" ] && { note "a subscription value is in the files:"; echo "$found" >&2; }
		done
		[ -n "$host" ] || continue
		found="$(hits "$host" . ':(exclude)docs/***' ':(exclude)*.md' ':(exclude)*.example' ':(exclude)tools/check-secrets.sh')"
		[ -n "$found" ] && { note "the subscription host $host is in the files:"; echo "$found" >&2; }
	done < config/subscriptions
fi
if [ -f config/flint.env ]; then
	pin="$(sed -n 's/^UI_PIN=//p' config/flint.env | tr -d '"' | head -n1)"
	case "$pin" in
		""|changeme|pin|1234|test) ;;
		*)
			found="$(hits "$pin" . ':(exclude)docs/***' ':(exclude)*.md' ':(exclude)*.example' ':(exclude)tools/check-secrets.sh')"
			[ -n "$found" ] && { note "the panel PIN is in the files:"; echo "$found" >&2; } ;;
	esac
fi

# 3. Shapes that are always a leak, wherever they are: private keys, this router's Wi-Fi password and a
#    real VLESS link with a UUID inside a script.
say "no keys, router passwords or real links"
found="$(hits 'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' . ':(exclude)docs/***' ':(exclude)*.md' ':(exclude)*.example' ':(exclude)tools/check-secrets.sh')"
[ -n "$found" ] && { note "a private key is in the files:"; echo "$found" >&2; }
found="$(hits 'wpa-psk|wireless\.[a-z0-9_]*\.key=' . ':(exclude)docs/***' ':(exclude)*.md' ':(exclude)*.example' ':(exclude)tools/check-secrets.sh')"
[ -n "$found" ] && { note "a Wi-Fi password is in the files:"; echo "$found" >&2; }
found="$(hits 'vless://[0-9a-f-]{36}@' . ':(exclude)docs/***' ':(exclude)*.md' ':(exclude)*.example' ':(exclude)tools/check-secrets.sh')"
[ -n "$found" ] && { note "a real VLESS link is in the files:"; echo "$found" >&2; }

if [ "$fail" = 0 ]; then
	echo "ok: no secrets found ($mode)"
fi
exit "$fail"
