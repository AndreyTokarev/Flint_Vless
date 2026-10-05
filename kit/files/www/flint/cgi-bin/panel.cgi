#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
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
if [ -n "$UI_PIN" ] && [ "$pass" = "$UI_PIN" ] && [ -n "$(get export)" ]; then
  echo "Content-Type: text/plain; charset=utf-8"
  echo "Content-Disposition: attachment; filename=flint-settings-$(date +%Y%m%d-%H%M).txt"
  echo ""
  flint-settings export
  exit 0
fi

echo "Content-Type: text/html; charset=utf-8"
[ "$lang" = "$L" ] && echo "Set-Cookie: lang=$L; Path=/; Max-Age=31536000; SameSite=Lax"
echo ""

case "$tab" in status|servers|own|subs|routing|adblock|dns|settings) ;; *) tab=status ;; esac
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
  exit 0
fi

# The action is the first non-empty parameter from this list; every form sends exactly one of them.
ACTIONS=" node routing vpn sub subint subadd subsave subdel subedit wd adblock abpreset ablist abldel abrule abrdel aballow abint abref abxadd abxdel add del link ndel save edit copy newnode import pin dns dnsurl dnscrypt dnsstamp dnsudp dnsip hostadd hostdel directadd directdel "
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
    if [ "$REQUEST_METHOD" = POST ] && [ "${CONTENT_LENGTH:-0}" -gt 0 ] && [ "${CONTENT_LENGTH:-0}" -le 1048576 ]; then
      b="--$(echo "$CONTENT_TYPE" | sed -n 's/.*boundary=//p' | tr -d '"')"
      msg="$(head -c "$CONTENT_LENGTH" | awk -v b="$b" '
        { sub(/\r$/, "") }
        index($0, b) == 1 { if (body) exit; hdr = 0; next }
        body { print; next }
        hdr && $0 == "" { body = 1; next }
        /^Content-Disposition:/ && /name="file"/ { hdr = 1 }' | flint-settings import 2>&1)"
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
  dnsurl) msg="$(flint-dns doh "$(param dnsurl)" 2>&1)" ;;
  dnscrypt) msg="$(flint-dns dnscrypt "$(get dnscrypt)" 2>&1)" ;;
  dnsstamp) msg="$(flint-dns dnscrypt "$(param dnsstamp)" 2>&1)" ;;
  dnsudp) msg="$(flint-dns udp "$(get dnsudp)" 2>&1)" ;;
  dnsip) msg="$(flint-dns udp "$(param dnsip)" 2>&1)" ;;
  hostadd) msg="$(flint-dns hosts add "$(param hostadd)" "$(param hostip)" 2>&1)" ;;
  hostdel) msg="$(flint-dns hosts del "$(param hostdel)" 2>&1)" ;;
  directadd) msg="$(flint-node direct add "$(param directadd)" "$(param directname)" 2>&1)" ;;
  directdel) msg="$(flint-node direct del "$(param directdel)" 2>&1)" ;;
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
  "adblock:🛡️ $(T "Реклама" "Ad blocking")" "settings:⚙️ $(T "Настройки" "Settings")"; do
  cur=""; [ "${t%%:*}" = "$tab" ] && cur=" class=cur"
  echo "<a href='?pass=$pass&amp;tab=${t%%:*}'$cur>${t#*:}</a>"
done
echo "</nav><div class=content>"
[ -n "$msg" ] && echo "<div class=card><pre class=ok>$(echo "$msg" | esc)</pre></div>"

