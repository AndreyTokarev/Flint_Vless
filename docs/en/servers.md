# Servers and subscriptions

How the router gets servers, how to choose between them, and what to do when one goes down.

**Contents**
- [Servers by hand](#servers-by-hand)
- [Subscriptions](#subscriptions)
- [Failover](#failover)
- [TLS fingerprint and multiplexing](#tls-fingerprint-and-multiplexing)

## Servers by hand

The router builds subscription servers by itself (`flint-sub-update`). `config/nodes.conf` holds only manually set servers; when the file exists, a deploy uploads it to the router, otherwise the router keeps its copy.

From subscriptions VLESS + REALITY over TCP (xtls-rprx-vision) is imported, including bare-IP servers, which go to the "white lists" block. gRPC only with `SUB_GRPC=1`. Provider announcements disguised as servers (names starting with ❗) are skipped.

Line format:

```
code  address  sni  pbk  sid  [uuid]  [port]  [tcp|grpc]  [serviceName]
```

An empty field is `-`; `uuid` defaults to `VLESS_UUID`, port to `443`, transport to `tcp`. The comment line above a server is its panel name; a flag emoji at the start of the name becomes the country code.

**Own servers** added in the panel are stored separately on the router, in `/etc/xray/nodes-custom.conf`, with codes `my1`, `my2`… Subscription updates don't touch them. A server from a subscription cannot be edited directly (the next update would overwrite the change), but it can be copied into your own servers and the copy edited.

## Subscriptions

You can have several subscriptions from different providers: add, change and delete them on the Subscriptions tab or with `flint-sub-update`. A regular subscription link from Happ, v2rayN or Hiddify works — a list of `vless://` links (plain or base64). On the first run `SUB_URL` from `flint.env` becomes the first subscription.

- A subscription is added only if it downloads and has supported servers (VLESS + REALITY).
- Each subscription's servers live in `/etc/xray/nodes.d/<id>.conf`, own servers in `nodes-custom.conf`, manual ones in `nodes.conf`. When codes clash, the second server gets a number: `de`, `de2`.
- If a subscription fails to download during an update, its servers stay as they were and the panel shows the error.
- The default subscription name comes from the `profile-title` header, the expiry and traffic from `subscription-userinfo` (most providers send them for Happ).
- The hosts of all subscriptions bypass the VPN, so refreshing works even when the current server is down.
- The list lives in `/etc/xray/subscriptions` (links carry a token, keep it secret); a backup copies it to `config/subscriptions`.
- There may be no subscriptions at all, e.g. right after an install without `SUB_URL` or after deleting the last one. With no own servers either, Xray stays down and devices go online directly; the Status tab shows it. The first subscription or own server added turns the VPN on by itself.

The auto-update interval is 30 minutes, 1, 3, 6, 12 or 24 hours, or off. The update runs from cron and does not depend on the panel.

## Failover

`flint-watchdog` runs from cron every 2 minutes:

1. it checks the tunnel (a request to `generate_204` through Xray);
2. on failure it waits 10 seconds and checks again;
3. if the direct internet works (so it's the server, not the ISP), it refreshes the subscription and checks again;
4. if the current server still fails, it tries the others in order and stays on the first working one, or returns to the original if none works.

The last result is shown in the panel and in `/etc/xray/watchdog-last`. Turn it off in the panel or with `flint-watchdog off`. With the VPN off the watchdog does nothing.

**After a manual server change** the watchdog stays quiet for two minutes: a switch restarts Xray, the tunnel needs a few seconds, and a check in that moment would otherwise take a working server for a dead one and move off it. The time of the switch is written to `/etc/xray/switch-at`.

**Which server to take on failure.** By default the first one in the list. On the Servers tab you can turn on "Switch to the fastest": the router then measures the connection time to every server (`flint-node probe`, using the same SNI as the working tunnel) and on failure walks the list from the quickest to the slowest, stopping at the first one that really answers. The measurement only changes the order — servers that did not answer are still tried, last. The rule is also a command: `flint-node probe-mode fastest` or `first`.

## TLS fingerprint and multiplexing

Both settings are on the Servers tab and in the commands `flint-node fingerprint` and `flint-node mux`.

- **The fingerprint** (`firefox` by default) is the browser the router claims to be to the REALITY server. If your provider has started to be picky about the connection, trying `chrome`, `safari` or `edge` is worth it.
- **Mux is off by default** and is worth turning on deliberately: according to the [Xray documentation](https://xtls.github.io/config/outbound.html) it reduces the number of handshakes but does not raise the speed, and usually lowers it for video and downloads. When you turn it on, the router first checks that traffic goes through the tunnel and turns mux back off by itself if a page does not load. On a check with one provider, traffic through the tunnel with mux on did not flow at all.

Both live in `/etc/xray/xray-opts` and travel with a backup and with the settings file.

---

**Next:** [Installation](install.md) · [Web panel](panel.md) · [DNS and ad blocking](dns-adblock.md) · [Telegram proxy](telegram-proxy.md) · [Maintenance](maintenance.md) · [Troubleshooting](troubleshooting.md) · [How it works](internals.md)
