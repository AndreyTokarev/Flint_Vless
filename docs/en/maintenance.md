# Maintenance

Backups, restore, firmware upgrades, uninstalling, and the commands on the router.

**Contents**
- [Backup](#backup)
- [Restore from a backup](#restore-from-a-backup)
- [Firmware upgrade](#firmware-upgrade)
- [Uninstall](#uninstall)
- [Router commands](#router-commands)
- [Updating the project](#updating-the-project)

## Backup

```powershell
.\backup.ps1               # router configs -> backup\<date>\router-config.tar.gz, refreshes config\
.\backup.ps1 -WithBinary   # plus backup\bin\xray (~27 MB) — useful if opkg is unavailable
```
```sh
./backup.sh
./backup.sh --with-binary
```

The backup pulls from the router its settings, the own servers and sites from the panel, and the network and Wi‑Fi configs. The user files listed in `kit/state-files` (`flint.env`, servers, subscriptions, sites, ad blocking files) are saved as one archive, `backup\<date>\state.tar.gz`, and also copied into `config/`, which the deploy uploads later. This includes `flint.env` with the PIN, if it was changed in the panel.

Without a computer, the panel settings can be saved as a file: Settings → "Download the settings file" (or `flint-settings export` on the router). It is not a full backup: `flint.env`, the network and Wi‑Fi are not included.

> [!WARNING]
> `backup/` and the files in `config/` contain your subscription UUID and Wi‑Fi passwords. They are gitignored; keep them separately — in the cloud or on a USB stick.

## Restore from a backup

```powershell
.\restore.ps1                                   # the latest backup\<date>
.\restore.ps1 -Backup backup\2026-10-03_1557    # a specific one
.\restore.ps1 -Full                             # plus network, Wi-Fi, firewall, DHCP, SSH keys and a reboot
```
```sh
./restore.sh
./restore.sh backup/2026-10-03_1557
./restore.sh --full
```

By default, `flint.env`, servers, subscriptions, own servers and sites, the ad blocking lists, rules and exclusions from the backup go into `config/`, then a normal deploy runs, and after it every panel setting from the backup comes back to the router: the chosen server, VPN and routing modes, DNS, local names, ad blocking, the Telegram proxy (with the same secret, so the links in Telegram keep working), the intervals and the watchdog. It also works for a reset router: connect it to the internet in the GL admin panel first. The current `config/` files are saved into `backup/config-before-restore-<time>/` before being replaced.

`-Full` / `--full` is only for the **same** router: it restores its network, Wi‑Fi (SSIDs and passwords), firewall, DHCP reservations, cron and SSH keys, then reboots. The script asks for confirmation (`-Yes` / `--yes` skips it).

**If `xray-core` from `opkg` did not install**, Xray is taken in this order:

1. `backup/bin/xray` — save it in advance from a working router: `.\backup.ps1 -WithBinary`;
2. the official release from GitHub (`XRAY_VERSION`).

## Firmware upgrade

Upgrade the firmware with **Keep Settings** checked, and Flint VPN survives the upgrade: after the reboot the VPN, panel, subscriptions, ad blocking and Telegram proxy work as before, no redeploy needed.

**How it works.** An upgrade wipes everything installed on top of the firmware, and with Keep Settings it carries over only `/etc/config/*` (network, Wi‑Fi, DHCP, firewall rules) and files from explicit lists. `install.sh` puts such a list into `/lib/upgrade/keep.d/flint` — the standard OpenWrt place `sysupgrade` reads before flashing. The list holds:

| What | Paths |
|---|---|
| Settings, servers, subscriptions, PIN | `/etc/xray` |
| Scripts, panel, services | `/usr/bin/flint-*`, `/usr/share/flint`, `/www/flint`, `/etc/init.d/xray`, `/etc/init.d/flint-*` |
| Service autostart | links `/etc/rc.d/*xray`, `/etc/rc.d/*flint-*` |
| Xray, geoip/geosite databases, Telegram proxy | `/usr/bin/xray`, `/usr/share/xray`, `/usr/bin/tg-ws-proxy` |
| Traffic interception, DNS, ad blocking | `/etc/firewall.user`, `/etc/dnsmasq.d/flint-*.conf`, `/etc/dnscrypt-proxy2/flint-doh.toml`, `/etc/flint-adguard` |
| Cron jobs (subscriptions, watchdog, geo databases) | `/etc/crontabs/root` |

The list includes itself, so the next upgrade keeps everything too. With Xray and the geo databases about 60 MB go into the upgrade archive — fine for this router.

**Check beforehand** without changing anything: `sysupgrade -l` on the router prints the files that will be kept. It should list `/etc/xray/…`, `/usr/bin/flint-…`, `/www/flint/…`. A deploy checks this itself and ends with `Firmware upgrade with "Keep settings": Flint stays (N files)`.

**When a deploy or restore is still needed:**

- upgraded **without** Keep Settings or reset the router — `.\restore.ps1 -Full` (or a normal deploy and setting up again);
- the new firmware is on another major OpenWrt version (e.g. 23.05 → 24.10) and something does not work after the upgrade — redeploy: it rewrites the kit's files, and the settings in `/etc/xray` stay;
- packages `install.sh` installed with `opkg` (`dnscrypt-proxy2`, `iptables-nft`, etc., if the firmware lacked them) are removed by the upgrade — a redeploy brings them back. GL firmware 4.x already has them; Xray itself is kept as a file.

Make a backup before a firmware upgrade anyway (`.\backup.ps1`), in case something goes wrong.

## Uninstall

```powershell
.\uninstall.ps1               # back up, then uninstall
.\uninstall.ps1 -KeepXray     # keep the xray-core package
.\uninstall.ps1 -NoBackup     # no backup
```
```sh
./uninstall.sh
./uninstall.sh --keep-xray
./uninstall.sh --no-backup
```

The script asks for confirmation (`-Yes` / `--yes` skips it), backs up to `backup/<date>` and removes from the router everything Flint VPN installed: the panel, services, `flint-*` scripts, settings in `/etc/xray`, its own AdGuard Home instance, the Telegram proxy, firewall rules and cron jobs, the `xray-core` package and the geoip/geosite databases. The DNS settings go back to the firmware defaults: dnsmasq takes DNS from the main router again. The firmware and its packages (`dnscrypt-proxy2`, `curl`, the firmware's AdGuard Home, etc.), network, Wi‑Fi and the root password stay as they are.

After uninstalling, devices go online directly. Flint is no longer reachable from the main router's network (Flint VPN's rules did that): connect to it over Wi‑Fi or a cable. To bring everything back, run `.\restore.ps1` / `./restore.sh` with the backup just made.

To uninstall by hand, without a computer with the project: upload `kit/uninstall.sh` to the router and run `sh uninstall.sh` (or `sh uninstall.sh --keep-xray`).

## Router commands

```sh
flint-node list                  # current server and codes
flint-node nl                    # switch to server nl (with an exit IP check)
flint-node routing ru            # geo filter: Russia direct (global — everything via the VPN)
flint-node vpn off               # clients go online directly (on — through the VPN again)
flint-node site add direct gosuslugi.ru   # own site: direct — past the VPN, proxy — through it
flint-node site list
flint-node site del gosuslugi.ru
flint-node direct add aa:bb:cc:dd:ee:ff TV   # device without VPN; list: flint-node direct, remove: direct del <MAC>
flint-node probe                 # connection time to every server: code, ms (silent ones show "-")
flint-node fastest               # the quickest server among those that answered
flint-node probe-mode fastest    # on failure switch to the fastest (first — to the first in the list)
flint-node opts                  # TLS fingerprint and mux: what is on now
flint-node fingerprint chrome    # which browser to claim to the server: chrome, firefox, safari, edge, random
flint-node mux on                # connection multiplexing (off by default; turns itself off if the tunnel stops working)
flint-node mux off               # turn multiplexing off
flint-custom link 'vless://...'  # add an own server by link
flint-custom list
flint-custom del my1
flint-sub-update                 # update every subscription
flint-sub-update list            # subscriptions: id, name, site, last update, expiry and traffic
flint-sub-update add 'https://...' "Name"   # add a subscription
flint-sub-update set s2 'https://...'       # new link (or name) for subscription s2
flint-sub-update del s2          # delete a subscription and its servers
flint-sub-update interval 1h     # auto-update: off, 30m, 1h, 3h, 6h, 12h, 24h
flint-watchdog off               # turn failover off (on — on)
cat /etc/xray/watchdog-last    # the last failover event
flint-geo-update                 # refresh geoip/geosite by hand
flint-adblock on                 # ad blocking (off — off)
flint-adblock list               # lists: URL, name, rules, last update
flint-adblock list add https://example.com/list.txt "Name"
flint-adblock rule add block ads.example.com   # allow — an exception
flint-adblock blocked                          # recently blocked domains and devices
flint-adblock exclude add aa:bb:cc:dd:ee:ff    # a device without blocking
flint-adblock refresh            # update the lists now
flint-adblock interval 24        # auto-update: off, 1, 12, 24, 72, 168 hours
flint-settings export > /tmp/s.txt   # export the panel settings (without flint.env)
flint-settings import /tmp/s.txt     # import: replaces the panel settings and applies them at once
flint-dns                            # current DNS: mode and server
flint-dns doh quad9                  # DoH; your own: flint-dns doh https://dns.example.com/dns-query
flint-dns dnscrypt quad9             # DNSCrypt; your own: flint-dns dnscrypt sdns://...
flint-dns udp provider               # plain DNS: a preset, provider or IPs separated by spaces
flint-dns mode doh                   # switch the mode: doh, dnscrypt, udp
flint-dns hosts                      # local names; add: flint-dns hosts add nas01 192.168.0.145, remove: hosts del nas01
flint-tg on                          # Telegram proxy (off — off)
flint-tg link                        # the tg://proxy link for the Flint network (upstream — main router, remote — internet)
flint-tg route vpn                   # route to Telegram via the VPN (direct — directly)
flint-tg check                       # check the proxy through to an answer from Telegram's servers
flint-tg secret <hex>                # an own secret (new — a new random one)
flint-tg dc 2:149.154.167.220        # data center addresses (default — the built-in ones)
flint-tg log verbose                 # the proxy log (on, off); flint-tg logs — the last lines
flint-tg latest                      # is there a newer proxy version on GitHub
logread -e xray                # Xray logs
```

## Updating the project

The code is updated with a plain `git pull` and a redeploy:

```powershell
git pull
.\deploy.ps1
```

Versions follow [SemVer](https://semver.org/): `1.2.3` — major (incompatible changes), minor (new features), patch (fixes). The number lives in `kit/VERSION`, every version has a `vX.Y.Z` git tag, and what changed is in [CHANGELOG.en.md](../../CHANGELOG.en.md).

---

**Next:** [Installation](install.md) · [Web panel](panel.md) · [Servers and subscriptions](servers.md) · [DNS and ad blocking](dns-adblock.md) · [Telegram proxy](telegram-proxy.md) · [Troubleshooting](troubleshooting.md) · [How it works](internals.md)