case "$tab" in
status)
  echo "<div class=card>"
  if [ -z "$NAMES" ]; then
    IP="$(curl -s -m 8 https://ifconfig.me 2>/dev/null || echo n/a)"
    echo "<b class=err>$(T "Серверов пока нет" "No servers yet")</b> — $(T "устройства ходят в интернет напрямую" "devices go online directly")<br>$(T "IP провайдера" "Provider IP"): <b>$IP</b>$ADD_SERVERS"
  elif [ "$VPN" = off ]; then
    IP="$(curl -s -m 8 https://ifconfig.me 2>/dev/null || echo n/a)"
    echo "<b class=err>$(T "VPN выключен" "VPN is off")</b> — $(T "устройства ходят в интернет напрямую" "devices go online directly")<br>$(T "IP провайдера" "Provider IP"): <b>$IP</b>"
    btn vpn on " class=on" "$(T "Включить VPN" "Turn VPN on")"
  else
    # The router's own traffic bypasses Xray, so a plain request shows the provider's IP; both run at once.
    curl -s -m 8 https://ifconfig.me > /tmp/flint-ip.$$ 2>/dev/null &
    IP="$(curl -s -m 8 -x http://127.0.0.1:1087 https://ifconfig.me 2>/dev/null || echo n/a)"
    wait
    DIRECT_IP="$(head -c 64 /tmp/flint-ip.$$ | esc)"; rm -f /tmp/flint-ip.$$
    echo "VPN: <b class=ok>$(T "включён" "on")</b><br>$(T "Сервер" "Server"): <b class=ok>${CUR_NAME:-$CUR}</b>"
    echo "<br>$(T "IP через VPN" "IP via VPN"): <b>$IP</b><br>$(T "IP провайдера (до VPN)" "Provider IP (before VPN)"): <b>${DIRECT_IP:-n/a}</b>"
    btn vpn off " class=off" "$(T "Выключить VPN" "Turn VPN off")"
  fi
  echo "</div>"
  [ "$MODE" = ru ] && geo="<b class=ok>$(T "включён" "on")</b>" || geo="<b class=err>$(T "выключен" "off")</b>"
  total="$(echo "$NAMES" | grep -c .)"; own="$(flint-custom list | grep -c .)"
  ndirect="$(echo "$SITES" | grep -c '^direct')"; nproxy="$(echo "$SITES" | grep -c '^proxy')"
  CHECKED="$(flint-sub-update status | esc)"
  WLAST="$(flint-watchdog last | esc)"
  [ "$(flint-watchdog state)" = on ] && wds="$ON" || wds="$OFF"
  echo "<div class=card>"
  echo "<div class=stat><span>$(T "Гео-фильтр РФ" "Russia geo filter")</span><span>$geo</span></div>"
  echo "<div class=stat><span>$(T "Свои сайты" "Own sites")</span><a href='?pass=$pass&amp;tab=routing'>$(T "$ndirect напрямую, $nproxy через VPN" "$ndirect direct, $nproxy via VPN")</a></div>"
  echo "<div class=stat><span>$(T "Серверов" "Servers")</span><a href='?pass=$pass&amp;tab=servers'>$(T "$total, из них своих $own" "$total, $own of them own")</a></div>"
  echo "<div class=stat><span>$(T "Проверка подписок" "Subscription check")</span><a href='?pass=$pass&amp;tab=subs'>${CHECKED:-$NEVER}</a></div>"
  echo "<div class=stat><span>$(T "Автопереключение при сбое" "Failover")</span><a href='?pass=$pass&amp;tab=servers'>$wds</a></div>"
  [ "$(flint-adblock state)" = on ] && abs="$ON" || abs="$OFF"
  echo "<div class=stat><span>$(T "Блокировка рекламы" "Ad blocking")</span><a href='?pass=$pass&amp;tab=adblock'>$abs</a></div>"
  echo "<div class=stat><span>DNS</span><a href='?pass=$pass&amp;tab=dns'>$(flint-dns title | esc)</a></div>"
  [ -n "$WLAST" ] && echo "<div class=stat><span>$(T "Последний сбой" "Last failure")</span><span>$WLAST</span></div>"
  echo "</div>"
  ;;
servers)
  # grid <ip|domain> [group]: server buttons; group "-" = manual servers in nodes.conf.
  grid() {
    echo "$NAMES" | awk -F "$TAB" -v k="$1" -v g="$2" \
      '$3 == k && (g == "" || $4 == g) { print $1 "\t" $2 }' |
    while IFS="$TAB" read -r code name; do
      on=""; [ "$code" = "$CUR" ] && on=" on"
      echo "<form method=get>$(hidden)<input type=hidden name=node value='$code'><button class='$on'>$name</button></form>"
    done
  }
  card() { [ -n "$2" ] && echo "<div class=card><h2>$1</h2><div class=grid>$2</div></div>"; }
  SERVERS="$(T "Серверы" "Servers")"
  [ -n "$NAMES" ] || echo "<div class=card><h2>$SERVERS</h2>$(T "Серверов пока нет: устройства ходят в интернет напрямую." "No servers yet: devices go online directly.")$ADD_SERVERS</div>"
  if [ "$(echo "$SUBLIST" | grep -c .)" -gt 1 ]; then
    echo "$SUBLIST" | while IFS="$TAB" read -r id sname host st info; do card "$sname" "$(grid domain "$id")"; done
  elif [ -n "$SUBLIST" ]; then
    card "$SERVERS" "$(grid domain "$(echo "$SUBLIST" | cut -f1)")"
  fi
  [ -n "$SUBLIST" ] && manual="$(T "Заданные вручную" "Manual")" || manual="$SERVERS"
  card "$manual" "$(grid domain "-")"
  card "$(T "Свои серверы" "Own servers")" "$(grid domain own)"
  WL="$(grid ip)"
  if [ -n "$WL" ]; then
    open=""; echo "$NAMES" | awk -F "$TAB" -v c="$CUR" '$1 == c && $3 == "ip" { f = 1 } END { exit !f }' && open=" open"
    echo "<details class=card$open><summary><b>$(T "Белые списки" "White lists")</b> <small>— $(T "серверы по IP-адресу, для сетей, где открыт только белый список" "servers by IP address, for networks where only a white list is open")</small></summary>"
    echo "<div class=grid style='margin-top:10px'>$WL</div></details>"
  fi
  echo "<div class=card><h2>$(T "Автопереключение при сбое" "Failover")</h2>"
  if [ "$(flint-watchdog state)" = on ]; then
    echo "$ON — $(T "каждые 2 минуты роутер проверяет VPN. Если сервер не отвечает, а интернет есть, он обновляет подписку и при необходимости переходит на первый рабочий сервер." \
      "every 2 minutes the router checks the VPN. If the server does not respond while the internet works, it refreshes the subscription and, if needed, switches to the first working server.")"
    btn wd off "" "$(T "Выключить автопереключение" "Turn failover off")"
  else
    echo "$OFF — $(T "при сбое сервера интернет пропадёт, пока не выберете другой сервер вручную." "if the server fails, the internet stays down until you pick another server manually.")"
    btn wd on " class=on" "$(T "Включить автопереключение" "Turn failover on")"
  fi
  WLAST="$(flint-watchdog last | esc)"
  echo "<small>$(T "Последнее срабатывание" "Last triggered"): ${WLAST:-$NEVER}</small></div>"
  ;;
