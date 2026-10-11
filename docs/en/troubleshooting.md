# Troubleshooting

**Contents**
- [What to check first](#what-to-check-first)
- [Symptoms](#symptoms)
- [A server switch takes long or does not happen](#a-server-switch-takes-long-or-does-not-happen)
- [Forgotten PIN](#forgotten-pin)
- [Devices bypass the router](#devices-bypass-the-router)
- [Limitations](#limitations)

## What to check first

One request replaces half the guesswork:

```sh
ssh root@192.168.8.1 'flint-node list; flint-dns; flint-tg state; flint-adblock state'
```

And the logs:

```sh
logread -e xray          # Xray: connections, REALITY errors
logread -e flint-watchdog   # failover events
cat /etc/xray/watchdog-last # the last failover event
cat /etc/xray/sub-checked   # when the subscriptions were last checked
```

## Symptoms

| Symptom | What to check |
|---|---|
| `VPN: FAIL` at the end of install | is the subscription alive (Subscriptions tab); is `VLESS_UUID` correct for manual `nodes.conf` lines; is `DEFAULT_NODE` alive (try another: `flint-node <code>`); `logread -e xray` |
| `DNS: FAIL` | `/etc/init.d/flint-doh restart`, then `nslookup youtube.com 127.0.0.1`; does the router have internet |
| Panel doesn't open at `vpn.lan` | use `http://192.168.8.1:81/`; disable Private DNS / DoH on the device; `/etc/init.d/flint-ui restart` |
| No internet after switching servers | the server is down — pick another or enable failover; as a last resort turn the VPN off on the Status tab |
| A server fails though it works in Happ | the provider rotated keys or SNI — "Subscriptions → Update all subscriptions now" |
| A subscription is not added | "could not be downloaded" - open the link in a browser, check the router's internet; "no supported servers" - the subscription has no VLESS + REALITY (VMess, Trojan, Shadowsocks, XHTTP are not supported) |
| A Russian site goes via VPN | geoip/geosite missing (then `global` mode): `flint-geo-update`; or add the site as "direct" |
| A site or app broke with ad blocking on | turn blocking off to confirm; if it is the cause, allow the domain in "Sites without blocking" ("Recently blocked" gives a hint) or add the device to "Devices without blocking" |
| A NAS or other device of the main network doesn't open | find it in the main router's client list: it may have a new address after a reboot. Fix the address (DHCP reservation or static IP on the device) and update its name on the DNS → Local names tab |
| Ads are not blocked on a device | turn off Private DNS, browser DoH and any VPN client (Happ, etc.) on it; check it is not excluded |
| Telegram doesn't connect through the proxy | Telegram → Check the proxy: if every route shows `[FAIL]`, turn the Cloudflare fallback on or choose the route "Via VPN". Turn off any VPN client on the device; after changing the port, masking or secret, add the proxy to Telegram again. "On, but not running" — turn the proxy off and on again |
| The proxy says "on" but does not work, port 443 | port 443 on the router is taken by the firmware's nginx. Put the proxy port back to 1443: `flint-tg port 1443; flint-tg on` |
| Ads remain on VK, YouTube, etc. | they come from the same domain as the content and DNS blocking can't remove them — install uBlock Origin in the browser (see [Where ads remain](dns-adblock.md#where-ads-remain)) |
| `opkg install ... failed` | `/tmp/flint-opkg.log`; router internet; put Xray into `backup/bin/xray` |
| The VPN and panel are gone after a firmware upgrade | upgraded without Keep Settings — `.\restore.ps1 -Full`; with it — redeploy, the settings in `/etc/xray` were kept (see [Firmware upgrade](maintenance.md#firmware-upgrade)) |
| The Status tab shows `n/a` instead of the addresses | the router could not learn its external address: `curl -s -m 8 https://ifconfig.me` on the router. If that service is unreachable, set your own in `IP_LOOKUP` (`/etc/xray/flint.env`), for example `https://api.ipify.org` |
| The encrypted DNS stopped answering and another DoH server does not help | the resolver's **name** is what is blocked, so trying DoH servers is pointless. Switch to DNSCrypt or to the tunnel mode (see [When the encrypted DNS stops working](dns-adblock.md#when-the-encrypted-dns-stops-working)) |

## A server switch takes long or does not happen

Switching a server restarts Xray, and Xray takes the interception port (**12345**) **without** `SO_REUSEADDR`. Sockets that devices left in `TIME_WAIT` (the kernel keeps each for about a minute; on a busy network there are 12–13 at a time) keep the new process from taking the port: the log shows `address already in use` while nothing is listening. Those sockets cannot be forced away — `conntrack` does not track the redirected LAN traffic, this firmware has no `ss -K`, `tcp_tw_reuse` affects outgoing connections only, and Xray 26 ignores the unknown `reusePort` key.

What the router does about it: it waits for the port in four rounds of a minute each and only then gives up. If it does give up, **the config and the previous server stay as they were** and the panel shows the message; repeat the switch a minute or two later, once the sockets expire.

What you can do:

- wait a minute and try again — that is usually enough;
- lower the number of simultaneous connections around the switch (pause downloads and video for a moment);
- if switches get in the way, turn failover on: then the watchdog changes servers instead of you, and it does so while the tunnel is down anyway.

Separately: **the watchdog leaves a fresh server switch alone for two minutes** (`/etc/xray/switch-at`). Otherwise it would see the brief drop from the restart, take the new server for a dead one and move off it — which is why the panel used to show the previous server.

## Forgotten PIN

See the current one:

```sh
ssh root@192.168.8.1 "grep UI_PIN /etc/xray/flint.env"
```

Set a new one (here `1234`, letters and digits only) — it works at once, nothing needs a restart:

```sh
ssh root@192.168.8.1 "sed -i '/^UI_PIN=/d' /etc/xray/flint.env && echo UI_PIN=1234 >> /etc/xray/flint.env"
```

Put it into `config/flint.env` too, or the next deploy brings the old PIN back. Or just redeploy — the PIN becomes the one in `config/flint.env`.

## Devices bypass the router

- **Android:** *Settings → Network → Private DNS → Off*, otherwise the phone bypasses the router's DNS.
- **Windows:** in the Wi‑Fi properties set *DNS server assignment → Automatic (DHCP)*; otherwise DoH bypasses the router's DNS and local names (`nas01`) don't resolve.
- **Browsers** with secure DNS (DoH) also bypass the router's DNS — the geo filter and own sites by domain still work (Xray reads the domain from TLS), local names and ad blocking don't.
- **A VPN client on a device** (Happ, v2rayN, Hiddify) puts all traffic into its own tunnel: neither the router's VPN nor ad blocking nor own sites apply. Behind Flint such a client is not needed — turn it off.

## Limitations

- **TCP only.** Through the VPN goes TCP; QUIC (UDP 443) is blocked so browsers and apps fall back to TCP. The rest of UDP (games, calls in some apps) goes directly. Devices without VPN keep QUIC.
- **IPv6 is not tunnelled.** If the main router hands out IPv6, disable it for the Flint network, otherwise some traffic goes past the VPN.
- **Xray.** The kit pins release `v26.3.27` (`XRAY_VERSION`), installed with a SHA-256 check, and the previous binary is kept in `/usr/bin/xray.previous`. This matters beyond new transports: versions below v25.6.8 do not imitate the cover site's post-handshake records, and REALITY in them can be told apart by active probing. **The server has to be updated too**: if the provider's server is older than v25.6.8, updating the router alone changes nothing. The XHTTP transport works on the router but needs support on the server side.
- **The panel is for the home network:** plain HTTP, the PIN travels in the request URL. Never expose port 81 to the internet.
- **Changing the VPN settings drops connections for a few seconds.** An Xray restart is needed to apply a new config. Some changes apply without a restart: own sites, devices without VPN, ad blocking lists and rules, DNS, local names.

---

**Next:** [Installation](install.md) · [Web panel](panel.md) · [Servers and subscriptions](servers.md) · [DNS and ad blocking](dns-adblock.md) · [Telegram proxy](telegram-proxy.md) · [Maintenance](maintenance.md) · [How it works](internals.md)
