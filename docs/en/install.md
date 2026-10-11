# Installation

The short path fits in the [README](../../README.en.md#quick-start); this page is the same thing in detail: requirements, preparing the router, every setting, and what the installer does.

**Contents**
- [Requirements](#requirements)
- [1. Get the project](#1-get-the-project)
- [2. Prepare the router](#2-prepare-the-router)
- [3. Add an SSH key](#3-add-an-ssh-key)
- [4. Fill in `config/flint.env`](#4-fill-in-configflintenv)
- [5. Servers by hand (optional)](#5-servers-by-hand-optional)
- [6. Install](#6-install)
- [7. Open the panel](#7-open-the-panel)
- [All `config/flint.env` settings](#all-configflintenv-settings)
- [What the installer does](#what-the-installer-does)
- [If `opkg` is unavailable](#if-opkg-is-unavailable)
- [Other OpenWrt routers](#other-openwrt-routers)

## Requirements

**Router**
- GL.iNet with firmware 4.x (OpenWrt 22.03+ with fw4) or another OpenWrt router — see [Other OpenWrt routers](#other-openwrt-routers);
- **aarch64** architecture (the installer checks it);
- internet access during installation (packages come from `opkg`) and ~60 MB of free space: Xray is about 27 MB, the geoip/geosite databases about 25 MB;
- SSH access as `root` (enabled by default on GL.iNet; the password is the admin panel one).

**VPN**
- a provider subscription with `vless://` links (VLESS + REALITY), as used by Happ, v2rayN or Hiddify, or your own VLESS + REALITY server.

**Computer for installation**
- Windows 10/11 with PowerShell and the built-in OpenSSH, **or** macOS / Linux with `ssh` and `tar`.

## 1. Get the project

```sh
git clone https://github.com/AndreyTokarev/Flint_Vless.git
cd Flint_Vless
```

Or download a ZIP: green **Code → Download ZIP** button on GitHub, then unpack it.

## 2. Prepare the router

1. Open the GL.iNet admin panel at `http://192.168.8.1` and set the admin password.
2. Connect the router to the internet. Tested in **Repeater** mode: *Internet → Repeater* → pick your main router's Wi‑Fi. A cable in WAN works too — then set `UPSTREAM_IF=wan` below.
3. Make sure the internet works on the router (green connection status in the admin panel).
4. If the router was reset and you have connected to it over SSH before, remove the old host key:
   ```sh
   ssh-keygen -R 192.168.8.1
   ```

## 3. Add an SSH key

Without a key you will type the `root` password several times per deploy.

```powershell
# Windows (PowerShell). No key yet? ssh-keygen -t ed25519
Get-Content "$HOME\.ssh\id_ed25519.pub" | ssh root@192.168.8.1 "cat >> /etc/dropbear/authorized_keys && chmod 600 /etc/dropbear/authorized_keys"
```

```sh
# macOS / Linux
cat ~/.ssh/id_*.pub | ssh root@192.168.8.1 "cat >> /etc/dropbear/authorized_keys && chmod 600 /etc/dropbear/authorized_keys"
```

Check: `ssh root@192.168.8.1 echo ok` should print `ok` without asking for a password.

## 4. Fill in `config/flint.env`

```powershell
Copy-Item config\flint.env.example config\flint.env     # Windows
```
```sh
cp config/flint.env.example config/flint.env              # macOS / Linux
```

The minimum to fill in:

| Setting | Value |
|---|---|
| `UI_PIN` | panel PIN (letters and digits) |
| `SUB_URL` | subscription URL (the one you add to Happ / v2rayN). May be left empty: add the subscription later in the panel |
| `UPSTREAM_IF` | `sta1` — router on Wi‑Fi (Repeater), `wan` — on a cable |
| `UPSTREAM_NET` | main router's network, e.g. `192.168.0.0/24` or `192.168.1.0/24` |

Everything else — in [All settings](#all-configflintenv-settings). `config/flint.env` is never committed.

## 5. Servers by hand (optional)

Usually not needed. If `SUB_URL` is set, the router downloads the subscription's servers during the install and keeps the list fresh by itself. The install also works without servers: devices go online directly until you add a subscription on the Subscriptions tab (or an own server on the Own servers tab), then the VPN turns on by itself.

With no subscription, only a server link, copy `config/nodes.conf.example` to `config/nodes.conf` and add the server from the link (or add it after the install on the Own servers tab):

```
vless://UUID@ADDRESS:PORT?type=tcp&security=reality&sni=SNI&pbk=PBK&sid=SID&flow=xtls-rprx-vision#NAME
```

```
# 🇳🇱 Netherlands
nl  ADDRESS  SNI  PBK  SID  UUID  PORT
```

The comment line above a server is its name in the panel. An empty `sid` is written as `-`. The first field is a short code (`nl`); after the install the server with the `DEFAULT_NODE` code from `flint.env` is enabled, or the first one if there is no such code. More — in [Servers and subscriptions](servers.md#servers-by-hand).

## 6. Install

From the project root:

```powershell
.\deploy.ps1                       # Windows
.\deploy.ps1 -Router 192.168.8.1   # if the router has another address
```
```sh
./deploy.sh                        # macOS / Linux
./deploy.sh 192.168.8.1
```

> [!TIP]
> If PowerShell says running scripts is disabled, allow it for the current window:
> `Set-ExecutionPolicy -Scope Process Bypass`

The script packs the kit, uploads it and runs `install.sh` on the router. It takes a few minutes: packages are installed, Xray and the geoip/geosite databases (~25 MB) are downloaded. At the end you will see:

```
DNS: ok
VPN exit IP: 203.0.113.42
Panel: http://vpn.lan:81/  (PIN from flint.env)
```

`VPN exit IP` is the VPN server's address, not your home one. If you get `VPN: FAIL` instead, see [Troubleshooting](troubleshooting.md).

## 7. Open the panel

Connect to the router's Wi‑Fi and open **http://vpn.lan:81/** (or `http://192.168.8.1:81/`), enter the PIN from `flint.env`. To check the VPN, open any site like [ifconfig.me](https://ifconfig.me): it should show the VPN server's address.

You can rerun the installation any number of times — for example after changing `flint.env` or updating the project. Settings made in the panel (own servers, sites, update interval) are kept. What the panel has — in [Web panel](panel.md).

## All `config/flint.env` settings

| Setting | Description |
|---|---|
| `UI_PIN` | panel PIN (letters and digits, at least 4) |
| `UI_LANG` | default panel language: `ru` or `en` |
| `UI_TITLE` | title in the panel header (`Flint VPN` by default) |
| `SUB_URL` | subscription URL; goes into the subscription list on the first run |
| `SUB_GRPC` | `1` — do not skip gRPC servers from a subscription (they are skipped by default) |
| `DEFAULT_NODE` | code of the server enabled after the install, or `auto` |
| `ROUTING` | `ru` — Russian sites and IPs go direct, the rest through the VPN; `global` — everything through the VPN |
| `UPSTREAM_IF` | interface towards the main router: `sta1` (Wi‑Fi, Repeater) or `wan` (cable) |
| `UPSTREAM_NET` | main router's network, e.g. `192.168.0.0/24` — access to Flint is allowed from it |
| `LOCAL_HOSTS` | local names as `name=IP`, space-separated: `nas01=192.168.0.145` |
| `IP_LOOKUP` | service that reports the router's external address (`https://ifconfig.me` by default) |

## What the installer does

1. Checks the model and architecture (it needs `aarch64`) and stops otherwise.
2. Installs packages: `curl`, `ca-bundle`, `dnscrypt-proxy2`, `unzip`, `xray-core`; log in `/tmp/flint-opkg.log`.
3. Installs **Xray 26.3.27** from GitHub with a SHA-256 check. If the router already has a version **older than 25.6.8** (a firmware rollback can bring one back), the installer replaces it: older versions do not imitate the cover site's post-handshake records, and active probing can tell such a router apart. The previous binary is kept in `/usr/bin/xray.previous` and put back if the new one does not start.
4. Lays out the kit files: `/etc/xray` (settings and state), `/usr/share/flint` (library, template, panel parts), `/www/flint` (panel), `flint-*` in `/usr/bin`.
5. Enables the services: Xray, the panel on port 81, dnscrypt-proxy (DoH), AdGuard Home when ad blocking is on, Telegram when the proxy is on.
6. Configures the firewall: interception of LAN TCP into Xray, DNS to the router, QUIC blocking, access from the main router's network.
7. Downloads the geoip/geosite databases (~25 MB) for the `ru` mode.
8. Checks the result: `DNS: ok` and the exit address through the VPN.

The install can be rerun — it is idempotent and does not reset your settings.

## If `opkg` is unavailable

`install.sh` installs the packages it needs by itself: `curl`, `ca-bundle`, `dnscrypt-proxy2`, `unzip`, `xray-core` (log in `/tmp/flint-opkg.log`). On GL.iNet it also fixes the architecture list in `/etc/opkg.conf`: the GL feed builds `xray-core` for `aarch64_cortex-a53` while the firmware declares `aarch64_cortex-a53_neon-vfpv4`.

If packages cannot be installed (no internet or the repository is unreachable):

1. Download Xray for `linux-arm64` on your computer and put the binary in `kit/bin/xray` — the installer takes it from there instead of downloading.
2. The other packages (`curl`, `ca-bundle`, `unzip`) are required: without them there is nothing to unpack with and nothing to download with. Download their `.ipk` files and install them by hand with `opkg install /tmp/*.ipk`.
3. `dnscrypt-proxy2` is only needed for the DoH and DNSCrypt modes; without it the plain UDP mode and "through the tunnel" remain.

To see what went wrong:

```sh
ssh root@192.168.8.1 'cat /tmp/flint-opkg.log'
```

## Other OpenWrt routers

The project was made for the GL-BE6500 and has only been tested on it. On other devices it should work when:

- the architecture is **aarch64** (for `armv7`/`mips` you need your own Xray binary in `kit/bin/xray` and a change in `kit/install.sh`);
- the firmware has `fw4` (OpenWrt 22.03+) — the firewall rules are written for `nftables` through the `iptables-nft` compatibility layer;
- ports **81** (panel) and **12345** (traffic interception) are free;
- there is enough space in `/overlay` (~60 MB);
- `procd` (the standard OpenWrt init system) is there — every service of the project relies on it.

What will almost certainly need changing: `UPSTREAM_IF`/`UPSTREAM_NET` (on GL.iNet these are `sta1` and the main router's network) and, if the device has a different set of interfaces, the firewall rules in `kit/files/etc/firewall.user`.

If you ran it on another device, tell us in [Issues](https://github.com/AndreyTokarev/Flint_Vless/issues) how it went: it helps both you and the project.

---

**Next:** [Web panel](panel.md) · [Servers and subscriptions](servers.md) · [DNS and ad blocking](dns-adblock.md) · [Telegram proxy](telegram-proxy.md) · [Maintenance](maintenance.md) · [Troubleshooting](troubleshooting.md) · [How it works](internals.md)
