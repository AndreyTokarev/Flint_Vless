# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# Shared by panel.cgi and the tab parts: read from the top of the file.
qs="$QUERY_STRING"
raw() { echo "$qs" | tr '&' '\n' | sed -n "s/^$1=//p" | head -n1; }
get() { raw "$1" | tr -cd 'A-Za-z0-9_-'; }
# URL-decoded value (%XX -> \0ooo -> printf %b); raw backslashes are dropped so only %XX can make bytes.
param() {
  printf '%b' "$(raw "$1" | tr -d '\\' | LC_ALL=C awk 'BEGIN { H = "0123456789ABCDEF" }
    { s = $0; gsub(/\+/, " ", s); out = ""
      while ((x = index(s, "%")) > 0) {
        a = index(H, toupper(substr(s, x + 1, 1))); b = index(H, toupper(substr(s, x + 2, 1)))
        if (a && b) { out = out substr(s, 1, x - 1) sprintf("\\0%03o", (a - 1) * 16 + b - 1); s = substr(s, x + 3) }
        else { out = out substr(s, 1, x); s = substr(s, x + 1) }
      }
      printf "%s", out s }')"
}
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&#39;/g"; }
TAB="$(printf '\t')"
if [ ! -f /etc/xray/flint.env ]; then
  printf 'Content-Type: text/plain; charset=utf-8\n\n%s\n' \
    "Flint VPN: /etc/xray/flint.env is missing. Redeploy (deploy.ps1) or restore a backup (restore.ps1)."
  return 0
fi
. /etc/xray/flint.env

# Language: ?lang= (remembered in a cookie), then the cookie, then UI_LANG, then the browser's first language.
lang="$(get lang)"
case "$lang" in
  ru|en) L="$lang" ;;
  *)
    L="$(echo "$HTTP_COOKIE" | tr ';' '\n' | sed -n -E 's/^ *lang=(ru|en) *$/\1/p' | head -n1)"
    [ -n "$L" ] || case "$UI_LANG" in ru|en) L="$UI_LANG" ;; esac
    if [ -z "$L" ]; then
      case "$(echo "$HTTP_ACCEPT_LANGUAGE" | cut -c1-2 | tr 'A-Z' 'a-z')" in ""|ru) L=ru ;; *) L=en ;; esac
    fi ;;
esac
export FLINT_LANG="$L"
T() { if [ "$L" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
  echo "Content-Type: text/plain; charset=utf-8"
  echo "Content-Disposition: attachment; filename=flint-settings-$(date +%Y%m%d-%H%M).txt"
  echo ""
  flint-settings export
  return 0
case "$tab" in status|servers|own|subs|routing|adblock|dns|telegram|settings) ;; *) tab=status ;; esac
# Ready-made lists from AdGuard's registry of DNS blocklists: id:name.
PRESET_URL=https://adguardteam.github.io/HostlistsRegistry/assets/filter_
PRESETS="1:AdGuard DNS filter
59:AdGuard DNS Popup Hosts filter
48:HaGeZi's Pro Blocklist
5:OISD Blocklist Small
33:Steven Black's List
18:Phishing Army
11:Malicious URL Blocklist (URLHaus)"
TITLE="$(echo "${UI_TITLE:-Flint VPN}" | esc)"
TAGLINE="$(echo "${UI_TAGLINE-Sail the internet}" | esc)"
FOOTER='<footer><span>YOUR NETWORK. <b>YOUR RULES.</b></span></footer>'
VER="$(cat /usr/share/flint/version 2>/dev/null | esc)"
[ -n "$VER" ] && VER="<div class=ver>Flint VPN v$VER</div>"
logo() {
  last="${TITLE##* }"; first="${TITLE% *}"
  [ "$first" = "$TITLE" ] && last=""
  [ -n "$last" ] && last=" <b>$last</b>"
  tag=""; [ -n "$TAGLINE" ] && tag="<div class=tag>$TAGLINE</div>"
  echo "<div class=\"logo $1\"><img src=/logo.svg alt=\"\"><div><div class=word>$first$last</div>$tag</div></div>"
}
# Language switch; $1 is the link prefix ending in "?" or "&amp;".
langs() {
  if [ "$L" = en ]; then echo "<div class=lang><a href='${1}lang=ru'>RU</a><b>EN</b></div>"
  else echo "<div class=lang><b>RU</b><a href='${1}lang=en'>EN</a></div>"; fi
}
# Top bar: $1 = left side (logo or empty), $2 = right side (language switch, sign out).
top() { echo "<header class=top>$1<div class=tools>$2</div></header>"; }
cat <<HTML
<!DOCTYPE html><html lang=$L><head>
<meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>$TITLE</title>
<link rel=icon type=image/svg+xml href=/icon.svg>
<link rel=stylesheet href=/panel.css>
</head><body>
HTML
if [ -z "$UI_PIN" ] || [ "$pass" != "$UI_PIN" ]; then
  err=""; [ -n "$pass" ] && err="<p class='err login-err'>$(T "Неверный PIN, попробуйте ещё раз" "Wrong PIN, please try again")</p>"
  cat <<HTML
$(top "" "$(langs "?")")<main>$(logo big)<div class="card login"><div class=lock>🔒</div>
<p class=login-hint>$(T "Введите PIN, чтобы управлять VPN" "Enter the PIN to manage the VPN")</p>$err
<form method=get><input type=password name=pass placeholder=PIN autocomplete=current-password autofocus required>
<button class=on>$(T "Войти" "Sign in")</button></form></div></main>$FOOTER$VER</body></html>
HTML
  return 0
fi
CUR="$(flint-node current)"
MODE="$(flint-node routing)"
VPN="$(flint-node vpn)"
hidden() { echo "<input type=hidden name=pass value='$pass'><input type=hidden name=tab value='$tab'>"; }
# btn <action> <value> <button attrs> <label>: a form that sends <action>=<value>.
btn() { echo "<form method=get class=act>$(hidden)<input type=hidden name=$1 value='$2'><button$3>$4</button></form>"; }
field() { echo "<label>$1<input type=text name=$2 value='$(printf '%s' "$3" | esc)'$4></label>"; }
SUBLIST="$(flint-sub-update list | esc)"
NAMES="$(flint-node names | esc)"
CUR_NAME="$(echo "$NAMES" | awk -F "$TAB" -v c="$CUR" '$1 == c {print $2}')"
SITES="$(flint-node site list)"
ON="<b class=ok>$(T "включено" "on")</b>"; OFF="<b class=err>$(T "выключено" "off")</b>"
NEVER="$(T "ещё не было" "never")"
ADD_SERVERS="<div class=cta><a class='btn on' href='?pass=$pass&amp;tab=subs'>🔗 $(T "Добавить подписку" "Add a subscription")</a><a class=btn href='?pass=$pass&amp;tab=own'>⭐ $(T "Добавить свой сервер" "Add an own server")</a></div>"
