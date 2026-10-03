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

echo "Content-Type: text/html; charset=utf-8"
[ "$lang" = "$L" ] && echo "Set-Cookie: lang=$L; Path=/; Max-Age=31536000; SameSite=Lax"
echo ""

pass="$(get pass)"; node="$(get node)"; routing="$(get routing)"; vpn="$(get vpn)"; sub="$(get sub)"
add="$(param add)"; to="$(get to)"; del="$(param del)"
link="$(param link)"; edit="$(get edit)"; copy="$(get copy)"; newnode="$(get newnode)"; save="$(get save)"; ndel="$(get ndel)"
subint="$(get subint)"; wd="$(get wd)"
adblock="$(get adblock)"; ablist="$(param ablist)"; abname="$(param abname)"; abpreset="$(get abpreset)"; abldel="$(param abldel)"
abrule="$(param abrule)"; abto="$(get abto)"; abrdel="$(param abrdel)"; abint="$(get abint)"; abref="$(get abref)"
abxadd="$(param abxadd)"; abxname="$(param abxname)"; abxdel="$(param abxdel)"
tab="$(get tab)"
case "$tab" in status|servers|own|routing|adblock) ;; *) tab=status ;; esac
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
logo() {
  last="${TITLE##* }"; first="${TITLE% *}"
  [ "$first" = "$TITLE" ] && last=""
  [ -n "$last" ] && last=" <b>$last</b>"
  tag=""; [ -n "$TAGLINE" ] && tag="<div class=tag>$TAGLINE</div>"
  echo "<div class=\"logo $1\"><img src=/logo.svg alt=\"\"><div><div class=word>$first$last</div>$tag</div></div>"
}
# Language switch; $1 is the link prefix ending in "?" or "&amp;".
langs() {
  if [ "$L" = en ]; then echo "<div class=lang><a href='${1}lang=ru'>RU</a> · <b>EN</b></div>"
  else echo "<div class=lang><b>RU</b> · <a href='${1}lang=en'>EN</a></div>"; fi
}
cat <<HTML
<!DOCTYPE html><html lang=$L><head>
<meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>$TITLE</title>
<link rel=icon type=image/svg+xml href=/icon.svg>
<style>
body{margin:0;font-family:system-ui,sans-serif;background:#111827;color:#e5e7eb;min-height:100vh;display:flex;flex-direction:column}
footer{margin-top:auto;padding:32px 0 28px;display:flex;align-items:center;gap:18px;font:700 15px/1 ui-monospace,Consolas,"Courier New",monospace;letter-spacing:.3em;color:#cbd5e1;white-space:nowrap}
footer::before,footer::after{content:"";flex:1;height:2px;background:linear-gradient(90deg,transparent,#f59e0b)}
footer::after{background:linear-gradient(90deg,#f59e0b,transparent)}
footer b{color:#f59e0b}
@media(max-width:480px){footer{font-size:12px;letter-spacing:.18em;gap:10px}}
main,.layout{flex-shrink:0}
main{max-width:640px;width:100%;box-sizing:border-box;margin:0 auto;padding:20px}
h2{font-size:17px;margin:0 0 8px}
.card{background:#1f2937;border-radius:12px;padding:14px;margin:12px 0}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:8px}
button{width:100%;padding:12px;border-radius:10px;border:1px solid #374151;background:#111827;color:#e5e7eb;font-size:15px}
.grid button{text-align:left}
button.on{border-color:#34d399;background:#064e3b}
button.off{border-color:#f87171;background:#450a0a}
form.act{margin-top:10px}
form.row{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}
form.row input[type=text],form.row select{flex:1 1 200px}
form.row button{width:auto}
.item{display:flex;align-items:center;gap:8px;margin:4px 0}
.item span{flex:1;word-break:break-all}
.item button{width:auto;padding:4px 10px}
label{display:block;margin-top:8px}
label input{width:100%;box-sizing:border-box;margin-top:4px}
input,select{padding:10px;border-radius:8px;border:1px solid #374151;background:#0b1220;color:#e5e7eb;font-size:15px}
pre{white-space:pre-wrap;margin:0}
small{color:#9ca3af}
.ok{color:#34d399}.err{color:#f87171}
.logo{display:flex;align-items:center;gap:.35em;font-size:22px}
.logo img{width:2.1em;height:2.1em;object-fit:contain;flex:none}
.logo .word{font-weight:800;line-height:1.05;letter-spacing:-.01em;white-space:nowrap;color:#f9fafb;text-align:center;padding-right:.12em}
.logo .word b{color:#f59e0b;font-weight:800}
.logo .tag{display:flex;align-items:center;gap:.5em;margin-top:.3em;font-size:.36em;font-weight:600;letter-spacing:.22em;text-transform:uppercase;color:#d1d5db;white-space:nowrap}
.logo .tag::before,.logo .tag::after{content:"";flex:1;min-width:.8em;height:2px;background:#f59e0b;border-radius:1px}
.logo.big{font-size:40px;justify-content:center;margin:40px 0 8px}
.lang{font-size:14px;color:#6b7280;letter-spacing:.05em}
.lang a{color:#93c5fd;text-decoration:none}
.lang b{color:#e5e7eb}
main>.lang{text-align:center;margin-top:4px}
.login{max-width:340px;margin-left:auto;margin-right:auto;padding:28px 24px;text-align:center}
.login{margin-top:16px}
.lock{font-size:40px}
.login-hint{color:#9ca3af;margin:8px 0 18px}
.login-err{margin:-6px 0 14px}
.login input{width:100%;box-sizing:border-box;padding:14px;font-size:20px;text-align:center;letter-spacing:4px;margin-bottom:12px}
.login input::placeholder{letter-spacing:normal}
.login input:focus{outline:none;border-color:#34d399}
.layout{display:flex;gap:24px;max-width:960px;width:100%;box-sizing:border-box;margin:0 auto;padding:20px}
nav{flex:0 0 200px;position:sticky;top:20px;align-self:flex-start}
nav .brand{margin:4px 8px 18px}
nav a{display:block;padding:10px 12px;margin-bottom:4px;border-radius:10px;color:#e5e7eb;text-decoration:none}
nav a:hover{background:#1f2937}
nav a.cur{background:#1f2937;color:#34d399;font-weight:600}
nav a.logout{color:#9ca3af;margin-top:16px}
nav .lang{padding:6px 12px}
nav .lang a{display:inline;padding:0;margin:0;background:none;color:#93c5fd}
.content{flex:1;min-width:0}
.content>.card:first-child{margin-top:0}
.stat{display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-bottom:1px solid #374151}
.stat:last-of-type{border-bottom:0}
.stat a{color:#93c5fd}
.stat>span:first-child{white-space:nowrap}
summary{cursor:pointer}
.stat>:last-child{text-align:right}
@media(max-width:720px){
.layout{flex-direction:column;gap:12px;padding:12px}
nav{flex:none;position:static;display:grid;grid-template-columns:1fr 1fr;gap:6px;align-self:stretch}
nav .brand{grid-column:1/-1;margin:0 4px 4px}
nav a{margin:0;padding:10px;background:#1f2937;text-align:center}
nav a.logout{grid-column:1/-1;background:none;padding:2px;margin:0;font-size:14px}
nav .lang{grid-column:1/-1;text-align:center;padding:0}
.stat{flex-wrap:wrap}
}
</style></head><body>
HTML
if [ -z "$UI_PIN" ] || [ "$pass" != "$UI_PIN" ]; then
  err=""; [ -n "$pass" ] && err="<p class='err login-err'>$(T "Неверный PIN, попробуйте ещё раз" "Wrong PIN, please try again")</p>"
  cat <<HTML
<main>$(logo big)<div class="card login"><div class=lock>🔒</div>
<p class=login-hint>$(T "Введите PIN, чтобы управлять VPN" "Enter the PIN to manage the VPN")</p>$err
<form method=get><input type=password name=pass placeholder=PIN autocomplete=current-password autofocus required>
<button class=on>$(T "Войти" "Sign in")</button></form></div>$(langs "?")</main>$FOOTER</body></html>
HTML
  exit 0
fi

msg=""; form=""
if [ -n "$node" ]; then
  msg="$(flint-node "$node" 2>&1)"
elif [ "$routing" = ru ] || [ "$routing" = global ]; then
  msg="$(flint-node routing "$routing" 2>&1)"
elif [ "$vpn" = on ] || [ "$vpn" = off ]; then
  msg="$(flint-node vpn "$vpn" 2>&1)"
elif [ "$sub" = 1 ]; then
  msg="$(flint-sub-update 2>&1)"
elif [ -n "$subint" ]; then
  msg="$(flint-sub-update interval "$subint" 2>&1)"
elif [ "$wd" = on ] || [ "$wd" = off ]; then
  msg="$(flint-watchdog "$wd" 2>&1)"
elif [ "$adblock" = on ] || [ "$adblock" = off ]; then
  msg="$(flint-adblock "$adblock" 2>&1)"
elif [ -n "$abpreset" ]; then
  pname="$(echo "$PRESETS" | awk -F : -v i="$abpreset" '$1 == i { print $2 }')"
  [ -n "$pname" ] && msg="$(flint-adblock list add "$PRESET_URL$abpreset.txt" "$pname" 2>&1)"
elif [ -n "$ablist" ]; then
  msg="$(flint-adblock list add "$ablist" "$abname" 2>&1)"
elif [ -n "$abldel" ]; then
  msg="$(flint-adblock list del "$abldel" 2>&1)"
elif [ -n "$abrule" ] && { [ "$abto" = block ] || [ "$abto" = allow ]; }; then
  msg="$(flint-adblock rule add "$abto" "$abrule" 2>&1)"
elif [ -n "$abrdel" ]; then
  msg="$(flint-adblock rule del "$abrdel" 2>&1)"
elif [ -n "$abint" ]; then
  msg="$(flint-adblock interval "$abint" 2>&1)"
elif [ "$abref" = 1 ]; then
  msg="$(flint-adblock refresh 2>&1)"
elif [ -n "$abxadd" ]; then
  msg="$(flint-adblock exclude add "$abxadd" "$abxname" 2>&1)"
elif [ -n "$abxdel" ]; then
  msg="$(flint-adblock exclude del "$abxdel" 2>&1)"
elif [ -n "$add" ] && { [ "$to" = direct ] || [ "$to" = proxy ]; }; then
  msg="$(flint-node site add "$to" "$add" 2>&1)"
elif [ -n "$del" ]; then
  msg="$(flint-node site del "$del" 2>&1)"
elif [ -n "$link" ]; then
  msg="$(flint-custom link "$link" 2>&1)"
elif [ -n "$ndel" ]; then
  msg="$(flint-custom del "$ndel" 2>&1)"
elif [ -n "$save" ]; then
  f_name="$(param n)"; f_addr="$(param a)"; f_port="$(param p)"; f_uuid="$(param u)"
  f_sni="$(param s)"; f_pbk="$(param k)"; f_sid="$(param i)"; f_net="$(get t)"; f_svc="$(param g)"
  # On a validation error keep the form open with what was typed.
  msg="$(flint-custom set "$save" "$f_name" "$f_addr" "$f_port" "$f_uuid" "$f_sni" "$f_pbk" "$f_sid" "$f_net" "$f_svc" 2>&1)" || form="$save"
elif [ -n "$edit" ] || [ -n "$copy" ]; then
  TAB="$(printf '\t')"
  IFS="$TAB" read -r f_code f_name f_addr f_port f_uuid f_sni f_pbk f_sid f_net f_svc <<EOF
$(flint-custom show "${edit:-$copy}")
EOF
  [ "$f_sid" = - ] && f_sid=""
  [ "$f_svc" = - ] && f_svc=""
  if [ -n "$edit" ]; then form="$edit"; else form=new; f_name="$f_name ($(T "копия" "copy"))"; fi
elif [ "$newnode" = 1 ]; then
  form=new; f_port=443
fi

CUR="$(cat /etc/xray/current-node 2>/dev/null || echo unknown)"
MODE="$(flint-node routing)"
VPN="$(flint-node vpn)"
TAB="$(printf '\t')"
hidden() { echo "<input type=hidden name=pass value='$pass'><input type=hidden name=tab value='$tab'>"; }
btn() { echo "<form method=get class=act>$(hidden)<input type=hidden name=$1 value='$2'><button$3>$4</button></form>"; }
field() { echo "<label>$1<input type=text name=$2 value='$(printf '%s' "$3" | esc)'$4></label>"; }
NAMES="$(flint-node names | esc)"
CUR_NAME="$(echo "$NAMES" | awk -F "$TAB" -v c="$CUR" '$1 == c {print $2}')"
SITES="$(flint-node site list)"
ON="<b class=ok>$(T "включено" "on")</b>"; OFF="<b class=err>$(T "выключено" "off")</b>"
NEVER="$(T "ещё не было" "never")"

echo "<div class=layout><nav>$(logo brand)"
for t in "status:🏠 $(T "Статус" "Status")" "servers:🌍 $(T "Серверы" "Servers")" "own:⭐ $(T "Свои серверы" "Own servers")" \
  "routing:🔀 $(T "Маршрутизация" "Routing")" "adblock:🛡️ $(T "Реклама" "Ad blocking")"; do
  cur=""; [ "${t%%:*}" = "$tab" ] && cur=" class=cur"
  echo "<a href='?pass=$pass&amp;tab=${t%%:*}'$cur>${t#*:}</a>"
done
echo "<a href='?' class=logout>$(T "Выйти" "Sign out")</a>$(langs "?pass=$pass&amp;tab=$tab&amp;")</nav><div class=content>"
[ -n "$msg" ] && echo "<div class=card><pre class=ok>$(echo "$msg" | esc)</pre></div>"

case "$tab" in
status)
  echo "<div class=card>"
  if [ "$VPN" = off ]; then
    IP="$(curl -s -m 8 https://ifconfig.me 2>/dev/null || echo n/a)"
    echo "<b class=err>$(T "VPN выключен" "VPN is off")</b> — $(T "устройства ходят в интернет напрямую" "devices go online directly")<br>IP: <b>$IP</b>"
    btn vpn on " class=on" "$(T "Включить VPN" "Turn VPN on")"
  else
    IP="$(curl -s -m 8 -x http://127.0.0.1:1087 https://ifconfig.me 2>/dev/null || echo n/a)"
    echo "VPN: <b class=ok>$(T "включён" "on")</b><br>$(T "Сервер" "Server"): <b class=ok>${CUR_NAME:-$CUR}</b><br>IP: <b>$IP</b>"
    btn vpn off " class=off" "$(T "Выключить VPN" "Turn VPN off")"
  fi
  echo "</div>"
  [ "$MODE" = ru ] && geo="<b class=ok>$(T "включён" "on")</b>" || geo="<b class=err>$(T "выключен" "off")</b>"
  total="$(echo "$NAMES" | grep -c .)"; own="$(flint-custom list | grep -c .)"
  ndirect="$(echo "$SITES" | grep -c '^direct')"; nproxy="$(echo "$SITES" | grep -c '^proxy')"
  CHECKED="$(cat /etc/xray/sub-checked 2>/dev/null | esc)"
  WLAST="$(cat /etc/xray/watchdog-last 2>/dev/null | esc)"
  [ "$(flint-watchdog state)" = on ] && wds="$ON" || wds="$OFF"
  echo "<div class=card>"
  echo "<div class=stat><span>$(T "Гео-фильтр РФ" "Russia geo filter")</span><span>$geo</span></div>"
  echo "<div class=stat><span>$(T "Свои сайты" "Own sites")</span><a href='?pass=$pass&amp;tab=routing'>$(T "$ndirect напрямую, $nproxy через VPN" "$ndirect direct, $nproxy via VPN")</a></div>"
  echo "<div class=stat><span>$(T "Серверов" "Servers")</span><a href='?pass=$pass&amp;tab=servers'>$(T "$total, из них своих $own" "$total, $own of them own")</a></div>"
  echo "<div class=stat><span>$(T "Проверка подписки" "Subscription check")</span><span>${CHECKED:-$NEVER}</span></div>"
  echo "<div class=stat><span>$(T "Автопереключение при сбое" "Failover")</span><a href='?pass=$pass&amp;tab=servers'>$wds</a></div>"
  [ "$(flint-adblock state)" = on ] && abs="$ON" || abs="$OFF"
  echo "<div class=stat><span>$(T "Блокировка рекламы" "Ad blocking")</span><a href='?pass=$pass&amp;tab=adblock'>$abs</a></div>"
  [ -n "$WLAST" ] && echo "<div class=stat><span>$(T "Последний сбой" "Last failure")</span><span>$WLAST</span></div>"
  echo "</div>"
  ;;
servers)
  grid() {
    echo "$NAMES" | while IFS="$TAB" read -r code name kind; do
      [ -n "$code" ] && [ "$kind" = "$1" ] || continue
      on=""; [ "$code" = "$CUR" ] && on=" on"
      echo "<form method=get>$(hidden)<input type=hidden name=node value='$code'><button class='$on'>$name</button></form>"
    done
  }
  echo "<div class=card><h2>$(T "Серверы" "Servers")</h2><div class=grid>$(grid domain)</div></div>"
  WL="$(grid ip)"
  if [ -n "$WL" ]; then
    open=""; echo "$NAMES" | awk -F "$TAB" -v c="$CUR" '$1 == c && $3 == "ip" { f = 1 } END { exit !f }' && open=" open"
    echo "<details class=card$open><summary><b>$(T "Белые списки" "White lists")</b> <small>— $(T "серверы по IP-адресу, для сетей, где открыт только белый список" "servers by IP address, for networks where only a white list is open")</small></summary>"
    echo "<div class=grid style='margin-top:10px'>$WL</div></details>"
  fi
  echo "<div class=card><h2>$(T "Подписка" "Subscription")</h2>"
  btn sub 1 "" "$(T "Обновить список серверов сейчас" "Refresh the server list now")"
  CHECKED="$(cat /etc/xray/sub-checked 2>/dev/null | esc)"
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
  echo "</select><button>$(T "Сохранить" "Save")</button></form></div>"
  echo "<div class=card><h2>$(T "Автопереключение при сбое" "Failover")</h2>"
  if [ "$(flint-watchdog state)" = on ]; then
    echo "$ON — $(T "каждые 2 минуты роутер проверяет VPN. Если сервер не отвечает, а интернет есть, он обновляет подписку и при необходимости переходит на первый рабочий сервер." \
      "every 2 minutes the router checks the VPN. If the server does not respond while the internet works, it refreshes the subscription and, if needed, switches to the first working server.")"
    btn wd off "" "$(T "Выключить автопереключение" "Turn failover off")"
  else
    echo "$OFF — $(T "при сбое сервера интернет пропадёт, пока не выберете другой сервер вручную." "if the server fails, the internet stays down until you pick another server manually.")"
    btn wd on " class=on" "$(T "Включить автопереключение" "Turn failover on")"
  fi
  WLAST="$(cat /etc/xray/watchdog-last 2>/dev/null | esc)"
  echo "<small>$(T "Последнее срабатывание" "Last triggered"): ${WLAST:-$NEVER}</small></div>"
  ;;
own)
  if [ -n "$form" ]; then
    [ "$form" = new ] && title="$(T "Новый сервер" "New server")" || title="$(T "Изменить сервер" "Edit server")"
    echo "<div class=card><h2>$title</h2><small>$(T "Поддерживаются VLESS + REALITY поверх TCP (xtls-rprx-vision) или gRPC." "Supported: VLESS + REALITY over TCP (xtls-rprx-vision) or gRPC.")</small>"
    echo "<form method=get>$(hidden)<input type=hidden name=save value='$form'>"
    field "$(T "Название" "Name")" n "$f_name" " maxlength=60"
    field "$(T "Адрес сервера" "Server address")" a "$f_addr" " required"
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
  echo "<form method=get class=row>$(hidden)<select name=copy>"
  echo "$NAMES" | while IFS="$TAB" read -r code name kind; do [ -n "$code" ] && echo "<option value='$code'>$name</option>"; done
  echo "</select><button>$(T "Скопировать и изменить" "Copy and edit")</button></form>"
  btn newnode 1 "" "$(T "Ввести вручную" "Enter manually")"
  echo "</div>"
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
  echo "<div class=card><h2>$(T "Свои сайты" "Own sites")</h2><small>$(T "Важнее гео-фильтра. Домен действует вместе с поддоменами; можно вставить ссылку, IP или подсеть." "Override the geo filter. A domain covers its subdomains; you can paste a link, an IP or a subnet.")</small>"
  echo "<form method=get class=row>$(hidden)<input type=text name=add placeholder='example.com' required>"
  echo "<select name=to><option value=direct>$(T "Напрямую" "Direct")</option><option value=proxy>$(T "Через VPN" "Via VPN")</option></select><button>$(T "Добавить" "Add")</button></form>"
  DEL="$(T "Удалить" "Delete")"
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
  echo "<div class=card><h2>$(T "Свои правила" "Own rules")</h2><small>$(T "Домен или ссылка блокируются вместе с поддоменами. «Разрешить» — исключение, если список заблокировал нужный сайт. Шаблоны пишутся в синтаксисе AdGuard: ||ads.*^, /regex/, @@||site.ru^." \
    "A domain or link is blocked with its subdomains. \"Allow\" makes an exception when a list blocks a site you need. Patterns use AdGuard syntax: ||ads.*^, /regex/, @@||site.com^.")</small>"
  echo "<form method=get class=row>$(hidden)<input type=text name=abrule placeholder='ads.example.com' required>"
  echo "<select name=abto><option value=block>$(T "Блокировать" "Block")</option><option value=allow>$(T "Разрешить" "Allow")</option></select><button>$(T "Добавить" "Add")</button></form>"
  RULES="$(flint-adblock rule | esc)"
  [ -n "$RULES" ] || echo "<p><small>$(T "пока нет" "none yet")</small></p>"
  echo "$RULES" | while IFS= read -r r; do
    [ -n "$r" ] || continue
    echo "<form method=get class=item>$(hidden)<input type=hidden name=abrdel value='$r'><span>$r</span><button title='$DEL'>✕</button></form>"
  done
  echo "</div>"
  ;;
esac
echo "</div></div>$FOOTER</body></html>"
