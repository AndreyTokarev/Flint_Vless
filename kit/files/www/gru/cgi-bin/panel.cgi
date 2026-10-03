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
tab="$(get tab)"
case "$tab" in status|servers|own|routing) ;; *) tab=status ;; esac
. /etc/xray/gru.env
TITLE="$(echo "${UI_TITLE:-Flint VPN}" | esc)"
cat <<HTML
<!DOCTYPE html><html lang=ru><head>
<meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>$TITLE</title>
<style>
body{margin:0;font-family:system-ui,sans-serif;background:#111827;color:#e5e7eb}
main{max-width:640px;margin:auto;padding:20px}
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
.login{max-width:340px;margin-left:auto;margin-right:auto;padding:28px 24px;text-align:center}
main:has(.login) h1{text-align:center;margin-top:40px}
.login{margin-top:16px}
.lock{font-size:40px}
.login-hint{color:#9ca3af;margin:8px 0 18px}
.login-err{margin:-6px 0 14px}
.login input{width:100%;box-sizing:border-box;padding:14px;font-size:20px;text-align:center;letter-spacing:4px;margin-bottom:12px}
.login input::placeholder{letter-spacing:normal}
.login input:focus{outline:none;border-color:#34d399}
.layout{display:flex;gap:24px;max-width:960px;margin:auto;padding:20px}
nav{flex:0 0 200px;position:sticky;top:20px;align-self:flex-start}
nav .brand{font-size:22px;font-weight:700;margin:4px 12px 16px}
nav a{display:block;padding:10px 12px;margin-bottom:4px;border-radius:10px;color:#e5e7eb;text-decoration:none}
nav a:hover{background:#1f2937}
nav a.cur{background:#1f2937;color:#34d399;font-weight:600}
nav a.logout{color:#9ca3af;margin-top:16px}
.content{flex:1;min-width:0}
.content>.card:first-child{margin-top:0}
.stat{display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-bottom:1px solid #374151}
.stat:last-of-type{border-bottom:0}
.stat a{color:#93c5fd}
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
<main><h1>$TITLE</h1><div class="card login"><div class=lock>🔒</div>
<p class=login-hint>Введите PIN, чтобы управлять VPN</p>$err
<form method=get><input type=password name=pass placeholder=PIN autocomplete=current-password autofocus required>
<button class=on>Войти</button></form></div></main></body></html>
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
  f_sni="$(param s)"; f_pbk="$(param k)"; f_sid="$(param i)"
  # On a validation error keep the form open with what was typed.
  msg="$(gru-custom set "$save" "$f_name" "$f_addr" "$f_port" "$f_uuid" "$f_sni" "$f_pbk" "$f_sid" 2>&1)" || form="$save"
elif [ -n "$edit" ] || [ -n "$copy" ]; then
  TAB="$(printf '\t')"
  IFS="$TAB" read -r f_code f_name f_addr f_port f_uuid f_sni f_pbk f_sid <<EOF
$(gru-custom show "${edit:-$copy}")
EOF
  [ "$f_sid" = - ] && f_sid=""
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

echo "<div class=layout><nav><div class=brand>$TITLE</div>"
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
  CHECKED="$(cat /etc/xray/sub-checked 2>/dev/null)"
  echo "<div class=card>"
  echo "<div class=stat><span>Гео-фильтр РФ</span><span>$geo</span></div>"
  echo "<div class=stat><span>Свои сайты</span><a href='?pass=$pass&amp;tab=routing'>$ndirect напрямую, $nproxy через VPN</a></div>"
  echo "<div class=stat><span>Серверов</span><a href='?pass=$pass&amp;tab=servers'>$total, из них своих $own</a></div>"
  echo "<div class=stat><span>Проверка подписки</span><span>${CHECKED:-ещё не было}</span></div>"
  echo "</div>"
  ;;
servers)
  echo "<div class=card><h2>Серверы</h2><div class=grid>"
  echo "$NAMES" | while IFS="$TAB" read -r code name; do
    [ -n "$code" ] || continue
    on=""; [ "$code" = "$CUR" ] && on=" on"
    echo "<form method=get>$(hidden)<input type=hidden name=node value='$code'><button class='$on'>$name</button></form>"
  done
  echo "</div>"
  btn sub 1 "" "Обновить список серверов по подписке"
  CHECKED="$(cat /etc/xray/sub-checked 2>/dev/null)"
  echo "<small>Автообновление каждый день в 5:15. Последняя проверка: ${CHECKED:-ещё не было}</small></div>"
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
  echo "$NAMES" | while IFS="$TAB" read -r code name; do [ -n "$code" ] && echo "<option value='$code'>$name</option>"; done
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
echo "</div></div></body></html>"