own)
  if [ -n "$form" ]; then
    [ "$form" = new ] && title="$(T "Новый сервер" "New server")" || title="$(T "Изменить сервер" "Edit server")"
    echo "<div class=card><h2>$title</h2><small>$(T "Поддерживаются VLESS + REALITY поверх TCP (xtls-rprx-vision) или gRPC." "Supported: VLESS + REALITY over TCP (xtls-rprx-vision) or gRPC.")</small>"
    echo "<form method=get>$(hidden)<input type=hidden name=save value='$form'>"
    field "$(T "Название" "Name")" n "$f_name" " maxlength=60"
    field "$(T "Адрес сервера" "Server address")" h "$f_addr" " required"
    field "$(T "Порт" "Port")" p "$f_port" " required inputmode=numeric"
    field "UUID" u "$f_uuid" " required"
    field "SNI (serverName)" s "$f_sni" " required"
    field "Public key (pbk)" k "$f_pbk" " required"
    field "Short ID (sid)" i "$f_sid" ""
    [ "$f_net" = grpc ] && g_sel=" selected" || g_sel=""
    echo "<label>$(T "Транспорт" "Transport")<select name=t style='width:100%;margin-top:4px'><option value=tcp>TCP (xtls-rprx-vision)</option><option value=grpc$g_sel>gRPC</option></select></label>"
    field "gRPC serviceName ($(T "только для gRPC" "gRPC only"))" g "$f_svc" ""
    echo "<button class=on style='margin-top:12px'>$(T "Сохранить" "Save")</button></form>"
    echo "<form method=get class=act>$(hidden)<button>$(T "Отмена" "Cancel")</button></form></div>"
  fi
  echo "<div class=card><h2>$(T "Свои серверы" "Own servers")</h2><small>$(T "Не из подписки: автообновление их не трогает. Выбираются на вкладке «Серверы»." "Not from the subscription: auto-update leaves them alone. Pick them on the Servers tab.")</small>"
  OWN="$(flint-custom list | esc)"
  [ -n "$OWN" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  DEL="$(T "Удалить" "Delete")"; EDIT="$(T "Изменить" "Edit")"
  echo "$OWN" | while IFS="$TAB" read -r code name; do
    [ -n "$code" ] || continue
    echo "<div class=item><span>$name</span>"
    echo "<form method=get>$(hidden)<input type=hidden name=edit value='$code'><button>$EDIT</button></form>"
    echo "<form method=get>$(hidden)<input type=hidden name=ndel value='$code'><button title='$DEL'>✕</button></form></div>"
  done
  echo "</div><div class=card><h2>$(T "Добавить" "Add")</h2>"
  echo "<form method=get class=row>$(hidden)<input type=text name=link placeholder='vless://...' required><button>$(T "Добавить по ссылке" "Add by link")</button></form>"
  if [ -n "$NAMES" ]; then
    echo "<form method=get class=row>$(hidden)<select name=copy>"
    echo "$NAMES" | while IFS="$TAB" read -r code name kind group; do [ -n "$code" ] && echo "<option value='$code'>$name</option>"; done
    echo "</select><button>$(T "Скопировать и изменить" "Copy and edit")</button></form>"
  fi
  btn newnode 1 "" "$(T "Ввести вручную" "Enter manually")"
  echo "</div>"
  ;;
subs)
  if [ -n "$subedit" ]; then
    IFS="$TAB" read -r s_id s_name s_host s_st s_info <<EOF
