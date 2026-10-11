# SPDX-FileCopyrightText: 2026 Andrey Tokarev
# SPDX-License-Identifier: LicenseRef-Flint-VPN-Noncommercial-1.0
# The settings tab of the panel: this body runs inside the case of panel.cgi.
  echo "<div class=card><h2>$(T "Сменить PIN" "Change PIN")</h2><small>$(T "Только буквы и цифры. PIN хранится в flint.env на роутере; при деплое с компьютера снова подставится PIN из config/flint.env." \
    "Letters and digits only. The PIN is stored in flint.env on the router; a deploy from the computer will put back the PIN from config/flint.env.")</small>"
  echo "<form method=get class=row>$(hidden)<input type=hidden name=pin value=1>"
  echo "<input type=password name=pinold placeholder='$(T "текущий PIN" "current PIN")' autocomplete=current-password required>"
  echo "<input type=password name=pinnew placeholder='$(T "новый PIN" "new PIN")' autocomplete=new-password required>"
  echo "<input type=password name=pinok placeholder='$(T "ещё раз новый PIN" "new PIN again")' autocomplete=new-password required>"
  echo "<button>$(T "Сменить PIN" "Change PIN")</button></form></div>"
  echo "<div class=card><h2>$(T "Экспорт настроек" "Export settings")</h2><small>$(T "Подписки, свои и ручные серверы, сайты, устройства без VPN, блокировка рекламы, DNS-сервер, локальные имена, прокси для Telegram, режимы и интервалы. PIN и сеть (flint.env) в файл не входят, поэтому его можно загрузить и на другой Flint. В файле ссылки подписок, данные серверов и секрет прокси — храните его как пароль." \
    "Subscriptions, own and manual servers, sites, devices without VPN, ad blocking, DNS server, local names, Telegram proxy, modes and intervals. The PIN and network (flint.env) are not included, so the file also fits another Flint. It holds subscription links, server data and the proxy secret — keep it like a password.")</small>"
  echo "<div class=cta><a class='btn on' href='?pass=$pass&amp;export=1'>⬇️ $(T "Скачать файл настроек" "Download the settings file")</a></div></div>"
  ASK="$(T "Заменить текущие настройки настройками из файла?" "Replace the current settings with the ones from the file?")"
  echo "<div class=card><h2>$(T "Импорт настроек" "Import settings")</h2><small>$(T "Все настройки из списка выше заменятся настройками из файла и сразу применятся. Прежние сохраняются на роутере в /tmp/flint-settings-prev.txt до перезагрузки." \
    "All the settings listed above are replaced with the ones from the file and applied at once. The previous ones stay on the router in /tmp/flint-settings-prev.txt until a reboot.")</small>"
  echo "<form method=post enctype=multipart/form-data action='?pass=$pass&amp;tab=settings&amp;import=1' class=row onsubmit=\"return confirm('$ASK')\">"
  echo "<input type=file name=file accept='.txt,text/plain' required><button>$(T "Загрузить настройки" "Upload settings")</button></form></div>"
