#!/bin/sh
# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# Checks that the files the router runs are POSIX shell and have LF line endings: a file with CRLF is
# not parsed by busybox ash at all, and that failure looks like a broken script on the router while the
# repository looks fine. Runs in CI and locally:
#   sh tools/check-scripts.sh
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 2
fail=0

say() { echo "== $*"; }
note() { echo "!! $*" >&2; fail=1; }

# 1. Every script in the kit parses. sh -n is POSIX and catches what busybox catches (misspellings of
#    keywords, unbalanced quotes), except for the busybox specifics themselves.
say "shell syntax"
for f in $(find kit -type f \( -name '*.sh' -o -name 'flint-*' -o -name 'panel.cgi' -o -name 'firewall.user' -o -name '*.awk' \) | sort); do
	case "$f" in
		*.awk) continue ;;
	esac
	sh -n "$f" 2>/tmp/flint-check-syntax ||
		{ note "$f does not parse:"; cat /tmp/flint-check-syntax >&2; }
done
rm -f /tmp/flint-check-syntax

# 2. No CRLF in the files that go to the router. The binaries under kit/bin are skipped: they are
#    archives, not scripts.
say "line endings"
crlf="$(find kit -type f ! -path 'kit/bin/*' -exec sh -c 'tr -d "\000-\176" < "$1" | grep -q "$(printf "\r")" && echo "$1"' _ {} \; 2>/dev/null)"
if [ -n "$crlf" ]; then
	for f in $crlf; do note "$f has CRLF endings"; done
fi

# 3. The Xray template: placeholders are substituted by type (a port cannot become a string) and every
#    placeholder in the template must be known to flint-node: a new one that nobody substitutes would
#    reach a router as "__SOMETHING__" inside the config.
say "xray template"
if command -v python3 >/dev/null 2>&1; then
	python3 - <<'EOF' || note "the Xray template did not pass the check"
import json, re, sys

TEMPLATE = "kit/files/etc/xray/template.json"
# What flint-node renders. Numbers first: the port is a JSON number.
NUMBERS = {"__PORT__"}
ARRAYS = {
    "__PROVIDER_DOMAINS__", "__CUSTOM_PROXY_DOMAIN__", "__CUSTOM_PROXY_IP__",
    "__CUSTOM_DIRECT_DOMAIN__", "__CUSTOM_DIRECT_IP__",
}
STRINGS = {"__UUID__", "__ADDR__", "__SNI__", "__PBK__", "__SID__", "__NET__", "__FLOW__",
           "__GRPC_SERVICE__", "__DOMAIN_STRATEGY__"}

text = open(TEMPLATE, encoding="utf-8").read()
found = set(re.findall(r"__[A-Z_]+__", text))
unknown = found - NUMBERS - ARRAYS - STRINGS
unused = (NUMBERS | ARRAYS | STRINGS) - found
ok = True
if unknown:
    print("!! placeholders nobody substitutes:", ", ".join(sorted(unknown)), file=sys.stderr)
    ok = False
if unused:
    print("   note: known placeholders that the template no longer uses:",
          ", ".join(sorted(unused)), file=sys.stderr)

filled = text
for name in NUMBERS:
    filled = filled.replace(name, "1")
for name in ARRAYS:
    filled = filled.replace(name, '"example.com"')
for name in STRINGS:
    filled = filled.replace(name, "x")
try:
    config = json.loads(filled)
except Exception as error:
    print(f"!! template is not valid JSON once filled: {error}", file=sys.stderr)
    ok = False
else:
    # The rendered config must still have the parts the project relies on.
    tags = [i.get("tag") for i in config.get("inbounds", [])]
    out_tags = [o.get("tag") for o in config.get("outbounds", [])]
    for want in ("transparent", "http-in", "socks-in", "dns-in"):
        if want not in tags:
            print(f"!! the template lost the {want} inbound", file=sys.stderr)
            ok = False
    for want in ("proxy", "direct", "block", "dns-out"):
        if want not in out_tags:
            print(f"!! the template lost the {want} outbound", file=sys.stderr)
            ok = False
sys.exit(0 if ok else 1)
EOF
else
	echo "   python3 is not available: the template was not checked"
fi

if [ "$fail" = 0 ]; then echo "ok: scripts, endings and template are fine"; fi
exit "$fail"
