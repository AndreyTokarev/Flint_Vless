# Как это устроено

Технические подробности: что происходит с трафиком, из чего состоит проект, где что лежит и что с безопасностью.

**Содержание**
- [Схема](#схема)
- [Что происходит с трафиком](#что-происходит-с-трафиком)
- [Структура проекта](#структура-проекта)
- [Где что лежит на роутере](#где-что-лежит-на-роутере)
- [Службы](#службы)
- [Версии и обновление](#версии-и-обновление)
- [Безопасность](#безопасность)
- [Участие в разработке](#участие-в-разработке)

## Схема

```
 Телефон / ноутбук / ТВ
          │  Wi-Fi или LAN, без настроек
          ▼
 ┌──────────────── Flint (OpenWrt) ────────────────┐
 │ DNS: [AdGuard Home] ──► dnsmasq ──► DoH         │
 │ iptables: TCP из br-lan ──► Xray :12345         │
 │           (устройства без VPN — напрямую)       │
 │ Xray: РФ и свои «напрямую» ──► direct           │
 │       остальное ──► VLESS + REALITY             │
 │ uhttpd :81 ──► веб-панель (CGI)                 │
 └─────────────────────────────────────────────────┘
          │
          ▼
 Основной роутер ──► интернет
```

## Что происходит с трафиком

- Правила `iptables` (через `/etc/firewall.user`) отправляют TCP-трафик клиентов из `br-lan` в `dokodemo-door` Xray. Локальные и частные сети, а также адреса VPN-серверов идут мимо.
- DNS-запросы устройств принудительно идут на роутер. При включённой блокировке рекламы они сначала попадают в AdGuard Home, иначе — сразу в dnsmasq; дальше — в dnscrypt-proxy (DoH или DNSCrypt) или, в режиме UDP, напрямую на выбранные DNS-серверы.
- QUIC (UDP 443) блокируется, чтобы браузеры и приложения перешли на TCP и попали в туннель. Остальной UDP идёт напрямую. Устройства без VPN сохраняют QUIC.
- Конфиг Xray собирается из шаблона `/etc/xray/template.json` скриптом `flint-node`: выбранный сервер, гео-фильтр, свои сайты. Перед применением конфиг проверяется `xray -test`, после — проверяется IP выхода. Если новый конфиг не поднялся, возвращается прежний.
- Собственный трафик роутера (обновление подписки, пакетов) идёт напрямую: перехват работает только для трафика из локальной сети.

## Структура проекта

| Путь | Что это |
|---|---|
| `kit/install.sh` | установщик, запускается на роутере; можно запускать повторно |
| `kit/state-files` | список пользовательских файлов в `/etc/xray`, которые переносят бэкап, восстановление и деплой |
| `kit/files/usr/share/flint/settings-files` | список файлов, которые переносит файл настроек панели; проверяется на согласованность с `state-files` сценарием `settings` |
| `kit/files/usr/share/flint/panel/` | части веб-панели: `ui.sh` (разметка, переключатель языка, проверка PIN, выгрузка настроек) и по файлу на вкладку (`status.sh`, `subs.sh`, `servers.sh`, `own.sh`, `dns.sh`, `routing.sh`, `adblock.sh`, `telegram.sh`, `settings.sh`). `panel.cgi` подключает их; сами по себе это не скрипты, а фрагменты, поэтому проверка синтаксиса их пропускает |
| `tests/` | сценарии проверки на роутере (`empty`, `redeploy`, `subscription`, `own-server`, `failover`, `panel`, `settings`, `adblock`): `tests/run.ps1` / `tests/run.sh` заливает рабочую копию, а установка и сценарии идут в фоне на роутере, так что обрыв связи их не прерывает. Повторный запуск того же кода с теми же сценариями не начинает заново, а дочитывает уже идущий или завершённый прогон (`-Force` / `--force` — запустить заново). Сценарий сохраняет копию `/etc/xray` и в конце возвращает её (большинство по ходу удаляют все серверы); одновременно идёт только один |
| `kit/migrate.sh` | переход со старых версий комплекта; его вызывает `install.sh` |
| `kit/files/` | файлы для роутера: шаблон Xray, init-скрипты, firewall, скрипты `flint-*` (сервер, подписки, свои серверы, автопереключение, реклама, DNS, Telegram, настройки), веб-панель |
| `kit/bin/` | архив прокси для Telegram (tg-ws-proxy-rs для aarch64) и его лицензия: деплой ставит прокси отсюда, без скачивания с GitHub |
| `config/*.example` | образцы настроек |
| `config/flint.env`, `config/nodes.conf` | **ваши** настройки и секреты — в git не попадают |
| `config/nodes-custom.conf`, `config/custom-sites`, `config/subscriptions`, `config/adblock-*` | свои серверы, сайты, подписки, списки и правила блокировки рекламы из панели; появляются после бэкапа |
| `deploy.ps1` / `deploy.sh` | залить комплект на роутер и установить |
| `backup.ps1` / `backup.sh` | резервная копия роутера в `backup/` |
| `restore.ps1` / `restore.sh` | восстановление из `backup/` |
| `uninstall.ps1` / `uninstall.sh` | удалить Flint VPN с роутера (на роутере работает `kit/uninstall.sh`) |
| `fix.ps1` | одна команда для починки: проверить роутер, вернуть DNS на рабочий режим, залить комплект и прогнать тесты |
| `tools/run-tests.ps1` | залить комплект и прогнать все сценарии на роутере, показывая вывод (не зависит от рабочего каталога и временных переменных) |
| `tools/check.ps1` | то же, что делает CI, но на машине разработчика: синтаксис, CRLF, шаблон Xray, секреты, shellcheck |
| `tools/screenshot.js` | снимки панели через headless-браузер для README (`tests/demo.sh` готовит страницы) |
| `tools/check-secrets.sh` | не даёт закоммитить ссылку подписки, PIN панели, пароль Wi-Fi или приватный ключ; включается хуком `.githooks/pre-commit` |
| `tools/check-scripts.sh` | проверки без роутера: синтаксис скриптов, отсутствие CRLF, шаблон Xray; то же запускает CI в `.github/workflows/checks.yml` |
| `kit/VERSION` | номер версии |
| `CHANGELOG.md` | история изменений |
| `docs/` | эта документация, скриншоты, логотип; выполненные аудиты и планы — в `docs/archive/` |

## Где что лежит на роутере

| Путь | Что |
|---|---|
| `/etc/xray/` | настройки и состояние: `template.json`, `config.json`, `nodes.conf`, `nodes.d/`, `nodes-custom.conf`, `subscriptions`, `current-node`, `flint.env`, `xray-opts`, `tgproxy`, списки и правила блокировки, `watchdog-last`, `switch-at`. Права `600`; входят в бэкап |
| `/www/flint/` | панель: `index.html`, `panel.css`, `cgi-bin/panel.cgi` |
| `/usr/share/flint/` | `lib.sh` (общая библиотека), `panel/` (части панели), `settings-files` (список для файла настроек), `state-files`, `version` |
| `/usr/bin/flint-*` | команды: `flint-node`, `flint-custom`, `flint-sub-update`, `flint-watchdog`, `flint-adblock`, `flint-dns`, `flint-tg`, `flint-settings`, `flint-geo-update` |
| `/etc/init.d/flint-*`, `/etc/init.d/xray` | службы procd |
| `/etc/firewall.user` | перехват трафика, DNS, блокировка QUIC, доступ из сети основного роутера |
| `/lib/upgrade/keep.d/flint` | что сохранять при обновлении прошивки с «Сохранить настройки» |
| `/etc/flint-adguard/` | скачанный кеш списков AdGuard Home (не входит в бэкап) |

## Службы

| Служба | Порт | Что делает |
|---|---|---|
| `xray` | 12345 (перехват), 1087 (HTTP-вход для прокси Telegram) | туннель VLESS + REALITY и маршрутизация |
| `flint-ui` | 81 | панель (`uhttpd` с CGI) |
| `flint-doh` | 5053 | dnscrypt-proxy: DoH или DNSCrypt |
| `flint-adblock` | 5054 (API 3054, только `127.0.0.1`) | AdGuard Home: блокировка рекламы |
| `flint-tgproxy` | 1443 | прокси для Telegram |

Все службы — procd, с перезапуском при падении. Сторож (`flint-watchdog`) и обновление подписок/списков/баз geo запускаются cron.

## Версии и обновление

Версия на роутере видна внизу меню панели и в `/usr/share/flint/version`; деплой пишет в начале, какая версия ставится и какая стояла. Версии нумеруются по [SemVer](https://semver.org/lang/ru/): `1.2.3` — мажорная (несовместимые изменения), минорная (новые возможности), патч (исправления). Номер лежит в `kit/VERSION`, у каждой версии есть git-тег `vX.Y.Z`, что изменилось — в [CHANGELOG.md](../CHANGELOG.md).

Обновление проекта — `git pull` и повторный деплой, см. [Обслуживание](maintenance.md#обновление-проекта).

## Безопасность

- UUID, PIN, ссылки подписок и серверы хранятся только в `config/flint.env`, `config/nodes*.conf`, `config/subscriptions` и `backup/` — все они в `.gitignore`. Перед публикацией форка проверьте, что они не попали в коммиты.
- На роутере эти файлы лежат в `/etc/xray/` с правами `600`.
- Панель слушает порт 81. Firewall пускает к ней только локальную сеть Flint и сеть основного роутера (`UPSTREAM_NET`); остальной внешний трафик к роутеру закрыт.
- Прокси для Telegram (порт 1443) так же доступен только из этих двух сетей; порт открывается в интернет, лишь когда включён «Доступ из интернета». Без секрета подключиться к прокси нельзя.
- Секрет прокси не виден в списке процессов: он передаётся переменной окружения.

## Участие в разработке

Pull request'ы и issues приветствуются: исправления, поддержка других роутеров, переводы панели.

Перед правкой загляните в [CONTRIBUTING.md](../CONTRIBUTING.md) — там правила проекта (POSIX shell, где живут пути и состояние, справка команд, переводы строк) и порядок работы: номер версии в `kit/VERSION`, запись в оба CHANGELOG, правка README на двух языках и обязательный прогон `tests/run.ps1` на роутере. Для отчётов есть шаблоны: [баг](../.github/ISSUE_TEMPLATE/bug.md) и [роутер, на котором проверено](../.github/ISSUE_TEMPLATE/router-compatibility.md) — второй попадает в список проверенных устройств.

Отправляя pull request, вы соглашаетесь с условиями из [LICENSE.ru.md](../LICENSE.ru.md#доработки).

## Благодарности

- [Xray-core](https://github.com/XTLS/Xray-core) — VLESS, REALITY и маршрутизация;
- [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) — базы geoip и geosite;
- [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) — DNS через DoH и DNSCrypt;
- [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) и [фильтры AdGuard](https://github.com/AdguardTeam/AdGuardSDNSFilter) — блокировка рекламы;
- [tg-ws-proxy-rs](https://github.com/valnesfjord/tg-ws-proxy-rs) и [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — прокси для Telegram;
- [OpenWrt](https://openwrt.org) и [GL.iNet](https://www.gl-inet.com).

---

**Дальше:** [Установка](install.md) · [Веб-панель](panel.md) · [Серверы и подписки](servers.md) · [DNS и блокировка рекламы](dns-adblock.md) · [Прокси для Telegram](telegram-proxy.md) · [Обслуживание](maintenance.md) · [Решение проблем](troubleshooting.md)
