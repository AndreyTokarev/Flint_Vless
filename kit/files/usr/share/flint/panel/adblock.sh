# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The adblock tab of the panel: this body runs inside the case of panel.cgi.
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
