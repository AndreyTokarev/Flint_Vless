# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The status tab of the panel: this body runs inside the case of panel.cgi.
  echo "<div class=card>"
  if [ -z "$NAMES" ]; then
    IP="$(curl -s -m 8 "$IP_LOOKUP" 2>/dev/null || echo n/a)"
    echo "<b class=err>$(T "Серверов пока нет" "No servers yet")</b> — $(T "устройства ходят в интернет напрямую" "devices go online directly")<br>$(T "IP провайдера" "Provider IP"): <b>$IP</b>$ADD_SERVERS"
  elif [ "$VPN" = off ]; then
    IP="$(curl -s -m 8 "$IP_LOOKUP" 2>/dev/null || echo n/a)"
    echo "<b class=err>$(T "VPN выключен" "VPN is off")</b> — $(T "устройства ходят в интернет напрямую" "devices go online directly")<br>$(T "IP провайдера" "Provider IP"): <b>$IP</b>"
    btn vpn on " class=on" "$(T "Включить VPN" "Turn VPN on")"
  else
    # The router's own traffic bypasses Xray, so a plain request shows the provider's IP; both run at once.
    # The address comes from $IP_LOOKUP (lib.sh, overridable in flint.env): a demo or a test points it at a
    # local answer, so a published screenshot never carries the real address of whoever ran the demo.
    #
    # Asking on every page load made the whole tab wait for the request to the VPN exit, and when the tunnel
    # was down that was the complete timeout (8 s of a blank page — it looked like a hung panel). The last
    # answer is therefore kept for two minutes: a working tunnel refreshes it as before, a broken one shows
    # the previous address (or n/a) at once instead of stalling. The timeout is 4 s for the same reason.
    CACHE=/tmp/flint-ip.cache
    now="$(date +%s)"
    c_ts=0; c_vpn=""; c_dir=""
    if [ -s "$CACHE" ]; then
      { read -r c_ts; read -r c_vpn; read -r c_dir; } < "$CACHE"
    fi
    case "$c_ts" in ''|*[!0-9]*) c_ts=0 ;; esac
    if [ $((now - c_ts)) -lt 120 ] && [ -n "$c_vpn" ]; then
      IP="$(printf '%s' "$c_vpn" | esc)"; DIRECT_IP="$(printf '%s' "$c_dir" | esc)"
    else
      curl -s -m 4 "$IP_LOOKUP" > /tmp/flint-ip.$$ 2>/dev/null &
      IP="$(curl -s -m 4 -x http://127.0.0.1:1087 "$IP_LOOKUP" 2>/dev/null)"
      wait
      DIRECT_IP="$(head -c 64 /tmp/flint-ip.$$)"; rm -f /tmp/flint-ip.$$
      [ -n "$IP" ] || IP=n/a
      [ -n "$DIRECT_IP" ] || DIRECT_IP=n/a
      printf '%s\n%s\n%s\n' "$now" "$IP" "$DIRECT_IP" > "$CACHE" 2>/dev/null
      IP="$(printf '%s' "$IP" | esc)"; DIRECT_IP="$(printf '%s' "$DIRECT_IP" | esc)"
    fi
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
  [ "$(flint-tg state)" = on ] && tgs="$ON" || tgs="$OFF"
  echo "<div class=stat><span>$(T "Прокси для Telegram" "Telegram proxy")</span><a href='?pass=$pass&amp;tab=telegram'>$tgs</a></div>"
  [ -n "$WLAST" ] && echo "<div class=stat><span>$(T "Последний сбой" "Last failure")</span><span>$WLAST</span></div>"
  echo "</div>"
