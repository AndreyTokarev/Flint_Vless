# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The telegram tab of the panel: this body runs inside the case of panel.cgi.
  TGPORT="$(flint-tg port)"; TGROUTE="$(flint-tg route)"; TGMASK="$(flint-tg mask | esc)"
  # tg_link <lan|upstream|remote> <title>: a button that adds the proxy to Telegram, and its fields for manual entry.
  tg_link() {
    l="$(flint-tg link "$1" 2>/dev/null)" || return 0
    q="${l#tg://proxy?}"
    srv="$(echo "$q" | sed 's/^server=\([^&]*\).*/\1/' | esc)"; sec="$(echo "$q" | sed 's/.*secret=//' | esc)"
    q="$(echo "$q" | esc)"
    echo "<p><b>$2</b></p><div class=cta><a class='btn on' href='tg://proxy?$q'>✈️ $(T "Добавить в Telegram" "Add to Telegram")</a><a class=btn href='https://t.me/proxy?$q'>t.me</a></div>"
    echo "<div class=stat><span>$(T "Сервер" "Server")</span><code>$srv</code></div><div class=stat><span>$(T "Порт" "Port")</span><code>$TGPORT</code></div>"
    echo "<div class=stat><span>$(T "Секрет" "Secret")</span><code>$sec</code></div>"
  }
  echo "<div class=card><h2>$(T "Прокси для Telegram" "Telegram proxy")</h2>"
  if [ "$(flint-tg state)" = on ]; then
    if pidof tg-ws-proxy >/dev/null; then
      echo "$ON — $(T "приложения Telegram в сети могут работать через роутер без VPN. Роутер ходит к Telegram через его веб-серверы, как Telegram Web." \
        "Telegram apps on the network can work through the router without a VPN. The router reaches Telegram through its web servers, like Telegram Web.")"
    else
      echo "<b class=err>$(T "включён, но не запущен" "on, but not running")</b> — $(T "выключите и включите прокси снова." "turn the proxy off and on again.")"
    fi
    echo "<br><small>$(T "Откройте кнопку на устройстве с Telegram — он предложит подключить прокси. Или вручную: Настройки → Данные и память → Прокси → Добавить прокси → MTProto." \
      "Tap the button on a device with Telegram and it offers to connect the proxy. Or by hand: Settings → Data and Storage → Proxy → Add Proxy → MTProto.")</small>"
    tg_link lan "$(T "В сети Flint" "On the Flint network")"
    [ -n "$UPSTREAM_NET" ] && tg_link upstream "$(T "В сети основного роутера" "On the main router's network")"
    [ "$(flint-tg remote)" = on ] && tg_link remote "$(T "Из интернета" "From the internet")"
    btn tgcheck 1 "" "$(T "Проверить прокси" "Check the proxy")"
    btn tg off " class=off" "$(T "Выключить прокси" "Turn the proxy off")"
  else
    echo "$OFF — $(T "прокси на роутере для приложений Telegram. Он работает без VPN: на устройствах без VPN, при выключенном VPN и не тратя трафик подписки. Подключается в самом Telegram, ссылки появятся здесь." \
      "a proxy on the router for Telegram apps. It works without the VPN: on devices without VPN, while the VPN is off, and without spending subscription traffic. It is set up in Telegram itself; the links appear here.")"
    btn tg on " class=on" "$(T "Включить прокси" "Turn the proxy on")"
  fi
  echo "</div>"
  echo "<div class=card><h2>$(T "Путь к Telegram" "Route to Telegram")</h2><small>$(T "Напрямую — мимо VPN: работает при выключенном VPN и не тратит трафик подписки. Через VPN — если провайдер мешает и веб-серверам Telegram; пока VPN выключен, прокси всё равно ходит напрямую." \
    "Directly — bypassing the VPN: works while the VPN is off and spends no subscription traffic. Via VPN — when the provider blocks Telegram's web servers too; while the VPN is off, the proxy still goes directly.")</small>"
  echo "<form method=get class=row>$(hidden)<select name=tgroute>"
  for v in "direct:$(T "Напрямую, мимо VPN" "Directly, bypassing the VPN")" "vpn:$(T "Через VPN" "Via VPN")"; do
    sel=""; [ "${v%%:*}" = "$TGROUTE" ] && sel=" selected"
    echo "<option value='${v%%:*}'$sel>${v#*:}</option>"
  done
  echo "</select><button>$(T "Сохранить" "Save")</button></form>"
  if [ "$TGROUTE" = vpn ] && { [ "$VPN" = off ] || [ -z "$NAMES" ]; }; then
    echo "<p><small class=err>$(T "Сейчас VPN не работает — прокси ходит напрямую." "The VPN is not working now — the proxy goes directly.")</small></p>"
  fi
  TGDC="$(flint-tg dc | sed 's/,/, /g' | esc)"
  echo "<p>$(T "Адреса дата-центров" "Data center addresses"): <b>${TGDC:-$(T "по умолчанию" "default")}</b><br><small>$(T "Номер дата-центра и IP, к которому прокси подключается напрямую; через запятую. Пусто — встроенные адреса прокси (DC2 и DC4)." \
    "Data center number and the IP the proxy connects to directly, comma-separated. Empty: the proxy's built-in addresses (DC2 and DC4).")</small></p>"
  echo "<form method=get class=row>$(hidden)<input type=text name=tgdc value='$TGDC' placeholder='2:149.154.167.220, 4:149.154.167.220' required><button>$(T "Сохранить" "Save")</button></form>"
  [ -n "$TGDC" ] && btn tgdc default "" "$(T "Адреса по умолчанию" "Default addresses")"
  echo "</div>"
  echo "<div class=card><h2>Cloudflare</h2><small>$(T "Резервный путь, если серверы Telegram недоступны напрямую: прокси идёт к ним через Cloudflare. Порядок: свои домены, общий список, затем Worker." \
    "A fallback when Telegram's servers are not reachable directly: the proxy goes to them through Cloudflare. Order: own domains, the shared list, then the Worker.")</small>"
  if [ "$(flint-tg cf)" = on ]; then
    echo "<p>$(T "Общий список доменов" "Shared domain list"): $ON<br><small>$(T "Домены проекта tg-ws-proxy, свой Cloudflare не нужен." "The tg-ws-proxy project's domains, no Cloudflare account needed.")</small></p>"
    btn tgcf off "" "$(T "Выключить общий список" "Turn the shared list off")"
  else
    echo "<p>$(T "Общий список доменов" "Shared domain list"): $OFF</p>"
    btn tgcf on " class=on" "$(T "Включить общий список" "Turn the shared list on")"
  fi
  TGCFD="$(flint-tg cfdomain | sed 's/,/, /g' | esc)"; TGWK="$(flint-tg worker | sed 's/,/, /g' | esc)"
  echo "<p>$(T "Свои домены (CF-прокси)" "Own domains (CF proxy)")<br><small>$(T "Домены на вашем Cloudflare, настроенные по инструкции tg-ws-proxy; через запятую." "Domains on your Cloudflare set up per the tg-ws-proxy guide, comma-separated.")</small></p>"
  echo "<form method=get class=row>$(hidden)<input type=text name=tgcfd value='$TGCFD' placeholder='proxy.example.com' required><button>$(T "Сохранить" "Save")</button></form>"
  [ -n "$TGCFD" ] && btn tgcfd off "" "$(T "Убрать свои домены" "Remove own domains")"
  echo "<p>Cloudflare Worker<br><small>$(T "Домены вашего Worker (*.workers.dev) — последний резерв, TCP-туннель до Telegram; через запятую." "Your Worker domains (*.workers.dev): the last fallback, a TCP tunnel to Telegram; comma-separated.")</small></p>"
  echo "<form method=get class=row>$(hidden)<input type=text name=tgworker value='$TGWK' placeholder='name.user.workers.dev' required><button>$(T "Сохранить" "Save")</button></form>"
  [ -n "$TGWK" ] && btn tgworker off "" "$(T "Убрать Worker" "Remove the Worker")"
  if [ "$(flint-tg cftls)" = on ]; then
    echo "<p>$(T "TLS к Cloudflare" "TLS to Cloudflare"): $ON</p>"
    btn tgcftls off "" "$(T "Выключить TLS (ws:// на порт 80)" "Turn TLS off (ws:// on port 80)")"
  else
    echo "<p>$(T "TLS к Cloudflare" "TLS to Cloudflare"): $OFF<br><small>$(T "Соединения с Cloudflare идут без шифрования на порт 80 — только если провайдер режет TLS к Cloudflare. Переписка всё равно зашифрована Telegram." \
      "Connections to Cloudflare go unencrypted to port 80 — only for providers that cut TLS to Cloudflare. Messages stay encrypted by Telegram.")</small></p>"
    btn tgcftls on " class=on" "$(T "Включить TLS" "Turn TLS on")"
  fi
  echo "</div>"
  echo "<div class=card><h2>$(T "Доступ из интернета" "Access from the internet")</h2>"
  if [ "$(flint-tg remote)" = on ]; then
    UPIP="$(flint-tg link upstream 2>/dev/null | sed -n 's/.*server=\([^&]*\).*/\1/p' | esc)"
    echo "$ON — $(T "Telegram на телефоне работает через домашний роутер и вне дома." "Telegram on a phone works through the home router away from home too.")"
    echo "<br><small>$(T "На основном роутере пробросьте TCP-порт $TGPORT на ${UPIP:-Flint} — адрес Flint в его сети. Ссылка «Из интернета» на первой карточке использует внешний IP провайдера; если он «серый» (CGNAT), доступ извне не заработает, а если меняется — укажите свой домен (DDNS). Для мобильного интернета включите маскировку ниже." \
      "On the main router forward TCP port $TGPORT to ${UPIP:-Flint}, Flint's address on its network. The \"From the internet\" link on the first card uses the provider's public IP; behind CGNAT access from outside will not work, and if the IP changes, set your own domain (DDNS). For mobile internet turn on masking below.")</small>"
    echo "<form method=get class=row>$(hidden)<input type=text name=tgaddr value='$(flint-tg addr | esc)' placeholder='$(T "IP провайдера (авто) или свой домен" "Provider IP (auto) or own domain")' required>"
    echo "<button>$(T "Сохранить адрес" "Save the address")</button></form>"
    [ -n "$(flint-tg addr)" ] && btn tgaddr auto "" "$(T "Адрес — IP провайдера" "Address — the provider IP")"
    btn tgremote off " class=off" "$(T "Закрыть доступ из интернета" "Close access from the internet")"
  else
    echo "$OFF — $(T "прокси доступен только в сети Flint и в сети основного роутера." "the proxy is reachable only on the Flint network and the main router's network.")"
    echo "<br><small>$(T "Включите, чтобы Telegram на телефоне работал через домашний роутер и вне дома. Понадобится проброс порта на основном роутере и «белый» IP у провайдера." \
      "Turn on to use the home router for Telegram on a phone away from home. Needs a port forward on the main router and a public IP from the provider.")</small>"
    btn tgremote on "" "$(T "Открыть доступ из интернета" "Open access from the internet")"
  fi
  echo "</div>"
  echo "<div class=card><h2>$(T "Настройки прокси" "Proxy settings")</h2>"
  echo "<form method=get class=row>$(hidden)<input type=text name=tgport value='$TGPORT' inputmode=numeric required><button>$(T "Сменить порт" "Change the port")</button></form>"
  echo "<p><small>$(T "Маскировка (FakeTLS): соединение с прокси выглядит как HTTPS к указанному сайту. Нужна, когда прокси открыт из интернета. После смены порта, маскировки или секрета добавьте прокси в Telegram заново." \
    "Masking (FakeTLS): connections to the proxy look like HTTPS to the given site. Needed when the proxy is open to the internet. After changing the port, masking or secret, add the proxy to Telegram again.")</small></p>"
  echo "<form method=get class=row>$(hidden)<input type=text name=tgmask value='$TGMASK' placeholder='www.google.com' required><button>$(T "Маскировать" "Mask")</button></form>"
  [ -n "$TGMASK" ] && btn tgmask off "" "$(T "Выключить маскировку" "Turn masking off")"
  echo "<p><small>$(T "Свой секрет: 32 шестнадцатеричных символа, например из другого прокси, чтобы не менять его в Telegram (подойдёт и секрет с dd или ee в начале)." \
    "Own secret: 32 hex characters, e.g. from another proxy so Telegram keeps it (a secret with dd or ee in front works too).")</small></p>"
  echo "<form method=get class=row>$(hidden)<input type=text name=tgsecretset placeholder='$(T "32 hex-символа" "32 hex characters")' autocomplete=off required><button>$(T "Сохранить секрет" "Save the secret")</button></form>"
  ASK="$(T "Сделать новый секрет? Старые ссылки перестанут работать." "Make a new secret? The old links stop working.")"
  echo "<form method=get class=act onsubmit=\"return confirm('$ASK')\">$(hidden)<input type=hidden name=tgsecret value=1><button>$(T "Новый секрет" "New secret")</button></form></div>"
  TGLOG="$(flint-tg log)"
  echo "<div class=card><h2>$(T "Журнал и обслуживание" "Log and maintenance")</h2>"
  echo "<p>$(T "Пул WebSocket-соединений" "WebSocket pool"): <b>$(flint-tg pool)</b><br><small>$(T "Сколько соединений с каждым дата-центром держать открытыми заранее (по умолчанию 4). Больше — быстрее открываются чаты и загрузки, но больше соединений." \
    "How many connections to each data center to keep open in advance (4 by default). More: chats and downloads open faster, at the cost of more connections.")</small></p>"
  echo "<form method=get class=row>$(hidden)<input type=text name=tgpool value='$(flint-tg pool)' inputmode=numeric required><button>$(T "Сохранить" "Save")</button></form>"
  echo "<p>$(T "Журнал прокси" "Proxy log")<br><small>$(T "Пишется в системный журнал роутера (в памяти, флеш не изнашивается): logread -e tg-ws-proxy. Подробный — для поиска проблем." \
    "Goes to the router's system log (in RAM, no flash wear): logread -e tg-ws-proxy. Verbose is for troubleshooting.")</small></p>"
  echo "<form method=get class=row>$(hidden)<select name=tglog>"
  for v in "off:$(T "Выключен" "Off")" "on:$(T "Включён" "On")" "verbose:$(T "Подробный" "Verbose")"; do
    sel=""; [ "${v%%:*}" = "$TGLOG" ] && sel=" selected"
    echo "<option value='${v%%:*}'$sel>${v#*:}</option>"
  done
  echo "</select><button>$(T "Сохранить" "Save")</button></form>"
  if [ "$TGLOG" != off ]; then
    LOGS="$(flint-tg logs 30 | sed -E 's/^[A-Z][a-z]{2} [A-Z][a-z]{2} +[0-9]+ ([0-9:]+) [0-9]{4} [a-z]+\.[a-z]+ [^:]+: /\1 /' | esc)"
    echo "<p><small>$(T "Последние строки" "Last lines"):</small></p><pre class=log>${LOGS:-$(T "пока пусто" "empty so far")}</pre>"
  fi
  echo "<p>$(T "Версия прокси" "Proxy version"): <b>$(flint-tg version | esc)</b></p>"
  btn tgupdate 1 "" "$(T "Проверить обновления" "Check for updates")"
  echo "</div>"
