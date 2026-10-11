# Web panel

Address: **http://vpn.lan:81/** (port 80 is taken by the stock GL.iNet admin panel). The panel is reachable only from the router's LAN and from the main router's network (`UPSTREAM_NET`).

Sign in with the PIN (`UI_PIN` in `flint.env`). Forgotten it — see [Troubleshooting](troubleshooting.md#forgotten-pin).

**Contents**
- [Tabs](#tabs)
- [Language](#language)
- [Common tasks](#common-tasks)
- [Devices on the network](#devices-on-the-network)
- [Access from the main router's network](#access-from-the-main-routers-network)

## Tabs

| Tab | What's there |
|---|---|
| **Status** | VPN on/off button, current server, IP via VPN and the provider IP (before VPN), geo filter, number of own sites and servers, last subscription check, failover state and last failure, ad blocking, DNS server, Telegram proxy |
| **Subscriptions** | VPN provider subscriptions: add by link, change the link or name, delete; last update, number of servers, expiry and traffic; "Update all subscriptions now" and the auto-update interval |
| **Servers** | one-click server selection — servers grouped by subscription, own servers apart; "White lists" block; failover on/off; TLS fingerprint and mux |
| **Own servers** | servers not from the subscription: add by `vless://` link, copy a subscription server and edit the copy, enter manually; edit or delete |
| **DNS** | DoH, DNSCrypt or plain UDP mode with a server for each — a preset or your own; the mode in use is marked. Local names for network devices (`nas01` → IP) |
| **Routing** | Russia geo filter on/off; devices without VPN (by MAC); own sites, IPs and subnets "always direct" or "always via VPN" |
| **Ad blocking** | ad blocking on/off and 24-hour stats; devices without blocking; sites without blocking and "Recently blocked" with an Allow button; filter lists — ready-made and your own by URL; auto-update and "Update the lists now"; own rules |
| **Telegram** | Telegram proxy on/off and a check; "Add to Telegram" buttons for the Flint network, the main router's network and the internet, plus server, port and secret for manual entry; route to Telegram — directly or via VPN; Cloudflare fallback; access from the internet; port, masking (FakeTLS), a new or own secret; data center addresses, own Cloudflare domains and Worker, connection pool, proxy log, update check |
| **Settings** | change the PIN; export the settings to a file and import them from a file (subscriptions, servers, sites, devices without VPN, ad blocking, DNS, local names, Telegram proxy, modes; no PIN or network) |

## Language

The panel speaks English and Russian. On the first visit the language follows the browser (or `UI_LANG` in `flint.env`); after that use the **RU | EN** switch in the top right corner (next to "Sign out"; on the login page too) — the choice is remembered in the browser. Messages after panel actions use the same language.

## Common tasks

- **Change the server** — Servers tab, click the one you want. The router checks the config and the exit IP; if the server does not answer, the panel says so. If a switch fails and the link drops, the interception port is busy — see [Troubleshooting](troubleshooting.md#a-server-switch-takes-long-or-does-not-happen).
- **Turn the VPN off** — the button on the Status tab. Devices go online directly; the chosen DNS and access to the home network stay.
- **A site does not open through the VPN** (a bank, a government portal) — add it on the Routing tab as "Direct". A full link can be pasted; a domain also covers its subdomains.
- **A site must go through the VPN although it is Russian** — add it as "Via VPN".
- **The provider updated its servers** — "Subscriptions → Update all subscriptions now". This works with the VPN on too, even when the current server is down.
- **Add another provider** — "Subscriptions", paste the subscription link (the one from Happ) and press "Add subscription". The provider issued a new link — "Change" on that subscription.
- **Connect your own VPS** — "Own servers → Add by link" and paste `vless://...`.
- **Send a device past the VPN** (a TV, a console, a work laptop) — "Routing → Devices without VPN": pick the device from the list or type its MAC. The rest still go through the VPN.
- **Remove ads** — "Ad blocking → Turn on blocking".
- **A site broke because of blocking** — "Ad blocking → Sites without blocking": type the site, or open "Recently blocked" and press Allow on the domain. If it bothers a whole device, add it to "Devices without blocking".
- **Change DNS** — the DNS tab; see [DNS and ad blocking](dns-adblock.md#dns-modes).
- **Reach a NAS or printer by name** — "DNS → Local names": the name (`nas01`) and the device IP. `nas01`, `nas01.lan` and `nas01.local` all work; a name with a dot (`nas.home`) is used as is. Adding the same name again changes its address.
- **Telegram without the VPN** (on a device without VPN, with the VPN off, or to save subscription traffic) — "Telegram → Turn the proxy on", then press "Add to Telegram" on the device. More — [Telegram proxy](telegram-proxy.md).
- **Change the PIN** — "Settings → Change PIN". The new PIN works at once; to keep a redeploy from bringing the old one back, put it in `config/flint.env` or make a backup.
- **Move the settings** to another Flint or save them before an experiment — "Settings → Download the settings file", then "Upload settings" on the router you need. The PIN and the network (`flint.env`) are not part of the file. An import applies in the background and interrupts the VPN for a few seconds: it ends with an Xray restart.

## Devices on the network

- No VPN client is needed on devices behind Flint. If one is on anyway (Happ, for instance), its connections to the provider's servers go from Flint directly rather than through a second VPN, but such a device bypasses the router's geo filter, own sites and ad blocking: the client decides everything.
- Devices get their addresses from Flint (`192.168.8.x`). Names for them — on the "DNS → Local names" tab.
- **A device without VPN**: a TV, a console or a work laptop can be taken out of the VPN by MAC address on the Routing tab. It then goes online directly, but DNS ad blocking still applies to it (unless you also add it to "Devices without blocking").

## Access from the main router's network

`install.sh` allows incoming connections to Flint from `UPSTREAM_NET` — to the router itself and to the devices behind it (`192.168.8.x`). If the main router's network has changed, fix `UPSTREAM_IF` / `UPSTREAM_NET` in `config/flint.env` and redeploy. To open the Flint panel and the devices behind it from a computer on the main network, configure the main router (a TP-Link example, `http://192.168.0.1`):

| What | Where in the admin panel | Value |
|---|---|---|
| Static route | *Advanced → Network → Routing → Static Route* | network `192.168.8.0`, mask `255.255.255.0`, gateway — Flint's address on the main network |
| Port forwarding for the panel (when a route cannot be set) | *NAT Forwarding → Port Forwarding* | external port `81` → internal `81`, Flint's IP |

Flint's address on the main network is visible in its admin panel on the *Internet* page (or with `ip -4 addr show sta1`).

---

**Next:** [Installation](install.md) · [Servers and subscriptions](servers.md) · [DNS and ad blocking](dns-adblock.md) · [Telegram proxy](telegram-proxy.md) · [Maintenance](maintenance.md) · [Troubleshooting](troubleshooting.md) · [How it works](internals.md)
