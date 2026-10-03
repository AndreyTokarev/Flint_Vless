# Flint_Vless

Комплект для GL.iNet GL-BE6500 (Flint), прошивка 4.x, режим Repeater/WISP:

- весь трафик клиентов Wi‑Fi Flint прозрачно идёт через Xray (VLESS REALITY), без настроек на устройствах;
- маршрутизация как в профиле GruVPN для Happ: российские сайты (`geosite:category-ru`) и IP (`geoip:ru`) идут напрямую, остальное через VPN, `appsflyersdk.com` блокируется (переключается в панели или `ROUTING` в `gru.env`);
- переключение регионов в веб-панели `http://gru.lan:81/` (по PIN);
- DNS через DoH (dnscrypt-proxy на `127.0.0.1:5053`) против подмены DNS провайдером;
- LAN основного роутера (`192.168.0.0/24`) и NAS доступны напрямую, без VPN;
- локальные имена (`nas01` и т.п.) через dnsmasq Flint.

## Состав

| Путь | Что это |
|---|---|
| `kit/install.sh` | установщик, запускается на роутере; можно запускать повторно |
| `kit/files/` | файлы, которые кладутся на роутер (шаблон Xray, init-скрипты, firewall, панель) |
| `config/*.example` | образцы настроек |
| `config/gru.env`, `config/nodes.conf` | **ваши** настройки и секреты (UUID, PIN, узлы) — в git не попадают |
| `deploy.ps1` | залить комплект на роутер и установить (с ПК Windows) |
| `backup.ps1` | снять с роутера резервную копию в `backup\` (в git не попадает) |

## Установка с нуля (новый или сброшенный роутер)

1. Настроить роутер в админке GL (`http://192.168.8.1`): задать пароль, подключить Repeater к Wi‑Fi основного роутера.
2. Если роутер сбрасывался, удалить старый ключ хоста: `ssh-keygen -R 192.168.8.1`.
3. (Желательно) добавить SSH-ключ, чтобы не вводить пароль:
   ```powershell
   Get-Content "$HOME\.ssh\id_rsa.pub" | ssh root@192.168.8.1 "cat >> /etc/dropbear/authorized_keys && chmod 600 /etc/dropbear/authorized_keys"
   ```
4. Проверить, что есть `config\gru.env` и `config\nodes.conf` (взять из `backup\<дата>\` или заполнить по `*.example`).
5. Запустить из корня репозитория:
   ```powershell
   .\deploy.ps1
   ```
   В конце установщик печатает `DNS: ok`, IP выхода VPN и адрес панели.

Если `opkg` не сможет скачать `xray-core`, сначала сохраните бинарник с рабочего роутера командой `.\backup.ps1 -WithBinary`: `deploy.ps1` сам подложит `backup\bin\xray`.

## Резервная копия

```powershell
.\backup.ps1              # конфиги роутера -> backup\<дата>\router-config.tar.gz, обновляет config\
.\backup.ps1 -WithBinary  # плюс backup\bin\xray (~27 МБ)
```

Папку `backup\` и `config\gru.env` / `config\nodes.conf` храните отдельно (облако, флешка): в них UUID подписки.

## Настройки `config/gru.env`

- `VLESS_UUID` — UUID из ссылки `vless://UUID@...`.
- `UI_PIN` — PIN панели (только буквы и цифры).
- `DEFAULT_NODE` — узел после установки (код из `nodes.conf`).
- `ROUTING` — `ru` (РФ-сайты напрямую, остальное через VPN) или `global` (всё через VPN). Базы `geoip.dat`/`geosite.dat` (Loyalsoldier) скачиваются в `/usr/share/xray` при установке и обновляются по воскресеньям в 4:30; без них роутер автоматически работает в режиме `global`.
- `UPSTREAM_IF` / `UPSTREAM_NET` — интерфейс и сеть основного роутера (`sta1` для Wi‑Fi-репитера, `wan` для кабеля).
- `LOCAL_HOSTS` — локальные имена: `"nas01=192.168.0.145 printer=192.168.0.50"`.

Узлы — `config/nodes.conf`, по строке на узел: `код адрес sni pbk sid [uuid]`.
После изменения настроек просто снова запустить `.\deploy.ps1`.

## Полезное на роутере

```sh
gru-node list        # текущий узел и коды
gru-node nl          # переключиться на узел nl
gru-node routing ru  # РФ напрямую (global — всё через VPN)
gru-geo-update       # обновить geoip/geosite вручную
logread -e xray      # логи Xray
```

## Клиенты

- Android: «Частный DNS» → «Выкл».
- Windows: в свойствах Wi‑Fi «Назначение DNS» → «Автоматически (DHCP)»; иначе включённый DoH обходит DNS роутера и локальные имена (`nas01`) не резолвятся.
