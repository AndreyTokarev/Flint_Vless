# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The status tab of the panel: this body runs inside the case of panel.cgi.
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
  [ "$(flint-tg state)" = on ] && tgs="$ON" || tgs="$OFF"
  echo "<div class=stat><span>$(T "Прокси для Telegram" "Telegram proxy")</span><a href='?pass=$pass&amp;tab=telegram'>$tgs</a></div>"
  [ -n "$WLAST" ] && echo "<div class=stat><span>$(T "Последний сбой" "Last failure")</span><span>$WLAST</span></div>"
  echo "</div>"
