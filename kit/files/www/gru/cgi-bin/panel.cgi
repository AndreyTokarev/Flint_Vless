#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
echo "Content-Type: text/html; charset=utf-8"
echo ""
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
pass="$(get pass)"; node="$(get node)"; routing="$(get routing)"; vpn="$(get vpn)"; sub="$(get sub)"
add="$(param add)"; to="$(get to)"; del="$(param del)"
link="$(param link)"; edit="$(get edit)"; copy="$(get copy)"; newnode="$(get newnode)"; save="$(get save)"; ndel="$(get ndel)"
subint="$(get subint)"; wd="$(get wd)"
tab="$(get tab)"
case "$tab" in status|servers|own|routing) ;; *) tab=status ;; esac
. /etc/xray/gru.env
TITLE="$(echo "${UI_TITLE:-Flint VPN}" | esc)"
TAGLINE="$(echo "${UI_TAGLINE-Sail the internet}" | esc)"
SHIELD='<path d="M7 15 29 8l16 8-2 22c-1 9-8 16-19 21C13 54 8 46 7 37Z" fill="url(#lg)" stroke="#e5e7eb" stroke-width="3" stroke-linejoin="round"/><path d="M10 17l18-6 3 13-10 6-11-4Z" fill="#4c6ef5" opacity=".55"/><path d="M14 21l10 6 9-6M24 27v22" fill="none" stroke="#e5e7eb" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M27 36C35 24 45 13 61 4 56 15 47 26 36 35Z" fill="#f59e0b"/><path d="M23 31C30 21 39 13 52 6 47 14 40 22 31 29Z" fill="#fcd34d"/>'
FOOTER='<footer>YOUR NETWORK.<br>YOUR RULES.</footer>'
ICON='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><path d="M17 31l-5 13 6-2-1 7 6-5ZM47 31l5 13-6-2 1 7-6-5Z" fill="#1e2a7a"/><path d="M17 31c0 12 2 17 7 19v6c4 3 12 3 16 0v-6c5-2 7-7 7-19Z" fill="#e5e7eb"/><path d="M20 38l9 2c0 4-4 5-7 3Z" fill="#111827"/><circle cx="25.5" cy="41.2" r="1.7" fill="#22d3ee"/><path d="M18 35l29 5" stroke="#1e2a7a" stroke-width="2"/><ellipse cx="38.5" cy="41.5" rx="5.2" ry="4.2" fill="#1e2a7a"/><path d="M32 45l-2.2 4h4.4Z" fill="#111827"/><path d="M25 52.5h14M28 50.5v5M31 50.8v5.4M34 50.8v5.4M37 50.5v5" stroke="#4b5563" stroke-width="1"/><path d="M4 19c6 3 11 5 15 6 2-14 24-14 26 0 4-1 9-3 15-6-3 11-14 16-28 16S7 30 4 19Z" fill="#23308f" stroke="#f5b301" stroke-width="2" stroke-linejoin="round"/><path d="M32 15.5l5 3v6l-5 3-5-3v-6Z" fill="#e5e7eb"/><path d="M27 18.5l5 3 5-3M32 21.5v6" fill="none" stroke="#23308f" stroke-width="1.3"/><path d="M33 25l10-11-3 7Z" fill="#f5b301"/></svg>'
logo() {
  last="${TITLE##* }"; first="${TITLE% *}"
  [ "$first" = "$TITLE" ] && last=""
  [ -n "$last" ] && last=" <b>$last</b>"
  tag=""; [ -n "$TAGLINE" ] && tag="<div class=tag>$TAGLINE</div>"
  echo "<div class=\"logo $1\"><svg viewBox=\"0 0 64 64\" aria-hidden=true><defs><linearGradient id=lg x1=0 y1=0 x2=1 y2=1><stop offset=0 stop-color=\"#2f4fc4\"/><stop offset=1 stop-color=\"#0f1a4a\"/></linearGradient></defs>$SHIELD</svg><div><div class=word>$first$last</div>$tag</div></div>"
}
cat <<HTML
<!DOCTYPE html><html lang=ru><head>
<meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>$TITLE</title>
<link rel=icon href="data:image/svg+xml,$(echo "$ICON" | sed -e 's/"/'"'"'/g' -e 's/#/%23/g' -e 's/</%3C/g' -e 's/>/%3E/g')">
<style>
body{margin:0;font-family:system-ui,sans-serif;background:#111827;color:#e5e7eb;min-height:100vh;display:flex;flex-direction:column}
footer{margin-top:auto;padding:28px 20px 24px;box-sizing:border-box;width:100%;max-width:960px;align-self:center;font:600 13px/1.6 ui-monospace,Consolas,"Courier New",monospace;letter-spacing:.25em;color:#94a3b8;opacity:.8}
main+footer{text-align:center}
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
.logo svg{width:2.1em;height:2.1em;flex:none}
.logo .word{font-weight:800;line-height:1.05;letter-spacing:-.01em;white-space:nowrap;color:#f9fafb}
.logo .word b{color:#f59e0b;font-weight:800}
.logo .tag{display:flex;align-items:center;gap:.5em;margin-top:.3em;font-size:.36em;font-weight:600;letter-spacing:.22em;text-transform:uppercase;color:#d1d5db;white-space:nowrap}
.logo .tag::before,.logo .tag::after{content:"";flex:1;min-width:.8em;height:2px;background:#f59e0b;border-radius:1px}
.logo.big{font-size:40px;justify-content:center;margin:40px 0 8px}
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
.stat{flex-wrap:wrap}
}
</style></head><body>
HTML
if [ -z "$UI_PIN" ] || [ "$pass" != "$UI_PIN" ]; then
  err=""; [ -n "$pass" ] && err="<p class='err login-err'>Неверный PIN, попробуйте ещё раз</p>"
  cat <<HTML
<main>$(logo big)<div class="card login"><div class=lock>🔒</div>
<p class=login-hint>Введите PIN, чтобы управлять VPN</p>$err
<form method=get><input type=password name=pass placeholder=PIN autocomplete=current-password autofocus required>
<button class=on>Войти</button></form></div></main>$FOOTER</body></html>
HTML
  exit 0
fi

msg=""; form=""
if [ -n "$node" ]; then
  msg="$(gru-node "$node" 2>&1)"
elif [ "$routing" = ru ] || [ "$routing" = global ]; then
  msg="$(gru-node routing "$routing" 2>&1)"
elif [ "$vpn" = on ] || [ "$vpn" = off ]; then
  msg="$(gru-node vpn "$vpn" 2>&1)"
elif [ "$sub" = 1 ]; then
  msg="$(gru-sub-update 2>&1)"
elif [ -n "$subint" ]; then
  msg="$(gru-sub-update interval "$subint" 2>&1)"
elif [ "$wd" = on ] || [ "$wd" = off ]; then
  msg="$(gru-watchdog "$wd" 2>&1)"
elif [ -n "$add" ] && { [ "$to" = direct ] || [ "$to" = proxy ]; }; then
  msg="$(gru-node site add "$to" "$add" 2>&1)"
elif [ -n "$del" ]; then
  msg="$(gru-node site del "$del" 2>&1)"
elif [ -n "$link" ]; then
  msg="$(gru-custom link "$link" 2>&1)"
elif [ -n "$ndel" ]; then
  msg="$(gru-custom del "$ndel" 2>&1)"
elif [ -n "$save" ]; then
  f_name="$(param n)"; f_addr="$(param a)"; f_port="$(param p)"; f_uuid="$(param u)"
  f_sni="$(param s)"; f_pbk="$(param k)"; f_sid="$(param i)"; f_net="$(get t)"; f_svc="$(param g)"
  # On a validation error keep the form open with what was typed.
  msg="$(gru-custom set "$save" "$f_name" "$f_addr" "$f_port" "$f_uuid" "$f_sni" "$f_pbk" "$f_sid" "$f_net" "$f_svc" 2>&1)" || form="$save"
elif [ -n "$edit" ] || [ -n "$copy" ]; then
  TAB="$(printf '\t')"
  IFS="$TAB" read -r f_code f_name f_addr f_port f_uuid f_sni f_pbk f_sid f_net f_svc <<EOF
$(gru-custom show "${edit:-$copy}")
EOF
  [ "$f_sid" = - ] && f_sid=""
  [ "$f_svc" = - ] && f_svc=""
  if [ -n "$edit" ]; then form="$edit"; else form=new; f_name="$f_name (копия)"; fi
elif [ "$newnode" = 1 ]; then
  form=new; f_port=443
fi

CUR="$(cat /etc/xray/current-node 2>/dev/null || echo unknown)"
MODE="$(gru-node routing)"
VPN="$(gru-node vpn)"
TAB="$(printf '\t')"
hidden() { echo "<input type=hidden name=pass value='$pass'><input type=hidden name=tab value='$tab'>"; }
btn() { echo "<form method=get class=act>$(hidden)<input type=hidden name=$1 value='$2'><button$3>$4</button></form>"; }
field() { echo "<label>$1<input type=text name=$2 value='$(printf '%s' "$3" | esc)'$4></label>"; }
NAMES="$(gru-node names | esc)"
CUR_NAME="$(echo "$NAMES" | awk -F "$TAB" -v c="$CUR" '$1 == c {print $2}')"
SITES="$(gru-node site list)"

echo "<div class=layout><nav>$(logo brand)"
for t in "status:🏠 Статус" "servers:🌍 Серверы" "own:⭐ Свои серверы" "routing:🔀 Маршрутизация"; do
  cur=""; [ "${t%%:*}" = "$tab" ] && cur=" class=cur"
  echo "<a href='?pass=$pass&amp;tab=${t%%:*}'$cur>${t#*:}</a>"
done
echo "<a href='?' class=logout>Выйти</a></nav><div class=content>"
[ -n "$msg" ] && echo "<div class=card><pre class=ok>$(echo "$msg" | esc)</pre></div>"

case "$tab" in
status)
  echo "<div class=card>"
  if [ "$VPN" = off ]; then
    IP="$(curl -s -m 8 https://ifconfig.me 2>/dev/null || echo n/a)"
    echo "<b class=err>VPN выключен</b> — устройства ходят в интернет напрямую<br>IP: <b>$IP</b>"
    btn vpn on " class=on" "Включить VPN"
  else
    IP="$(curl -s -m 8 -x http://127.0.0.1:1087 https://ifconfig.me 2>/dev/null || echo n/a)"
    echo "VPN: <b class=ok>включён</b><br>Сервер: <b class=ok>${CUR_NAME:-$CUR}</b><br>IP: <b>$IP</b>"
    btn vpn off " class=off" "Выключить VPN"
  fi
  echo "</div>"
  [ "$MODE" = ru ] && geo="<b class=ok>включён</b>" || geo="<b class=err>выключен</b>"
  total="$(echo "$NAMES" | grep -c .)"; own="$(gru-custom list | grep -c .)"
  ndirect="$(echo "$SITES" | grep -c '^direct')"; nproxy="$(echo "$SITES" | grep -c '^proxy')"
  CHECKED="$(cat /etc/xray/sub-checked 2>/dev/null | esc)"
  WLAST="$(cat /etc/xray/watchdog-last 2>/dev/null | esc)"
  [ "$(gru-watchdog state)" = on ] && wds="<b class=ok>включено</b>" || wds="<b class=err>выключено</b>"
  echo "<div class=card>"
  echo "<div class=stat><span>Гео-фильтр РФ</span><span>$geo</span></div>"
  echo "<div class=stat><span>Свои сайты</span><a href='?pass=$pass&amp;tab=routing'>$ndirect напрямую, $nproxy через VPN</a></div>"
  echo "<div class=stat><span>Серверов</span><a href='?pass=$pass&amp;tab=servers'>$total, из них своих $own</a></div>"
  echo "<div class=stat><span>Проверка подписки</span><span>${CHECKED:-ещё не было}</span></div>"
  echo "<div class=stat><span>Автопереключение при сбое</span><a href='?pass=$pass&amp;tab=servers'>$wds</a></div>"
  [ -n "$WLAST" ] && echo "<div class=stat><span>Последний сбой</span><span>$WLAST</span></div>"
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
  echo "<div class=card><h2>Серверы</h2><div class=grid>$(grid domain)</div></div>"
  WL="$(grid ip)"
  if [ -n "$WL" ]; then
    open=""; echo "$NAMES" | awk -F "$TAB" -v c="$CUR" '$1 == c && $3 == "ip" { f = 1 } END { exit !f }' && open=" open"
    echo "<details class=card$open><summary><b>Белые списки</b> <small>— серверы по IP-адресу, для сетей, где открыт только белый список</small></summary>"
    echo "<div class=grid style='margin-top:10px'>$WL</div></details>"
  fi
  echo "<div class=card><h2>Подписка</h2>"
  btn sub 1 "" "Обновить список серверов сейчас"
  CHECKED="$(cat /etc/xray/sub-checked 2>/dev/null | esc)"
  echo "<small>Последняя проверка: ${CHECKED:-ещё не было}</small>"
  SI="$(gru-sub-update interval)"
  echo "<form method=get class=row>$(hidden)<select name=subint>"
  for v in "off:Автообновление выключено" "30m:Обновлять каждые 30 минут" "1h:Обновлять каждый час" "3h:Обновлять каждые 3 часа" \
    "6h:Обновлять каждые 6 часов" "12h:Обновлять каждые 12 часов" "24h:Обновлять раз в сутки"; do
    sel=""; [ "${v%%:*}" = "$SI" ] && sel=" selected"
    echo "<option value='${v%%:*}'$sel>${v#*:}</option>"
  done
  echo "</select><button>Сохранить</button></form></div>"
  echo "<div class=card><h2>Автопереключение при сбое</h2>"
  if [ "$(gru-watchdog state)" = on ]; then
    echo "<b class=ok>включено</b> — каждые 2 минуты роутер проверяет VPN. Если сервер не отвечает, а интернет есть, он обновляет подписку и при необходимости переходит на первый рабочий сервер."
    btn wd off "" "Выключить автопереключение"
  else
    echo "<b class=err>выключено</b> — при сбое сервера интернет пропадёт, пока не выберете другой сервер вручную."
    btn wd on " class=on" "Включить автопереключение"
  fi
  WLAST="$(cat /etc/xray/watchdog-last 2>/dev/null | esc)"
  echo "<small>Последнее срабатывание: ${WLAST:-не было}</small></div>"
  ;;
own)
  if [ -n "$form" ]; then
    [ "$form" = new ] && title="Новый сервер" || title="Изменить сервер"
    echo "<div class=card><h2>$title</h2><small>Поддерживаются VLESS + TCP + REALITY (xtls-rprx-vision).</small>"
    echo "<form method=get>$(hidden)<input type=hidden name=save value='$form'>"
    field "Название" n "$f_name" " maxlength=60"
    field "Адрес сервера" a "$f_addr" " required"
    field "Порт" p "$f_port" " required inputmode=numeric"
    field "UUID" u "$f_uuid" " required"
    field "SNI (serverName)" s "$f_sni" " required"
    field "Public key (pbk)" k "$f_pbk" " required"
    field "Short ID (sid)" i "$f_sid" ""
    [ "$f_net" = grpc ] && g_sel=" selected" || g_sel=""
    echo "<label>Транспорт<select name=t style='width:100%;margin-top:4px'><option value=tcp>TCP (xtls-rprx-vision)</option><option value=grpc$g_sel>gRPC</option></select></label>"
    field "gRPC serviceName (только для gRPC)" g "$f_svc" ""
    echo "<button class=on style='margin-top:12px'>Сохранить</button></form>"
    echo "<form method=get class=act>$(hidden)<button>Отмена</button></form></div>"
  fi
  echo "<div class=card><h2>Свои серверы</h2><small>Не из подписки: автообновление их не трогает. Выбираются на вкладке «Серверы».</small>"
  OWN="$(gru-custom list | esc)"
  [ -n "$OWN" ] || echo "<p><small>пока нет</small></p>"
  echo "$OWN" | while IFS="$TAB" read -r code name; do
    [ -n "$code" ] || continue
    echo "<div class=item><span>$name</span>"
    echo "<form method=get>$(hidden)<input type=hidden name=edit value='$code'><button>Изменить</button></form>"
    echo "<form method=get>$(hidden)<input type=hidden name=ndel value='$code'><button title='Удалить'>✕</button></form></div>"
  done
  echo "</div><div class=card><h2>Добавить</h2>"
  echo "<form method=get class=row>$(hidden)<input type=text name=link placeholder='vless://...' required><button>Добавить по ссылке</button></form>"
  echo "<form method=get class=row>$(hidden)<select name=copy>"
  echo "$NAMES" | while IFS="$TAB" read -r code name kind; do [ -n "$code" ] && echo "<option value='$code'>$name</option>"; done
  echo "</select><button>Скопировать и изменить</button></form>"
  btn newnode 1 "" "Ввести вручную"
  echo "</div>"
  ;;
routing)
  echo "<div class=card><h2>Гео-фильтр РФ</h2>"
  if [ "$MODE" = ru ]; then
    echo "<b class=ok>включён</b> — российские сайты и IP идут напрямую, остальное через VPN"
    btn routing global "" "Выключить гео-фильтр (всё через VPN)"
  else
    echo "<b class=err>выключен</b> — весь трафик идёт через VPN"
    btn routing ru " class=on" "Включить гео-фильтр"
  fi
  echo "</div>"
  echo "<div class=card><h2>Свои сайты</h2><small>Важнее гео-фильтра. Домен действует вместе с поддоменами; можно вставить ссылку, IP или подсеть.</small>"
  echo "<form method=get class=row>$(hidden)<input type=text name=add placeholder='example.com' required>"
  echo "<select name=to><option value=direct>Напрямую</option><option value=proxy>Через VPN</option></select><button>Добавить</button></form>"
  for list in direct proxy; do
    [ "$list" = direct ] && title="Всегда напрямую (мимо VPN)" || title="Всегда через VPN"
    items="$(echo "$SITES" | awk -F "$TAB" -v l="$list" '$1 == l {print $2}')"
    echo "<p><b>$title</b></p>"
    [ -n "$items" ] || echo "<small>пусто</small>"
    for s in $items; do
      echo "<form method=get class=item>$(hidden)<input type=hidden name=del value='$s'><span>$s</span><button title='Удалить'>✕</button></form>"
    done
  done
  echo "</div>"
  ;;
esac
echo "</div></div>$FOOTER</body></html>"
