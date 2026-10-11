# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The routing tab of the panel: this body runs inside the case of panel.cgi.
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
  echo "<br><small>$(T "Telegram на таких устройствах может работать через прокси роутера — вкладка «Telegram»." "Telegram on these devices can work through the router's proxy — the Telegram tab.")</small>"
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
