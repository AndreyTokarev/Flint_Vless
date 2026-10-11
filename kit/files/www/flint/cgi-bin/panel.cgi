#!/bin/sh
# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The Flint VPN panel: one CGI page per tab, Russian or English, rendered on the router.
# Shared markup is in /usr/share/flint/panel/ui.sh, each tab in its own file next to it.

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
  exit 0
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
pass="$(get pass)"; tab="$(get tab)"

# The HTTP headers come before anything is printed, and before ui.sh is sourced: ui.sh answers with the
# login page or with the panel, so its output starts the body. A CGI response whose first line is not a
# header is rejected by the server (that is a 502 from uhttpd), which is what happened when the headers
# were sent after ui.sh.
#
# The settings export is the one response with different headers (text/plain and a download name), so it is
# recognised here first. That needs UI_PIN, which comes from flint.env — the same file ui.sh reads later;
# sourcing it twice is harmless, the values are assignments.
. /etc/xray/flint.env
if [ -z "$UI_PIN" ] || [ "$pass" != "$UI_PIN" ] || [ -z "$(get export)" ]; then
  echo "Content-Type: text/html; charset=utf-8"
  [ "$lang" = "$L" ] && echo "Set-Cookie: lang=$L; Path=/; Max-Age=31536000; SameSite=Lax"
  echo ""
fi

# Shared markup, the language switch, the login gate, the settings export and the tab data. The export
# block itself lives in ui.sh, right after it has read flint.env: it prints its own headers and ends the
# request, so everything below belongs to a normal page.
# Shared markup, the language switch, the login gate, the settings export, the page header and the data
# the tabs read: all of it is in ui.sh. This file must not repeat any of it — a second copy of the page
# header and the login form was left here once and the panel rendered the whole page twice, one form after
# another.
. /usr/share/flint/panel/ui.sh
# ui.sh answers with the login page and returns when the PIN is wrong or missing — but "return" ends only
# that sourced file, so the request has to be ended here too. Without this the panel went on to render the
# status page after the login form, and the browser showed a form and a full page one after another.
if [ -z "$UI_PIN" ] || [ "$pass" != "$UI_PIN" ]; then
  exit 0
