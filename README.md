# Flint_Vless

Комплект для GL.iNet GL-BE6500 (Flint), прошивка 4.x, режим Repeater/WISP:

- весь трафик клиентов Wi‑Fi Flint прозрачно идёт через Xray (VLESS REALITY), без настроек на устройствах;
- маршрутизация как в профиле GruVPN для Happ: российские сайты (`geosite:category-ru`) и IP (`geoip:ru`) идут напрямую, остальное через VPN, `appsflyersdk.com` блокируется (гео-фильтр выключается в панели или `ROUTING` в `gru.env`);
- веб-панель `http://vpn.lan:81/` (по PIN): выбор сервера, включение/выключение VPN, гео-фильтр, свои сайты «всегда напрямую» / «всегда через VPN», свои серверы (по ссылке `vless://` или вручную), обновление списка серверов по подписке (и автоматически каждый день в 5:15);
- DNS через DoH (dnscrypt-proxy на `127.0.0.1:5053`) против подмены DNS провайдером;
- LAN основного роутера (`192.168.0.0/24`) и NAS доступны напрямую, без VPN;
- из LAN основного роутера доступны сам Flint и устройства за ним (`192.168.8.0/24`);
- локальные имена (`nas01` и т.п.) через dnsmasq Flint.

## Состав

| Путь | Что это |
|---|---|
| `kit/install.sh` | установщик, запускается на роутере; можно запускать повторно |
| `kit/upstream-access.sh` | только доступ из сети основного роутера к Flint (то же есть в `install.sh`) |
| `kit/files/` | файлы, которые кладутся на роутер (шаблон Xray, init-скрипты, firewall, панель) |
| `config/*.example` | образцы настроек |
| `config/gru.env`, `config/nodes.conf` | **ваши** настройки и секреты (UUID, PIN, узлы) — в git не попадают |
| `config/nodes-custom.conf`, `config/custom-sites` | свои серверы и сайты из панели; появляются после бэкапа, деплой возвращает их на роутер |
| `tools/sub2nodes.py` | пересобрать `config/nodes.conf` из подписки провайдера |
| `deploy.ps1` / `deploy.sh` | залить комплект на роутер и установить (Windows / macOS, Linux) |
| `backup.ps1` / `backup.sh` | снять с роутера резервную копию в `backup/` (в git не попадает) |

## Установка с нуля (новый или сброшенный роутер)

1. Настроить роутер в админке GL (`http://192.168.8.1`): задать пароль, подключить Repeater к Wi‑Fi основного роутера.
2. Если роутер сбрасывался, удалить старый ключ хоста: `ssh-keygen -R 192.168.8.1`.
3. (Желательно) добавить SSH-ключ, чтобы не вводить пароль:
   ```powershell
   # Windows
   Get-Content "$HOME\.ssh\id_rsa.pub" | ssh root@192.168.8.1 "cat >> /etc/dropbear/authorized_keys && chmod 600 /etc/dropbear/authorized_keys"
   ```
   ```sh
   # macOS / Linux
   cat ~/.ssh/id_*.pub | ssh root@192.168.8.1 "cat >> /etc/dropbear/authorized_keys && chmod 600 /etc/dropbear/authorized_keys"
   ```
4. Проверить, что есть `config/gru.env` и `config/nodes.conf` (взять из `backup/<дата>/` или заполнить по `*.example`).
5. Запустить из корня репозитория:
   ```powershell
   .\deploy.ps1          # Windows
   ```
   ```sh
   ./deploy.sh           # macOS / Linux
   ```
   В конце установщик печатает `DNS: ok`, IP выхода VPN и адрес панели.

### Пакеты

`install.sh` сам ставит недостающее: чинит архитектуры в `/etc/opkg.conf` (фид GL собирает `xray-core` под `aarch64_cortex-a53`, а прошивка объявляет `aarch64_cortex-a53_neon-vfpv4`), затем через `opkg` — `curl`, `ca-bundle`, `dnscrypt-proxy2`, `unzip`, `xray-core`. Лог: `/tmp/gru-opkg.log`.

Если `xray-core` из `opkg` не встал, берётся по порядку:
1. `backup/bin/xray` — сохраните заранее с рабочего роутера: `.\backup.ps1 -WithBinary` / `./backup.sh --with-binary`;
2. официальный релиз с GitHub (`XRAY_VERSION`, по умолчанию `v1.8.24`).

## Доступ к Flint из сети основного роутера

`install.sh` разрешает на Flint входящие соединения из `UPSTREAM_NET` (к самому роутеру и к устройствам `192.168.8.x`). Остаётся настроить основной роутер (TP-Link, `http://192.168.0.1`):

