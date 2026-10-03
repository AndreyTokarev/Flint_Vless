#!/bin/sh
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
echo "Content-Type: text/html; charset=utf-8"
echo ""
qs="$QUERY_STRING"
get() { echo "$qs" | tr '&' '\n' | sed -n "s/^$1=//p" | head -n1 | tr -cd 'A-Za-z0-9_-'; }
pass="$(get pass)"; node="$(get node)"; routing="$(get routing)"
. /etc/xray/gru.env
CUR="$(cat /etc/xray/current-node 2>/dev/null || echo unknown)"
cat <<HTML
<!DOCTYPE html><html lang=ru><head>
<meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>Gru VPN</title>
<style>
body{margin:0;font-family:system-ui,sans-serif;background:#111827;color:#e5e7eb}
main{max-width:640px;margin:auto;padding:20px}
.card{background:#1f2937;border-radius:12px;padding:14px;margin:12px 0}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:8px}
button{width:100%;padding:12px;border-radius:10px;border:1px solid #374151;background:#111827;color:#e5e7eb;font-size:15px}
.grid button{text-align:left}
button.on{border-color:#34d399;background:#064e3b}
input{padding:10px;border-radius:8px;border:1px solid #374151;background:#0b1220;color:#e5e7eb}
.ok{color:#34d399}.err{color:#f87171}
</style></head><body><main><h1>Gru VPN</h1>
HTML
if [ -z "$UI_PIN" ] || [ "$pass" != "$UI_PIN" ]; then
  echo "<div class=card><form method=get>PIN: <input type=password name=pass> <button>Войти</button></form></div></main></body></html>"
  exit 0
fi
msg=""
if [ -n "$node" ]; then
  msg="$(gru-node "$node" 2>&1)"
  CUR="$(cat /etc/xray/current-node 2>/dev/null || echo "$node")"
elif [ "$routing" = ru ] || [ "$routing" = global ]; then
  msg="$(gru-node routing "$routing" 2>&1)"
fi
MODE="$(gru-node routing)"
TAB="$(printf '\t')"
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/'/\&#39;/g"; }
NAMES="$(gru-node names | esc)"
CUR_NAME="$(echo "$NAMES" | awk -F "$TAB" -v c="$CUR" '$1 == c {print $2}')"
IP="$(curl -s -m 8 -x http://127.0.0.1:1087 https://ifconfig.me 2>/dev/null || echo n/a)"
if [ "$MODE" = ru ]; then MODE_TXT="РФ-сайты напрямую"; NEXT=global; NEXT_TXT="Всё через VPN"
else MODE_TXT="Всё через VPN"; NEXT=ru; NEXT_TXT="РФ-сайты напрямую"; fi
echo "<div class=card>Сервер: <b class=ok>${CUR_NAME:-$CUR}</b><br>IP: <b>$IP</b><br>Маршрутизация: <b>$MODE_TXT</b>"
echo "<form method=get style='margin-top:10px'><input type=hidden name=pass value='$pass'><input type=hidden name=routing value='$NEXT'><button>Переключить: $NEXT_TXT</button></form></div>"
[ -n "$msg" ] && echo "<div class=card><pre class=ok>$(echo "$msg" | esc)</pre></div>"
echo "<div class=grid>"
echo "$NAMES" | while IFS="$TAB" read -r code name; do
  [ -n "$code" ] || continue
  on=""; [ "$code" = "$CUR" ] && on=" on"
  echo "<form method=get><input type=hidden name=pass value='$pass'><input type=hidden name=node value='$code'><button class='$on'>$name</button></form>"
done
echo "</div></main></body></html>"