fi
case "$tab" in status|servers|own|subs|routing|adblock|dns|telegram|settings) ;; *) tab=status ;; esac
# The action is the first non-empty parameter from this list; every form sends exactly one of them.
ACTIONS=" node routing vpn sub subint subadd subsave subdel subedit wd adblock abpreset ablist abldel abrule abrdel aballow abint abref abxadd abxdel add del link ndel save edit copy newnode import pin dns dnsmode dnsurl dnscrypt dnsstamp dnsudp dnsip hostadd hostdel directadd directdel tg tgroute tgcf tgremote tgaddr tgmask tgport tgsecret tgsecretset tgcheck tgdc tgcfd tgworker tgcftls tgpool tglog tgupdate probemode fingerprint mux "
a="$(echo "$qs" | tr '&' '\n' | awk -F = -v l="$ACTIONS" '$2 != "" && index(l, " " $1 " ") { print $1; exit }')"
msg=""; form=""; subedit=""; subsave=""
case "$a" in
  node) msg="$(flint-node "$(get node)" 2>&1)" ;;
  routing) msg="$(flint-node routing "$(get routing)" 2>&1)" ;;
  vpn) msg="$(flint-node vpn "$(get vpn)" 2>&1)" ;;
  sub) msg="$(flint-sub-update 2>&1)" ;;
  subint) msg="$(flint-sub-update interval "$(get subint)" 2>&1)" ;;
  subadd) msg="$(flint-sub-update add "$(param subadd)" "$(param subname)" 2>&1)" ;;
  subsave)
    subsave="$(get subsave)"
    msg="$(flint-sub-update set "$subsave" "$(param subu)" "$(param subn)" 2>&1)" || subedit="$subsave" ;;
  subdel) msg="$(flint-sub-update del "$(get subdel)" 2>&1)" ;;
  subedit) subedit="$(get subedit)" ;;
  wd) msg="$(flint-watchdog "$(get wd)" 2>&1)" ;;
  probemode) case "$(get probemode)" in fastest|first) msg="$(flint-node probe-mode "$(get probemode)" 2>/dev/null || true)" ;; esac ;;
  adblock) msg="$(flint-adblock "$(get adblock)" 2>&1)" ;;
  abpreset)
    abpreset="$(get abpreset)"
    pname="$(echo "$PRESETS" | awk -F : -v i="$abpreset" '$1 == i { print $2 }')"
    [ -n "$pname" ] && msg="$(flint-adblock list add "$PRESET_URL$abpreset.txt" "$pname" 2>&1)" ;;
  ablist) msg="$(flint-adblock list add "$(param ablist)" "$(param abname)" 2>&1)" ;;
  abldel) msg="$(flint-adblock list del "$(param abldel)" 2>&1)" ;;
  abrule)
    abto="$(get abto)"
    case "$abto" in block|allow) msg="$(flint-adblock rule add "$abto" "$(param abrule)" 2>&1)" ;; esac ;;
  abrdel) msg="$(flint-adblock rule del "$(param abrdel)" 2>&1)" ;;
  aballow) msg="$(flint-adblock rule add allow "$(param aballow)" 2>&1)" ;;
  abint) msg="$(flint-adblock interval "$(get abint)" 2>&1)" ;;
  abref) msg="$(flint-adblock refresh 2>&1)" ;;
  abxadd) msg="$(flint-adblock exclude add "$(param abxadd)" "$(param abxname)" 2>&1)" ;;
  abxdel) msg="$(flint-adblock exclude del "$(param abxdel)" 2>&1)" ;;
  add)
    to="$(get to)"
    case "$to" in direct|proxy) msg="$(flint-node site add "$to" "$(param add)" 2>&1)" ;; esac ;;
  del) msg="$(flint-node site del "$(param del)" 2>&1)" ;;
  link) msg="$(flint-custom link "$(param link)" 2>&1)" ;;
  ndel) msg="$(flint-custom del "$(get ndel)" 2>&1)" ;;
  save)
    save="$(get save)"
    f_name="$(param n)"; f_addr="$(param h)"; f_port="$(param p)"; f_uuid="$(param u)"
    f_sni="$(param s)"; f_pbk="$(param k)"; f_sid="$(param i)"; f_net="$(get t)"; f_svc="$(param g)"
    # On a validation error keep the form open with what was typed.
    msg="$(flint-custom set "$save" "$f_name" "$f_addr" "$f_port" "$f_uuid" "$f_sni" "$f_pbk" "$f_sid" "$f_net" "$f_svc" 2>&1)" || form="$save" ;;
  edit|copy)
    code="$(get "$a")"
    IFS="$TAB" read -r f_code f_name f_addr f_port f_uuid f_sni f_pbk f_sid f_net f_svc <<EOF
