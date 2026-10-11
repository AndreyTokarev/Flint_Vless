# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The servers tab of the panel: this body runs inside the case of panel.cgi.
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
  echo "<small>$(T "Последнее срабатывание" "Last triggered"): ${WLAST:-$NEVER}</small>"
  # Which server to switch to: the first in the list or the one that answers soonest.
  if [ "$(flint-node probe-mode)" = fastest ]; then
    echo "<p>$(T "Замена при сбое" "Replacement on failure"): <b class=ok>$(T "самый быстрый" "the fastest")</b> — $(
      T "роутер проверяет задержку до серверов и переходит на тот, что отвечает быстрее всех." \
        "the router measures the time to each server and switches to the one that answers soonest.")</p>"
    btn probemode first "" "$(T "Переключаться на первый из списка" "Switch to the first in the list")"
  else
    echo "<p>$(T "Замена при сбое" "Replacement on failure"): <b>$(T "первый в списке" "the first in the list")</b></p>"
    btn probemode fastest " class=on" "$(T "Переключаться на самый быстрый" "Switch to the fastest")"
  fi
  echo "</div>"
