# Telegram proxy

An MTProto proxy on the router — [tg-ws-proxy-rs](https://github.com/valnesfjord/tg-ws-proxy-rs), the Rust version of [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy). The Telegram app connects to the router as to a regular MTProto proxy, and the router reaches Telegram through its web servers over WebSocket on top of TLS — the same way Telegram Web does in a browser. The provider sees an HTTPS connection to a Telegram web server, not the MTProto protocol, which gets cut by its signature.

**Contents**
- [Why it is needed](#why-it-is-needed)
- [Turning it on](#turning-it-on)
- [How it works](#how-it-works)
- [How it is set up on the router](#how-it-is-set-up-on-the-router)
- [Where the proxy comes from](#where-the-proxy-comes-from)
- [What does not go through the proxy](#what-does-not-go-through-the-proxy)
- [Switches](#switches)
- [Resources, backup, firmware](#resources-backup-firmware)

## Why it is needed

With the VPN on, Telegram on devices behind Flint works anyway: its servers are not Russian, so the geo filter sends them through VLESS. The proxy is for when Telegram has to work **without the VPN**:

- on **devices without VPN** (Routing → Devices without VPN) — their traffic bypasses Xray, and the provider may slow Telegram down or break it;
- while the **VPN is off** or the subscription servers are down — Telegram keeps working through the proxy;
- **without spending subscription traffic** — photos, videos and files bypass VLESS (the "Directly" route);
- **away from home**, with access from the internet open: a phone on mobile data reaches Telegram through the home router.

While the proxy is off, or until it is added in Telegram on the device, Telegram follows the router's usual rules like any other traffic.

## Turning it on

1. "Telegram → Turn the proxy on". The proxy is already on the router (the deploy installs it), so it starts at once; the panel waits until it listens on the port.
2. Open the Telegram tab on a device with Telegram and press **"Add to Telegram"** — Telegram offers to connect the proxy itself. The `t.me` button next to it is the same link through the Telegram site, in case the app did not open the `tg://` one.
3. By hand: *Settings → Data and storage → Proxy → Add proxy → MTProto*; the server, port and secret come from the same tab.

There are up to three links, each with its own server address:

| Link | Server | For whom |
|---|---|---|
| On the Flint network | `192.168.8.1` (the router's LAN address) | devices on Flint's Wi‑Fi or LAN |
| On the main router's network | Flint's address on the main network, e.g. `192.168.0.111` | devices on the main router's Wi‑Fi; present when `UPSTREAM_NET` is set |
| From the internet | the provider IP or your own domain | a phone away from home; present when access from the internet is on |

## How it works

```
 Telegram (phone, PC)
    │  MTProto, obfuscated with the secret (dd…), masked — inside a TLS wrapper (ee…)
    ▼
 Flint :1443 ── tg-ws-proxy ─┬─► WebSocket over TLS :443 → kwsN.web.telegram.org ─► Telegram data center
                             ├─► fallback: Cloudflare (kwsN.<domain from the list>)  ─► Telegram data center
                             └─► last resort: TCP :443 straight to the data center
    "Via VPN": every outgoing connection of the proxy goes into Xray (HTTP inbound 127.0.0.1:1087) ─► VLESS
```

1. **The connection to the router.** Telegram opens a TCP connection to the proxy port (1443). The address is inside the network, so Xray leaves it alone even when the device itself goes through the VPN.
2. **Handshake and secret.** The first 64 bytes are an obfuscated MTProto handshake. The proxy checks the secret in them and learns the data center (DC) number and the connection type: ordinary or media (photos, videos, files). A connection without the right secret is dropped, so knowing the address and port is not enough to use the proxy.
3. **The bridge into WebSocket.** The proxy opens `wss://kwsN.web.telegram.org/apiws` — Telegram Web's entry for data center N. TCP goes to the data center's IP while TLS names the web server, so from the outside it looks like an ordinary HTTPS connection to Telegram Web. The stream is re-encrypted with AES-256-CTR (client keys ↔ bridge keys). The proxy cannot see the content of a conversation: Telegram encrypts it, and the proxy passes already encrypted data.
4. **Connection pool.** It keeps 4 pre-opened WebSocket connections per data center, so new chats and downloads do not wait for a TLS handshake.
5. **Fallback routes.** Every connection takes the first route that works: direct WebSocket → Cloudflare (when the fallback is on) → a direct TCP connection to the data center on port 443. The Cloudflare fallback uses the shared domain list of the tg-ws-proxy project: the proxy downloads it from GitHub at startup and falls back to a short built-in list when GitHub is unreachable. The same `kwsN` entries sit behind those domains, but the provider sees a connection to Cloudflare. When TCP to a data center address hangs until timeout — the usual shape of a DPI block — the proxy skips that address for an hour and goes to the fallback at once. A refused connection does not count as a skip. If the fallbacks fail too, the address is tried again, and the first successful direct connection clears the skip.
6. **The route to Telegram.** "Directly" means the proxy reaches the internet as the router itself: the router's own traffic is not sent into Xray (interception works only for LAN traffic), so no VPN traffic is spent. "Via VPN" sends every outgoing connection of the proxy, Cloudflare fallback included, into Xray's HTTP inbound on `127.0.0.1:1087`, and Xray routes them by its rules: Telegram addresses are not Russian, so through VLESS. With the VPN off or no servers, the proxy switches to "Directly" by itself and comes back when the VPN is on again.
7. **Masking (FakeTLS).** With it the proxy accepts only clients whose secret is `ee…`: the phone's connection to the router begins as a TLS handshake with the given site (e.g. `www.google.com`). This protects the "phone → router" leg when it crosses the internet and a mobile operator. Masking does not change the router's path to Telegram.

## How it is set up on the router

| What | Where |
|---|---|
| The proxy | `/usr/bin/tg-ws-proxy` — a static aarch64 binary (3.8 MB). Installed on every deploy from the `kit/bin/` archive |
| The service | `/etc/init.d/flint-tgproxy` (procd, restarts on crash). Enabled at boot only while the proxy is on in the panel |
| Settings | `/etc/xray/tgproxy`, mode 600: `state`, `route`, `cf`, `remote`, `addr`, `mask`, `port`, `secret`, `dc`, `cfdomain`, `worker`, `cftls`, `pool`, `log` |
| Control | `flint-tg` — used by the panel, `install.sh` and `firewall.user` |
| Firewall | from the Flint network the router's ports are open through the `lan` zone; from the main router's network through the `Allow-Upstream-LAN-to-Router` rule; from the internet through `Allow-Flint-Telegram-Proxy` (`firewall.flint_tg_remote`), which exists only while access from the internet is on and follows a port change |

Details:

- **The launch parameters** are assembled by `flint-tg args`: `--host 0.0.0.0 --port <port> --link-ip <LAN address>`, plus `--default-domains` (Cloudflare fallback), `--listen-faketls-domain <site>` (masking) and `--outbound-proxy http://127.0.0.1:1087` (the vpn route, while the VPN works). The secret goes through the `TG_SECRET` environment variable, so it does not show in `ps`.
- **Synchronisation.** `flint-tg sync` runs at the end of `/etc/firewall.user`, that is when the VPN is turned on or off, when the server changes, when the firewall reloads and at boot. It restarts the proxy only when the launch parameters or the secret changed (the last applied ones are remembered in `/tmp/flint-tg.applied`), so open Telegram connections are not dropped for nothing.
- **The secret** is 16 random bytes (32 hex characters), created on first use. The link: `tg://proxy?server=<address>&port=<port>&secret=dd<secret>`, with masking `secret=ee<secret><site domain in hex>`.
- **The check** ("Check the proxy", `flint-tg check`) starts a second copy of the proxy with the same settings on the next port (`port + 1`, `127.0.0.1` only) with the `--check-listener` flag. That copy connects to itself as a Telegram client — the handshake, a `req_pq_multi` request, a `resPQ` answer from the data center — checks the Cloudflare domains and prints `[OK]` / `[FAIL]` lines for each route. The running proxy is not touched.

## Where the proxy comes from

So as not to depend on the project on GitHub being alive, the release archive is kept in this repository: `kit/bin/tg-ws-proxy-aarch64-unknown-linux-musl.tar.gz` (v2.5.2) and its MIT licence in `kit/bin/tg-ws-proxy-LICENSE`. The deploy uploads it with the kit, `install.sh` checks the archive's SHA-256 against the sum in `flint-tg` and installs `/usr/bin/tg-ws-proxy`. If the archive is missing or damaged, the install continues without the proxy, and `flint-tg on` (the panel button) downloads the same archive from GitHub — through the VPN first, then directly — and checks the same sum. A foreign or modified file is never installed.

**To update the proxy to a newer version:**

1. Download `tg-ws-proxy-aarch64-unknown-linux-musl.tar.gz` from the [tg-ws-proxy-rs releases](https://github.com/valnesfjord/tg-ws-proxy-rs/releases) and replace the archive in `kit/bin/`.
2. In `kit/files/usr/bin/flint-tg` change `VERSION` and `SHA256` (the archive sum: `Get-FileHash <file> -Algorithm SHA256` or `sha256sum <file>`; GitHub shows it next to the file in the release).
3. Redeploy. The proxy restarts on the new version with the same settings and secret — the links in Telegram do not need changing.

## What does not go through the proxy

- **Telegram calls.** An MTProto proxy does not carry them. Calls follow the network's usual rules: UDP behind Flint is not tunneled and goes directly.
- **Telegram Web in a browser.** It is an ordinary site and follows the router's rules — via the VPN, if it is on.
- **Devices where the proxy is not added in Telegram.** The proxy is not transparent: it works only once set up in the app.

## Switches

| Setting | What it does |
|---|---|
| Route to Telegram | **directly, bypassing the VPN** (default) or **via VPN** — when the provider blocks Telegram's web servers too. While the VPN is off, the proxy goes directly anyway |
| Cloudflare fallback | if Telegram's servers are not reachable, the proxy goes to them through Cloudflare, using the shared domain list of the tg-ws-proxy project (on by default) |
| Access from the internet | opens the proxy port in the WAN zone, so Telegram on a phone works through the home router away from home. Needs a TCP port forward on the main router to Flint's address there and a public IP from the provider (it won't work behind CGNAT). The address in the link is the provider IP or your own domain (DDNS) |
| Port | 1443 by default |
| Masking (FakeTLS) | connections to the proxy look like HTTPS to the given site (a link with an `ee…` secret). Turn it on when the proxy is open to the internet: without it a mobile operator may spot the proxy |
| New secret | the old links stop working |
| Own secret | 32 hex characters, e.g. from the desktop tg-ws-proxy, so Telegram keeps its secret (a secret with `dd`/`ee` in front works too) |
| Data center addresses | number:IP, comma-separated (`--dc-ip`): the addresses the proxy connects to directly. Empty: the built-in ones (DC2 and DC4) |
| Cloudflare: own domains | domains on your Cloudflare (`--cf-domain`), tried before the shared list |
| Cloudflare Worker | your Worker domains (`--cf-worker-domain`): the last fallback, a TCP tunnel to Telegram |
| TLS to Cloudflare | off means `ws://` on port 80 (`--cf-disable-tls`), only for providers that cut TLS to Cloudflare |
| WebSocket pool | how many connections to each data center to keep open in advance (`--pool-size`, 4 by default) |
| Proxy log | off, on or verbose (`--verbose`); goes to the router's in-memory system log (`logread -e tg-ws-proxy`), the last lines show on the tab |
| Check for updates | compares the installed version with the latest on GitHub. It does not update by itself: the version is pinned in the kit, see [Where the proxy comes from](#where-the-proxy-comes-from) |

The desktop tg-ws-proxy's "Buffer, KB" is not carried over: the Rust version accepts it but does not use it.

After changing the port, masking or secret, add the proxy to Telegram again. "Check the proxy" starts a second copy of the proxy with the same settings, walks the whole path — from a client connection to an answer from Telegram's servers — and shows the result for each route (`[OK]` / `[FAIL]`).

## Resources, backup, firmware

- The proxy takes 3–5 MB of memory and 3.8 MB of flash; it is stopped while off.
- Its settings and secret (`/etc/xray/tgproxy`) go into backups and the panel's settings file and come back with `restore` — the links in Telegram keep working after a restore.
- A firmware upgrade with Keep Settings keeps the proxy along with the rest of the kit (see [Maintenance](maintenance.md#firmware-upgrade)). Without it a redeploy installs the proxy again from `kit/bin/`, with no internet needed for that.
- `uninstall` stops the proxy and removes the binary, the service and the firewall rule.

---

**Next:** [Installation](install.md) · [Web panel](panel.md) · [Servers and subscriptions](servers.md) · [DNS and ad blocking](dns-adblock.md) · [Maintenance](maintenance.md) · [Troubleshooting](troubleshooting.md) · [How it works](internals.md)
