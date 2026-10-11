# Обслуживание

Резервные копии, восстановление, обновление прошивки, удаление и команды на роутере.

**Содержание**
- [Резервная копия](#резервная-копия)
- [Восстановление из бэкапа](#восстановление-из-бэкапа)
- [Обновление прошивки](#обновление-прошивки)
- [Удаление](#удаление)
- [Команды на роутере](#команды-на-роутере)
- [Обновление проекта](#обновление-проекта)

## Резервная копия

```powershell
.\backup.ps1              # конфиги роутера -> backup\<дата>\router-config.tar.gz, обновляет config\
.\backup.ps1 -WithBinary  # плюс backup\bin\xray (~27 МБ) — пригодится, если opkg недоступен
```
```sh
./backup.sh
./backup.sh --with-binary
```

Бэкап забирает с роутера настройки, свои серверы и сайты из панели, конфиги сети и Wi‑Fi. Пользовательские файлы из списка `kit/state-files` (`flint.env`, серверы, подписки, сайты, файлы блокировки рекламы) сохраняются одним архивом `backup\<дата>\state.tar.gz` и заодно кладутся в `config/` — их же потом заливает деплой. В том числе `flint.env` с PIN, если его меняли в панели.

Без компьютера настройки панели можно сохранить файлом: «Настройки → Скачать файл настроек» (или `flint-settings export` на роутере). Это не полный бэкап: в файл не входят `flint.env`, сеть и Wi‑Fi.

> [!WARNING]
> Папка `backup/` и файлы в `config/` содержат UUID подписки и пароли Wi‑Fi. В git они не попадают (`.gitignore`); храните их отдельно — в облаке или на флешке.

## Восстановление из бэкапа

```powershell
.\restore.ps1                                   # последний backup\<дата>
.\restore.ps1 -Backup backup\2026-10-03_1557    # конкретный
.\restore.ps1 -Full                             # плюс сеть, Wi-Fi, firewall, DHCP, SSH-ключи и перезагрузка
```
```sh
./restore.sh
./restore.sh backup/2026-10-03_1557
./restore.sh --full
```

По умолчанию `flint.env`, серверы, подписки, свои серверы и сайты, списки, правила и исключения блокировки рекламы из бэкапа кладутся в `config/`, затем запускается обычный деплой, а после него на роутер возвращаются все настройки панели из бэкапа: выбранный сервер, режимы VPN и маршрутизации, DNS, локальные имена, блокировка рекламы, прокси для Telegram (с прежним секретом, так что ссылки в Telegram остаются рабочими), интервалы и сторож. Подходит и для сброшенного роутера: сначала подключите его к интернету в админке GL. Текущие файлы `config/` перед заменой сохраняются в `backup/config-before-restore-<время>/`.

`-Full` / `--full` — только для **того же** роутера: вернёт его сеть, Wi‑Fi (SSID и пароли), firewall, DHCP-резервирования, cron и ключи SSH, затем перезагрузит. Скрипт спрашивает подтверждение (`-Yes` / `--yes` — без вопроса).

**Если `xray-core` из `opkg` не встал**, Xray берётся по порядку:

1. `backup/bin/xray` — сохраните заранее с рабочего роутера: `.\backup.ps1 -WithBinary`;
2. официальный релиз с GitHub (`XRAY_VERSION`).

## Обновление прошивки

Обновляйте прошивку с галочкой **«Сохранить настройки»** (*Keep Settings*) — тогда Flint VPN переживёт обновление: после перезагрузки VPN, панель, подписки, блокировка рекламы и прокси для Telegram работают как раньше, повторный деплой не нужен.

**Как это работает.** При обновлении прошивка стирает всё, что ставилось поверх неё, а с галочкой «Сохранить настройки» переносит в новую прошивку только `/etc/config/*` (сеть, Wi‑Fi, DHCP, правила firewall) и файлы из явных списков. `install.sh` кладёт такой список в `/lib/upgrade/keep.d/flint` — стандартное место OpenWrt, которое читает `sysupgrade` перед прошивкой. В списке:

| Что | Пути |
|---|---|
| Настройки, серверы, подписки, PIN | `/etc/xray` |
| Скрипты, панель, службы | `/usr/bin/flint-*`, `/usr/share/flint`, `/www/flint`, `/etc/init.d/xray`, `/etc/init.d/flint-*` |
| Автозапуск служб | ссылки `/etc/rc.d/*xray`, `/etc/rc.d/*flint-*` |
| Xray, базы geoip/geosite, прокси для Telegram | `/usr/bin/xray`, `/usr/share/xray`, `/usr/bin/tg-ws-proxy` |
| Перехват трафика, DNS, блокировка рекламы | `/etc/firewall.user`, `/etc/dnsmasq.d/flint-*.conf`, `/etc/dnscrypt-proxy2/flint-doh.toml`, `/etc/flint-adguard` |
| Задачи cron (подписки, сторож, базы geo) | `/etc/crontabs/root` |

Сам список тоже в нём, поэтому сохранится и при следующем обновлении. Вместе с Xray и базами geo в архив обновления уходит около 60 МБ — для этого роутера это нормально.

**Проверить заранее**, ничего не меняя: `sysupgrade -l` на роутере выводит список файлов, которые сохранятся. В нём должны быть `/etc/xray/…`, `/usr/bin/flint-…`, `/www/flint/…`. Деплой проверяет это сам и в конце пишет `Firmware upgrade with "Keep settings": Flint stays (N files)`.

**Когда всё же нужен деплой или восстановление:**

- обновили **без** «Сохранить настройки» или сбросили роутер — `.\restore.ps1 -Full` (или обычный деплой и настройка заново);
- новая прошивка на другой крупной версии OpenWrt (например, 23.05 → 24.10) и после обновления что-то не работает — повторите деплой: он перезапишет файлы комплекта, а настройки в `/etc/xray` останутся;
- пакеты, которые `install.sh` ставил через `opkg` (`dnscrypt-proxy2`, `iptables-nft` и т. п., если их не было в прошивке), обновление удаляет — их вернёт повторный деплой. В прошивке GL 4.x они уже есть, сам Xray сохраняется как файл.

Перед обновлением прошивки всё равно сделайте бэкап (`.\backup.ps1`) — на случай, если что-то пойдёт не так.

## Удаление

```powershell
.\uninstall.ps1               # бэкап, затем удаление
.\uninstall.ps1 -KeepXray     # оставить пакет xray-core
.\uninstall.ps1 -NoBackup     # без бэкапа
```
```sh
./uninstall.sh
./uninstall.sh --keep-xray
./uninstall.sh --no-backup
```

Скрипт спрашивает подтверждение (`-Yes` / `--yes` — без вопроса), делает бэкап в `backup/<дата>` и удаляет с роутера всё, что поставил Flint VPN: панель, службы, скрипты `flint-*`, настройки в `/etc/xray`, свой AdGuard Home, прокси для Telegram, правила firewall и задачи cron, пакет `xray-core` и базы geoip/geosite. Настройки DNS возвращаются к заводским: dnsmasq снова берёт DNS у основного роутера. Прошивка и её пакеты (`dnscrypt-proxy2`, `curl`, AdGuard Home из прошивки и т. д.), сеть, Wi‑Fi и пароль root не меняются.

После удаления устройства ходят в интернет напрямую. Из сети основного роутера Flint больше недоступен (это делали правила Flint VPN): подключайтесь к нему по Wi‑Fi или кабелем. Вернуть всё как было — `.\restore.ps1` / `./restore.sh` из сделанного бэкапа.

Удалить вручную, без компьютера с проектом: залейте на роутер `kit/uninstall.sh` и запустите `sh uninstall.sh` (или `sh uninstall.sh --keep-xray`).

## Команды на роутере

```sh
flint-node list                  # текущий сервер и коды
flint-node nl                    # переключиться на сервер nl (с проверкой IP выхода)
flint-node routing ru            # гео-фильтр: РФ напрямую (global — всё через VPN)
flint-node vpn off               # клиенты ходят в интернет напрямую (on — снова через VPN)
flint-node site add direct gosuslugi.ru   # свой сайт: direct — мимо VPN, proxy — через VPN
flint-node site list
flint-node site del gosuslugi.ru
flint-node direct add aa:bb:cc:dd:ee:ff TV   # устройство без VPN; список: flint-node direct, убрать: direct del <MAC>
flint-node probe                 # время соединения до каждого сервера: код, мс (узлы без ответа — «-»)
flint-node fastest               # самый быстрый сервер из ответивших
flint-node probe-mode fastest    # при сбое переключаться на самый быстрый (first — на первый в списке)
flint-node opts                  # отпечаток TLS и объединение соединений: что сейчас включено
flint-node fingerprint chrome    # каким браузером представляться серверу: chrome, firefox, safari, edge, random
flint-node mux on                # объединение соединений (по умолчанию выключено; выключится само, если туннель не пойдёт)
flint-node mux off               # выключить объединение соединений
flint-custom link 'vless://...'  # добавить свой сервер по ссылке
flint-custom list
flint-custom del my1
flint-sub-update                 # обновить все подписки
flint-sub-update list            # подписки: id, название, сайт, последнее обновление, срок и трафик
flint-sub-update add 'https://...' "Название"   # добавить подписку
flint-sub-update set s2 'https://...'          # новая ссылка (или название) подписки s2
flint-sub-update del s2          # удалить подписку и её серверы
flint-sub-update interval 1h     # автообновление: off, 30m, 1h, 3h, 6h, 12h, 24h
flint-watchdog off               # выключить автопереключение (on — включить)
cat /etc/xray/watchdog-last    # последнее срабатывание
flint-geo-update                 # обновить geoip/geosite вручную
flint-adblock on                 # блокировка рекламы (off — выключить)
flint-adblock list               # списки: ссылка, название, правил, когда обновлён
flint-adblock list add https://example.com/list.txt "Название"
flint-adblock rule add block ads.example.com   # allow — исключение
flint-adblock blocked                          # недавно заблокированные домены и устройства
flint-adblock exclude add aa:bb:cc:dd:ee:ff    # устройство без блокировки
flint-adblock refresh            # обновить списки сейчас
flint-adblock interval 24        # автообновление: off, 1, 12, 24, 72, 168 часов
flint-settings export > /tmp/s.txt   # экспорт настроек панели (без flint.env)
flint-settings import /tmp/s.txt     # импорт: заменяет настройки панели и сразу применяет
flint-dns                            # текущий DNS: режим и сервер
flint-dns doh quad9                  # DoH; свой: flint-dns doh https://dns.example.com/dns-query
flint-dns dnscrypt quad9             # DNSCrypt; свой: flint-dns dnscrypt sdns://...
flint-dns udp provider               # обычный DNS: пресет, provider или IP через пробел
flint-dns mode doh                   # переключить режим: doh, dnscrypt, udp
flint-dns hosts                      # локальные имена; добавить: flint-dns hosts add nas01 192.168.0.145, удалить: hosts del nas01
flint-tg on                          # прокси для Telegram (off — выключить)
flint-tg link                        # ссылка tg://proxy для сети Flint (upstream — сеть основного роутера, remote — интернет)
flint-tg route vpn                   # путь к Telegram через VPN (direct — напрямую)
flint-tg check                       # проверить прокси до ответа серверов Telegram
flint-tg secret <hex>                # свой секрет (new — новый случайный)
flint-tg dc 2:149.154.167.220        # адреса дата-центров (default — встроенные)
flint-tg log verbose                 # журнал прокси (on, off); flint-tg logs — последние строки
flint-tg latest                      # есть ли новая версия прокси на GitHub
logread -e xray                # логи Xray
```

## Обновление проекта

Код проекта обновляется обычным `git pull` и повторным деплоем:

```powershell
git pull
.\deploy.ps1
```

Версии нумеруются по [SemVer](https://semver.org/lang/ru/): `1.2.3` — мажорная (несовместимые изменения), минорная (новые возможности), патч (исправления). Номер лежит в `kit/VERSION`, у каждой версии есть git-тег `vX.Y.Z`, что изменилось — в [CHANGELOG.md](../CHANGELOG.md).

---

**Дальше:** [Установка](install.md) · [Веб-панель](panel.md) · [Серверы и подписки](servers.md) · [DNS и блокировка рекламы](dns-adblock.md) · [Прокси для Telegram](telegram-proxy.md) · [Решение проблем](troubleshooting.md) · [Как это устроено](internals.md)