$(flint-sub-update list | awk -F "$TAB" -v i="$subedit" '$1 == i')
EOF
    if [ -n "$s_id" ]; then
      s_url="$(flint-sub-update url "$s_id")"
      # After a failed save keep what was typed.
      [ -n "$subsave" ] && { s_url="$(param subu)"; s_name="$(param subn)"; }
      echo "<div class=card><h2>$(T "Изменить подписку" "Edit subscription")</h2>"
      echo "<form method=get>$(hidden)<input type=hidden name=subsave value='$s_id'>"
      field "$(T "Ссылка" "Link")" subu "$s_url" " required"
      field "$(T "Название" "Name")" subn "$s_name" " maxlength=60"
      echo "<button class=on style='margin-top:12px'>$(T "Сохранить" "Save")</button></form>"
      echo "<form method=get class=act>$(hidden)<button>$(T "Отмена" "Cancel")</button></form></div>"
    fi
  fi
  DEL="$(T "Удалить" "Delete")"; EDIT="$(T "Изменить" "Edit")"
  ASK="$(T "Удалить подписку и её серверы?" "Delete the subscription and its servers?")"
  echo "<div class=card><h2>$(T "Подписки" "Subscriptions")</h2><small>$(T "Ссылки на подписки любых VPN-провайдеров в формате v2rayN / Happ / Hiddify: список vless://, обычный или в base64. Серверы всех подписок появятся на вкладке «Серверы»." \
    "Subscription links from any VPN providers in the v2rayN / Happ / Hiddify format: a list of vless:// links, plain or base64. Servers from all subscriptions appear on the Servers tab.")</small>"
  [ -n "$SUBLIST" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  echo "$SUBLIST" | while IFS="$TAB" read -r id sname host st info; do
    [ -n "$id" ] || continue
    [ "$st" = - ] && st="$(T "ещё не обновлялась" "not updated yet")"
    [ "$info" = - ] && info="" || info="<br><small>$info</small>"
    echo "<div class=item><span>$sname<br><small>$host · $st</small>$info</span>"
    echo "<form method=get>$(hidden)<input type=hidden name=subedit value='$id'><button>$EDIT</button></form>"
    echo "<form method=get onsubmit=\"return confirm('$ASK')\">$(hidden)<input type=hidden name=subdel value='$id'><button title='$DEL'>✕</button></form></div>"
  done
  echo "<form method=get class=row>$(hidden)<input type=text name=subadd placeholder='https://provider.example/sub/...' required>"
  echo "<input type=text name=subname placeholder='$(T "Название (необязательно)" "Name (optional)")'><button>$(T "Добавить подписку" "Add subscription")</button></form></div>"
  echo "<div class=card><h2>$(T "Обновление" "Updates")</h2>"
  btn sub 1 "" "$(T "Обновить все подписки сейчас" "Update all subscriptions now")"
  CHECKED="$(flint-sub-update status | esc)"
  echo "<small>$(T "Последняя проверка" "Last check"): ${CHECKED:-$NEVER}</small>"
  SI="$(flint-sub-update interval)"
  echo "<form method=get class=row>$(hidden)<select name=subint>"
  for v in "off:$(T "Автообновление выключено" "Auto-update off")" "30m:$(T "Обновлять каждые 30 минут" "Update every 30 minutes")" \
    "1h:$(T "Обновлять каждый час" "Update every hour")" "3h:$(T "Обновлять каждые 3 часа" "Update every 3 hours")" \
    "6h:$(T "Обновлять каждые 6 часов" "Update every 6 hours")" "12h:$(T "Обновлять каждые 12 часов" "Update every 12 hours")" \
    "24h:$(T "Обновлять раз в сутки" "Update once a day")"; do
    sel=""; [ "${v%%:*}" = "$SI" ] && sel=" selected"
    echo "<option value='${v%%:*}'$sel>${v#*:}</option>"
  done
  echo "</select><button>$(T "Сохранить" "Save")</button></form>"
  echo "<small>$(T "Если подписка не скачалась, её серверы остаются прежними." "If a subscription fails to download, its servers stay as they were.")</small></div>"
  ;;
routing)
  echo "<div class=card><h2>$(T "Гео-фильтр РФ" "Russia geo filter")</h2>"
  if [ "$MODE" = ru ]; then
    echo "<b class=ok>$(T "включён" "on")</b> — $(T "российские сайты и IP идут напрямую, остальное через VPN" "Russian sites and IPs go direct, everything else via VPN")"
    btn routing global "" "$(T "Выключить гео-фильтр (всё через VPN)" "Turn the geo filter off (everything via VPN)")"
  else
    echo "<b class=err>$(T "выключен" "off")</b> — $(T "весь трафик идёт через VPN" "all traffic goes via VPN")"
    btn routing ru " class=on" "$(T "Включить гео-фильтр" "Turn the geo filter on")"
  fi
  echo "</div>"
  DEL="$(T "Удалить" "Delete")"
  echo "<div class=card><h2>$(T "Устройства без VPN" "Devices without VPN")</h2><small>$(T "Эти устройства всегда ходят в интернет напрямую, мимо VPN, — например, телевизор или консоль. Устройство узнаётся по MAC-адресу. Уже открытые соединения доработают как были, новые пойдут напрямую." \
    "These devices always go online directly, bypassing the VPN — a TV or a game console, for example. A device is recognised by its MAC address. Open connections finish as they were; new ones go direct.")</small>"
  DIRECTS="$(flint-node direct | esc)"
  [ -n "$DIRECTS" ] || echo "<p><small>$(T "нет — все устройства через VPN" "none — every device goes via VPN")</small></p>"
  echo "$DIRECTS" | while IFS="$TAB" read -r m name; do
    [ -n "$m" ] || continue
    echo "<form method=get class=item>$(hidden)<input type=hidden name=directdel value='$m'><span>$name<br><small>$m</small></span><button title='$DEL'>✕</button></form>"
  done
  DEVS="$(flint-adblock devices | esc | awk -F '\t' -v ex="$(flint-node direct | cut -f1 | tr '\n' ' ')" 'index(" " ex, " " $1 " ") == 0')"
  if [ -n "$DEVS" ]; then
    echo "<form method=get class=row>$(hidden)<select name=directadd>"
    echo "$DEVS" | while IFS="$TAB" read -r m ip name; do echo "<option value='$m'>${name:-$m} — $ip</option>"; done
    echo "</select><button>$(T "Без VPN" "Without VPN")</button></form>"
  fi
  echo "<form method=get class=row>$(hidden)<input type=text name=directadd placeholder='aa:bb:cc:dd:ee:ff' required>"
  echo "<input type=text name=directname placeholder='$(T "Название (необязательно)" "Name (optional)")'><button>$(T "Добавить по MAC" "Add by MAC")</button></form></div>"
  echo "<div class=card><h2>$(T "Свои сайты" "Own sites")</h2><small>$(T "Важнее гео-фильтра. Домен действует вместе с поддоменами; можно вставить ссылку, IP или подсеть." "Override the geo filter. A domain covers its subdomains; you can paste a link, an IP or a subnet.")</small>"
  echo "<form method=get class=row>$(hidden)<input type=text name=add placeholder='example.com' required>"
  echo "<select name=to><option value=direct>$(T "Напрямую" "Direct")</option><option value=proxy>$(T "Через VPN" "Via VPN")</option></select><button>$(T "Добавить" "Add")</button></form>"
  for list in direct proxy; do
    [ "$list" = direct ] && title="$(T "Всегда напрямую (мимо VPN)" "Always direct (bypass VPN)")" || title="$(T "Всегда через VPN" "Always via VPN")"
    items="$(echo "$SITES" | awk -F "$TAB" -v l="$list" '$1 == l {print $2}')"
    echo "<p><b>$title</b></p>"
    [ -n "$items" ] || echo "<small>$(T "пусто" "empty")</small>"
    for s in $items; do
      echo "<form method=get class=item>$(hidden)<input type=hidden name=del value='$s'><span>$s</span><button title='$DEL'>✕</button></form>"
    done
  done
  echo "</div>"
  ;;