- резервирование DHCP для Flint (его MAC в режиме репитера → `192.168.0.111`), чтобы адрес не менялся;
- статический маршрут: сеть `192.168.8.0`, маска `255.255.255.0`, шлюз `192.168.0.111`.

После этого Flint доступен из сети TP-Link как `192.168.0.111` и как `192.168.8.1`. Если на компьютере включён VPN-клиент (Happ и т.п.), он может забирать `192.168.8.x` в туннель — тогда добавьте маршрут на самом компьютере:

```powershell
route -p add 192.168.8.0 mask 255.255.255.0 192.168.0.111   # Windows, от администратора
```

## Резервная копия

```powershell
.\backup.ps1              # конфиги роутера -> backup\<дата>\router-config.tar.gz, обновляет config\
.\backup.ps1 -WithBinary  # плюс backup\bin\xray (~27 МБ)
```
```sh
./backup.sh
./backup.sh --with-binary
```

Папку `backup/` и `config/gru.env` / `config/nodes.conf` храните отдельно (облако, флешка): в них UUID подписки.

## Настройки `config/gru.env`

- `VLESS_UUID` — UUID из ссылки `vless://UUID@...`.
- `UI_PIN` — PIN панели (только буквы и цифры).
- `UI_TITLE` — заголовок панели, по умолчанию `Flint VPN`.
- `DEFAULT_NODE` — узел после установки (код из `nodes.conf`).
- `ROUTING` — `ru` (РФ-сайты напрямую, остальное через VPN) или `global` (всё через VPN). Базы `geoip.dat`/`geosite.dat` (Loyalsoldier) скачиваются в `/usr/share/xray` при установке и обновляются по воскресеньям в 4:30; без них роутер автоматически работает в режиме `global`.
- `UPSTREAM_IF` / `UPSTREAM_NET` — интерфейс и сеть основного роутера (`sta1` для Wi‑Fi-репитера, `wan` для кабеля).
- `LOCAL_HOSTS` — локальные имена: `"nas01=192.168.0.145 printer=192.168.0.50"`.
- `XRAY_VERSION` — релиз Xray для загрузки с GitHub, если других источников нет.

- `SUB_URL` — ссылка на подписку (из Happ/v2rayN): по ней роутер сам обновляет список серверов (`gru-sub-update`, кнопка в панели) и её же читает `tools/sub2nodes.py`.

## Серверы `config/nodes.conf`

Список собирается из подписки провайдера (он периодически меняет SNI и ключи — тогда просто пересоберите):

```sh
python tools/sub2nodes.py     # берёт SUB_URL из config/gru.env, пишет config/nodes.conf
```

Затем снова запустить деплой. Берутся только серверы TCP + REALITY с доменным адресом; серверы «белых списков» (голые IP) — с флагом `--include-ip`. Формат строки: `код адрес sni pbk sid [uuid] [порт]` (пустой sid — `-`), строка-комментарий над узлом — его название в панели.

Свои серверы (не из подписки) лежат на роутере отдельно, в `/etc/xray/nodes-custom.conf`, с кодами `my1`, `my2`… Обновление подписки их не трогает. Сервер из подписки нельзя править напрямую (следующее обновление затрёт правку), но в панели его можно скопировать в свои и изменить копию.

## Полезное на роутере

```sh
gru-node list        # текущий узел и коды
gru-node nl          # переключиться на узел nl
gru-node routing ru  # гео-фильтр: РФ напрямую (global — всё через VPN)
gru-node vpn off     # клиенты ходят в интернет напрямую (on — снова через VPN)
gru-node site add direct gosuslugi.ru   # свой сайт: direct — мимо VPN, proxy — через VPN
gru-node site list
gru-node site del gosuslugi.ru
gru-custom link 'vless://...'           # добавить свой сервер по ссылке
gru-custom list
gru-custom del my1
gru-sub-update       # обновить список серверов по подписке
gru-geo-update       # обновить geoip/geosite вручную
logread -e xray      # логи Xray
```

## Клиенты

- VPN-клиент на устройстве в сети Flint не нужен: Flint уже пускает всё через VPN. Если он всё же включён (например, Happ), его соединения с серверами провайдера идут с Flint напрямую, а не через второй VPN.
- Android: «Частный DNS» → «Выкл».
- Windows: в свойствах Wi‑Fi «Назначение DNS» → «Автоматически (DHCP)»; иначе включённый DoH обходит DNS роутера и локальные имена (`nas01`) не резолвятся.