$(flint-custom show "$code")
EOF
    [ "$f_sid" = - ] && f_sid=""
    [ "$f_svc" = - ] && f_svc=""
    if [ "$a" = edit ]; then form="$code"; else form=new; f_name="$f_name ($(T "копия" "copy"))"; fi ;;
  newnode) form=new; f_port=443 ;;
  import)
    # The settings file comes as the "file" part of a multipart POST (the form keeps pass/tab in the URL).
    # The import runs in the background on purpose: it ends with flint-node apply, which restarts Xray, and
    # that restart waits for the transparent port to be free of TIME_WAIT sockets (up to 90 s). uhttpd does
    # not wait that long for a CGI request — it drops the connection and the browser shows a broken page
    # with no message, although the import itself had worked. So the uploaded file is stored here, the
    # answer is sent at once, and the import runs on its own.
    rm -f /tmp/flint-import.txt /tmp/flint-import.status
    if [ "$REQUEST_METHOD" = POST ] && [ "${CONTENT_LENGTH:-0}" -gt 0 ] && [ "${CONTENT_LENGTH:-0}" -le 1048576 ]; then
      b="--$(printf '%s' "$CONTENT_TYPE" | sed -n 's/.*boundary=//p' | tr -d '"')"
      head -c "$CONTENT_LENGTH" | awk -v b="$b" '
        { sub(/\r$/, "") }
        index($0, b) == 1 { if (body) exit; hdr = 0; next }
        body { print; next }
        hdr && $0 == "" { body = 1; next }
        /^Content-Disposition:/ && /name="file"/ { hdr = 1 }' > /tmp/flint-import.txt
      if [ -s /tmp/flint-import.txt ]; then
        # The import has to survive this CGI: it ends with flint-node apply, which restarts Xray, and that
        # restart waits for the transparent port to be free of TIME_WAIT sockets. This firmware has no
        # setsid and no nohup, and a plain "( ... ) &" is killed together with the CGI, which left the status
        # file empty; start-stop-daemon detaches it properly. It must NOT be given -b: that option closes the
        # output of the process, and the status file the panel reads stayed empty with it.
        start-stop-daemon -S -x /usr/bin/flint-settings -- import /tmp/flint-import.txt \
          > /tmp/flint-import.status 2>&1
        msg="$(T "Файл принят: настройки загружаются в фоне, панель обновится через минуту" \
          "The file was taken: the settings load in the background, the panel updates in a minute")"
      else
        msg="$(T "Файл не принят: в нём нет настроек" "The file was not taken: there are no settings in it")"
      fi
    else
      msg="$(T "Выберите файл настроек (не больше 1 МБ)" "Choose a settings file (up to 1 MB)")"
    fi ;;
  pin)
    pinnew="$(param pinnew)"
    if [ "$(get pinold)" != "$UI_PIN" ]; then
      msg="$(T "Неверный текущий PIN" "Wrong current PIN")"
    elif ! echo "$pinnew" | grep -qxE '[A-Za-z0-9]+'; then
      msg="$(T "Новый PIN: только буквы и цифры" "New PIN: letters and digits only")"
    elif [ "$pinnew" != "$(param pinok)" ]; then
      msg="$(T "Новый PIN и подтверждение не совпадают" "New PIN and confirmation do not match")"
    elif sed -i "s/^UI_PIN=.*/UI_PIN=$pinnew/" /etc/xray/flint.env; then
      UI_PIN="$pinnew"; pass="$pinnew"
      msg="$(T "PIN изменён" "PIN changed")"
    else
      msg="$(T "Не удалось записать PIN в flint.env" "Could not write the PIN to flint.env")"
    fi ;;
  dns) msg="$(flint-dns doh "$(get dns)" 2>&1)" ;;
  dnsmode) case "$(get dnsmode)" in doh|dnscrypt|udp|tunnel) msg="$(flint-dns mode "$(get dnsmode)" 2>&1)" ;; esac ;;
  dnsurl) msg="$(flint-dns doh "$(param dnsurl)" 2>&1)" ;;
  dnscrypt) msg="$(flint-dns dnscrypt "$(get dnscrypt)" 2>&1)" ;;
  dnsstamp) msg="$(flint-dns dnscrypt "$(param dnsstamp)" 2>&1)" ;;
  dnsudp) msg="$(flint-dns udp "$(get dnsudp)" 2>&1)" ;;
  dnsip) msg="$(flint-dns udp "$(param dnsip)" 2>&1)" ;;
  hostadd) msg="$(flint-dns hosts add "$(param hostadd)" "$(param hostip)" 2>&1)" ;;
  hostdel) msg="$(flint-dns hosts del "$(param hostdel)" 2>&1)" ;;
  directadd) msg="$(flint-node direct add "$(param directadd)" "$(param directname)" 2>&1)" ;;
  directdel) msg="$(flint-node direct del "$(param directdel)" 2>&1)" ;;
  tg) case "$(get tg)" in on|off) msg="$(flint-tg "$(get tg)" 2>&1)" ;; esac ;;
  tgroute) msg="$(flint-tg route "$(get tgroute)" 2>&1)" ;;
  tgcf) msg="$(flint-tg cf "$(get tgcf)" 2>&1)" ;;
  tgremote) msg="$(flint-tg remote "$(get tgremote)" 2>&1)" ;;
  tgaddr) msg="$(flint-tg addr "$(param tgaddr)" 2>&1)" ;;
  tgmask) msg="$(flint-tg mask "$(param tgmask)" 2>&1)" ;;
  tgport) msg="$(flint-tg port "$(get tgport)" 2>&1)" ;;
  tgsecret) msg="$(flint-tg secret new 2>&1)" ;;
  tgsecretset) msg="$(flint-tg secret "$(get tgsecretset)" 2>&1)" ;;
  tgcheck) msg="$(flint-tg check 2>&1)" ;;
  tgdc) msg="$(flint-tg dc "$(param tgdc)" 2>&1)" ;;
  tgcfd) msg="$(flint-tg cfdomain "$(param tgcfd)" 2>&1)" ;;
  tgworker) msg="$(flint-tg worker "$(param tgworker)" 2>&1)" ;;
  tgcftls) msg="$(flint-tg cftls "$(get tgcftls)" 2>&1)" ;;
  tgpool) msg="$(flint-tg pool "$(get tgpool)" 2>&1)" ;;
  tglog) msg="$(flint-tg log "$(get tglog)" 2>&1)" ;;
  tgupdate) msg="$(flint-tg latest 2>&1)" ;;
  # Xray options: the fingerprint REALITY shows, and multiplexing (off by default, it slows video down and
  # with some servers stops the tunnel; flint-node turns it back off by itself when that happens).
  fingerprint) case "$(get fingerprint)" in chrome|firefox|safari|edge|random) msg="$(flint-node fingerprint "$(get fingerprint)" 2>&1)" ;; esac ;;
  mux) case "$(get mux)" in on|off) msg="$(flint-node mux "$(get mux)" 2>&1)" ;; esac ;;