adblock)
  echo "<div class=card><h2>$(T "Блокировка рекламы" "Ad blocking")</h2>"
  if [ "$(flint-adblock state)" = on ]; then
    echo "$ON — $(T "реклама, трекеры и вредоносные сайты блокируются для всех устройств сети на уровне DNS." \
      "ads, trackers and malicious sites are blocked for every device on the network at the DNS level.")"
    set -- $(flint-adblock stats 2>/dev/null)
    if [ -n "$1" ]; then
      pct="$(awk -v q="$1" -v b="$2" 'BEGIN { printf "%.1f", q ? b * 100 / q : 0 }')"
      echo "<br><small>$(T "За сутки: запросов $1, заблокировано $2 ($pct%)" "Last 24 hours: $1 queries, $2 blocked ($pct%)")</small>"
    fi
    echo "<br><small>$(T "Реклама, которая идёт с того же сайта, что и контент (ВКонтакте, YouTube), останется — её убирает только блокировщик в браузере, например uBlock Origin. Устройства с «Частным DNS», DoH в браузере или VPN-клиентом (Happ и т. п.) обходят блокировку." \
      "Ads served from the same site as the content (VK, YouTube) stay — only a browser blocker such as uBlock Origin removes them. Devices with Private DNS, browser DoH or a VPN client (Happ, etc.) bypass the blocking.")</small>"
    btn adblock off "" "$(T "Выключить блокировку" "Turn ad blocking off")"
  else
    echo "$OFF — $(T "устройства видят рекламу как обычно." "devices see ads as usual.")"
    btn adblock on " class=on" "$(T "Включить блокировку" "Turn ad blocking on")"
  fi
  [ -x /usr/bin/AdGuardHome ] || echo "<p class=err>$(T "AdGuard Home не найден: нужна прошивка GL 4.x или пакет adguardhome." "AdGuard Home not found: needs GL firmware 4.x or the adguardhome package.")</p>"
  echo "</div>"
  DEL="$(T "Удалить" "Delete")"
  echo "<div class=card><h2>$(T "Устройства без блокировки" "Devices without blocking")</h2><small>$(T "Блокировка действует на все устройства сети, кроме этих. Устройство узнаётся по MAC-адресу." \
    "Blocking applies to every device on the network except these. A device is recognised by its MAC address.")</small>"
  EXCL="$(flint-adblock exclude | esc)"
  [ -n "$EXCL" ] || echo "<p><small>$(T "нет — блокировка для всех" "none — blocking for everyone")</small></p>"
  echo "$EXCL" | while IFS="$TAB" read -r m name; do
    [ -n "$m" ] || continue
    echo "<div class=item><span>$name<br><small>$m</small></span>"
    echo "<form method=get>$(hidden)<input type=hidden name=abxdel value='$m'><button title='$DEL'>✕</button></form></div>"
  done
  DEVS="$(flint-adblock devices | esc | awk -F '\t' -v ex="$(flint-adblock exclude | cut -f1 | tr '\n' ' ')" 'index(" " ex, " " $1 " ") == 0')"
  if [ -n "$DEVS" ]; then
    echo "<form method=get class=row>$(hidden)<select name=abxadd>"
    echo "$DEVS" | while IFS="$TAB" read -r m ip name; do echo "<option value='$m'>${name:-$m} — $ip</option>"; done
    echo "</select><button>$(T "Не блокировать" "Don't block")</button></form>"
  fi
  echo "<form method=get class=row>$(hidden)<input type=text name=abxadd placeholder='aa:bb:cc:dd:ee:ff' required>"
  echo "<input type=text name=abxname placeholder='$(T "Название (необязательно)" "Name (optional)")'><button>$(T "Добавить по MAC" "Add by MAC")</button></form></div>"
  # Allow rules for a plain domain (@@||domain^) are shown here; every other rule under "Own rules".
  RULES="$(flint-adblock rule | esc)"
  ALLOWED="$(echo "$RULES" | grep -E '^@@\|\|[a-z0-9.-]+\^$')"
  echo "<div class=card><h2>$(T "Сайты без блокировки" "Sites without blocking")</h2><small>$(T "Сайт и его поддомены не блокируются — если блокировка сломала нужный сайт. Рекламу с чужих доменов на этом сайте блокировка всё равно убирает: по DNS-запросу не видно, с какой страницы он пришёл." \
    "The site and its subdomains are not blocked — for when blocking breaks a site you need. Ads from other domains on that site are still blocked: a DNS query does not tell which page it came from.")</small>"
  [ -n "$ALLOWED" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  echo "$ALLOWED" | while IFS= read -r r; do
    [ -n "$r" ] || continue
    d="${r#@@||}"
    echo "<form method=get class=item>$(hidden)<input type=hidden name=abrdel value='$r'><span>${d%^}</span><button title='$DEL'>✕</button></form>"
  done
  echo "<form method=get class=row>$(hidden)<input type=text name=aballow placeholder='example.com' required><button>$(T "Не блокировать" "Don't block")</button></form>"
  BLOCKED="$(flint-adblock blocked 2>/dev/null | esc)"
  if [ -n "$BLOCKED" ]; then
    echo "<details style='margin-top:10px'><summary><b>$(T "Недавно заблокировано" "Recently blocked")</b> <small>— $(T "если сайт перестал работать, разрешите домен, который ему нужен" "if a site stopped working, allow the domain it needs")</small></summary>"
    echo "$BLOCKED" | while IFS="$TAB" read -r d dev; do
      echo "<form method=get class=item>$(hidden)<input type=hidden name=aballow value='$d'><span>$d<br><small>$dev</small></span><button>$(T "Разрешить" "Allow")</button></form>"
    done
    echo "</details>"
  fi
  echo "</div>"
  echo "<div class=card><h2>$(T "Списки фильтров" "Filter lists")</h2><small>$(T "Списки в формате AdGuard или hosts. AdGuard DNS filter — DNS-версия фильтров платного AdGuard: Base, Tracking Protection, Mobile Ads, российские рекламные серверы, EasyList, EasyPrivacy." \
    "Lists in AdGuard or hosts format. AdGuard DNS filter is the DNS version of the filters in paid AdGuard: Base, Tracking Protection, Mobile Ads, Russian ad servers, EasyList, EasyPrivacy.")</small>"
  LISTS="$(flint-adblock list | esc)"
  [ -n "$LISTS" ] || echo "<p><small>$(T "пусто" "empty")</small></p>"
  echo "$LISTS" | while IFS="$TAB" read -r url name rc up; do
    [ -n "$url" ] || continue
    info="$url"; [ "$rc" != - ] && info="$(T "правил" "rules"): $rc · $(T "обновлён" "updated") $up"
    echo "<div class=item><span>$name<br><small>$info</small></span>"
    echo "<form method=get>$(hidden)<input type=hidden name=abldel value='$url'><button title='$DEL'>✕</button></form></div>"
  done
  OPTS="$(echo "$PRESETS" | while IFS=: read -r id pname; do
    echo "$LISTS" | cut -f1 | grep -qxF "$PRESET_URL$id.txt" || echo "<option value=$id>$pname</option>"
  done)"
  [ -n "$OPTS" ] && echo "<form method=get class=row>$(hidden)<select name=abpreset>$OPTS</select><button>$(T "Добавить" "Add")</button></form>"
  echo "<form method=get class=row>$(hidden)<input type=text name=ablist placeholder='https://example.com/list.txt' required>"
  echo "<input type=text name=abname placeholder='$(T "Название (необязательно)" "Name (optional)")'><button>$(T "Добавить по ссылке" "Add by link")</button></form></div>"
  echo "<div class=card><h2>$(T "Обновление списков" "List updates")</h2>"
  btn abref 1 "" "$(T "Обновить списки сейчас" "Update the lists now")"
  AI="$(flint-adblock interval)"
  echo "<form method=get class=row>$(hidden)<select name=abint>"
  for v in "off:$(T "Автообновление выключено" "Auto-update off")" "1:$(T "Обновлять каждый час" "Update every hour")" \
    "12:$(T "Обновлять каждые 12 часов" "Update every 12 hours")" "24:$(T "Обновлять раз в сутки" "Update once a day")" \
    "72:$(T "Обновлять раз в 3 дня" "Update every 3 days")" "168:$(T "Обновлять раз в неделю" "Update once a week")"; do
    sel=""; [ "${v%%:*}" = "$AI" ] && sel=" selected"
    echo "<option value='${v%%:*}'$sel>${v#*:}</option>"
  done
  echo "</select><button>$(T "Сохранить" "Save")</button></form></div>"
  echo "<div class=card><h2>$(T "Свои правила" "Own rules")</h2><small>$(T "Домен или ссылка блокируются вместе с поддоменами. «Разрешить» с шаблоном — исключение сложнее, чем сайт целиком. Шаблоны пишутся в синтаксисе AdGuard: ||ads.*^, /regex/, @@||site.ru^." \
    "A domain or link is blocked with its subdomains. \"Allow\" with a pattern makes a narrower exception than a whole site. Patterns use AdGuard syntax: ||ads.*^, /regex/, @@||site.com^.")</small>"
  echo "<form method=get class=row>$(hidden)<input type=text name=abrule placeholder='ads.example.com' required>"
  echo "<select name=abto><option value=block>$(T "Блокировать" "Block")</option><option value=allow>$(T "Разрешить" "Allow")</option></select><button>$(T "Добавить" "Add")</button></form>"
  OWNRULES="$(echo "$RULES" | grep -vE '^@@\|\|[a-z0-9.-]+\^$')"
  [ -n "$OWNRULES" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  echo "$OWNRULES" | while IFS= read -r r; do
    [ -n "$r" ] || continue
    echo "<form method=get class=item>$(hidden)<input type=hidden name=abrdel value='$r'><span>$r</span><button title='$DEL'>✕</button></form>"
  done
  echo "</div>"
  ;;
dns)
  DOH="$(flint-dns doh)"; DNSCRYPT="$(flint-dns dnscrypt)"; UDP="$(flint-dns udp)"; DNSMODE="$(flint-dns mode)"
  # dns_card <mode> <title> <hint>: a card per mode; the one in use is marked.
  dns_card() {
    used=""; [ "$1" = "$DNSMODE" ] && used=" <small class=ok>· $(T "используется" "in use")</small>"
    echo "<div class=card><h2>$2$used</h2><small>$3</small>"
  }
  # dns_select <action> doh|dnscrypt|udp <current> <button>: a preset list that sends <action>=<name>.
  dns_select() {
    echo "<form method=get class=row>$(hidden)<select name=$1>"
    flint-dns presets "$2" | esc | while IFS="$TAB" read -r n title; do
      sel=""; [ "$n" = "$3" ] && sel=" selected"
      case "$2:$n" in doh:cloudflare|dnscrypt:adguard-unfiltered) title="$title — $(T "по умолчанию" "default")" ;; esac
      echo "<option value=$n$sel>$title</option>"
    done
    echo "</select><button>$4</button></form>"
  }
  echo "<div class=card><h2>DNS</h2><small>$(T "Через этот DNS роутер узнаёт адреса сайтов для всех устройств сети. Если выбранный сервер не ответит, останется прежний." \
    "The router looks up site addresses for every device on the network through this DNS. If the chosen server does not answer, the previous one stays.")</small>"
  echo "<p>$(T "Сейчас" "Now"): <b class=ok>$(flint-dns title | esc)</b></p></div>"
  dns_card doh "$(T "DoH — зашифрованный" "DoH — encrypted")" "$(T "Запросы идут по HTTPS: провайдер не видит, какие сайты открываются, и не может подменить ответ." \
    "Queries go over HTTPS: the provider does not see which sites are opened and cannot spoof the answers.")"
  dns_select dns doh "$DOH" "$(T "Использовать DoH" "Use DoH")"
  url=""; case "$DOH" in https://*) url="$(echo "$DOH" | esc)" ;; esac
  echo "<form method=get class=row>$(hidden)<input type=text name=dnsurl value='$url' placeholder='https://dns.example.com/dns-query' required>"
  echo "<button>$(T "Свой DoH-сервер" "Own DoH server")</button></form></div>"
  dns_card dnscrypt "$(T "DNSCrypt — зашифрованный" "DNSCrypt — encrypted")" "$(T "Отдельный протокол шифрования DNS. Пригодится, если DoH в сети блокируют. Свой сервер задаётся stamp'ом sdns:// из списка dnscrypt.info." \
    "A separate DNS encryption protocol. Useful when DoH is blocked on the network. An own server is set with an sdns:// stamp from the dnscrypt.info list.")"
  dns_select dnscrypt dnscrypt "$DNSCRYPT" "$(T "Использовать DNSCrypt" "Use DNSCrypt")"
  stamps=""; case "$DNSCRYPT" in sdns://*) stamps="$(echo "$DNSCRYPT" | esc)" ;; esac
  echo "<form method=get class=row>$(hidden)<input type=text name=dnsstamp value='$stamps' placeholder='sdns://...' required>"
  echo "<button>$(T "Свой DNSCrypt-сервер" "Own DNSCrypt server")</button></form></div>"
  dns_card udp "$(T "Обычный DNS (UDP)" "Plain DNS (UDP)")" "$(T "Запросы идут открыто: провайдер их видит и может подменить. Пригодится, если шифрованный DNS в вашей сети не работает или нужен DNS основного роутера." \
    "Queries go in the clear: the provider sees them and can spoof them. Useful when encrypted DNS does not work on your network or you need the main router's DNS.")"
  dns_select dnsudp udp "$UDP" "$(T "Использовать UDP" "Use UDP")"
  ips=""; echo "$UDP" | grep -qE '^[0-9. ]+$' && ips="$UDP"
  echo "<form method=get class=row>$(hidden)<input type=text name=dnsip value='$ips' placeholder='1.1.1.1 8.8.8.8' required>"
  echo "<button>$(T "Свои DNS-серверы" "Own DNS servers")</button></form></div>"
  DEL="$(T "Удалить" "Delete")"
  echo "<div class=card><h2>$(T "Локальные имена" "Local names")</h2><small>$(T "Устройство в сети открывается по имени вместо IP: nas01, nas01.lan и nas01.local. Имя с точкой, например nas.home, работает как есть. Повторное добавление имени меняет его адрес. Закрепите за устройством постоянный IP на роутере, который его выдаёт, иначе имя может перестать работать после перезагрузки." \
    "A device on the network opens by name instead of IP: nas01, nas01.lan and nas01.local. A name with a dot, such as nas.home, works as is. Adding a name again changes its address. Give the device a fixed IP on the router that hands it out, or the name may stop working after a reboot.")</small>"
  HOSTS="$(flint-dns hosts | esc)"
  [ -n "$HOSTS" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  echo "$HOSTS" | while IFS="$TAB" read -r n ip; do
    [ -n "$n" ] || continue
    echo "<form method=get class=item>$(hidden)<input type=hidden name=hostdel value='$n'><span>$n<br><small>$ip</small></span><button title='$DEL'>✕</button></form>"
  done
  echo "<form method=get class=row>$(hidden)<input type=text name=hostadd placeholder='nas01' required>"
  echo "<input type=text name=hostip placeholder='192.168.0.145' list=lan-devices required><button>$(T "Добавить имя" "Add a name")</button></form>"
  echo "<datalist id=lan-devices>"
  flint-adblock devices | esc | while IFS="$TAB" read -r m ip name; do echo "<option value='$ip'>${name:-$m}</option>"; done
  echo "</datalist></div>"
  ;;
settings)
  echo "<div class=card><h2>$(T "Сменить PIN" "Change PIN")</h2><small>$(T "Только буквы и цифры. PIN хранится в flint.env на роутере; при деплое с компьютера снова подставится PIN из config/flint.env." \
    "Letters and digits only. The PIN is stored in flint.env on the router; a deploy from the computer will put back the PIN from config/flint.env.")</small>"
  echo "<form method=get class=row>$(hidden)<input type=hidden name=pin value=1>"
  echo "<input type=password name=pinold placeholder='$(T "текущий PIN" "current PIN")' autocomplete=current-password required>"
  echo "<input type=password name=pinnew placeholder='$(T "новый PIN" "new PIN")' autocomplete=new-password required>"
  echo "<input type=password name=pinok placeholder='$(T "ещё раз новый PIN" "new PIN again")' autocomplete=new-password required>"
  echo "<button>$(T "Сменить PIN" "Change PIN")</button></form></div>"
  echo "<div class=card><h2>$(T "Экспорт настроек" "Export settings")</h2><small>$(T "Подписки, свои и ручные серверы, сайты, устройства без VPN, блокировка рекламы, DNS-сервер, локальные имена, режимы и интервалы. PIN и сеть (flint.env) в файл не входят, поэтому его можно загрузить и на другой Flint. В файле ссылки подписок и данные серверов — храните его как пароль." \
    "Subscriptions, own and manual servers, sites, devices without VPN, ad blocking, DNS server, local names, modes and intervals. The PIN and network (flint.env) are not included, so the file also fits another Flint. It holds subscription links and server data — keep it like a password.")</small>"
  echo "<div class=cta><a class='btn on' href='?pass=$pass&amp;export=1'>⬇️ $(T "Скачать файл настроек" "Download the settings file")</a></div></div>"
  ASK="$(T "Заменить текущие настройки настройками из файла?" "Replace the current settings with the ones from the file?")"
  echo "<div class=card><h2>$(T "Импорт настроек" "Import settings")</h2><small>$(T "Все настройки из списка выше заменятся настройками из файла и сразу применятся. Прежние сохраняются на роутере в /tmp/flint-settings-prev.txt до перезагрузки." \
    "All the settings listed above are replaced with the ones from the file and applied at once. The previous ones stay on the router in /tmp/flint-settings-prev.txt until a reboot.")</small>"
  echo "<form method=post enctype=multipart/form-data action='?pass=$pass&amp;tab=settings&amp;import=1' class=row onsubmit=\"return confirm('$ASK')\">"
  echo "<input type=file name=file accept='.txt,text/plain' required><button>$(T "Загрузить настройки" "Upload settings")</button></form></div>"
  ;;
esac
echo "</div></div>$FOOTER$VER</body></html>"