esac
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

top "$(logo)" "$(langs "?pass=$pass&amp;tab=$tab&amp;")<a href='?' class=logout>$(T "Выйти" "Sign out")</a>"

echo "<div class=layout><nav>"
for t in "status:🏠 $(T "Статус" "Status")" "subs:🔗 $(T "Подписки" "Subscriptions")" "servers:🌍 $(T "Серверы" "Servers")" \
  "own:⭐ $(T "Свои серверы" "Own servers")" "dns:📡 DNS" "routing:🔀 $(T "Маршрутизация" "Routing")" \
  "adblock:🛡️ $(T "Реклама" "Ad blocking")" "telegram:✈️ Telegram" "settings:⚙️ $(T "Настройки" "Settings")"; do
  cur=""; [ "${t%%:*}" = "$tab" ] && cur=" class=cur"
  echo "<a href='?pass=$pass&amp;tab=${t%%:*}'$cur>${t#*:}</a>"
done
echo "</nav><div class=content>"
[ -n "$msg" ] && echo "<div class=card><pre class=ok>$(echo "$msg" | esc)</pre></div>"

case "$tab" in
  status) . /usr/share/flint/panel/status.sh ;;
  servers) . /usr/share/flint/panel/servers.sh ;;
  own) . /usr/share/flint/panel/own.sh ;;
  subs) . /usr/share/flint/panel/subs.sh ;;
  routing) . /usr/share/flint/panel/routing.sh ;;
  adblock) . /usr/share/flint/panel/adblock.sh ;;
  dns) . /usr/share/flint/panel/dns.sh ;;
  telegram) . /usr/share/flint/panel/telegram.sh ;;
  settings) . /usr/share/flint/panel/settings.sh ;;
esac
echo "</div></div>$FOOTER$VER</body></html>"
