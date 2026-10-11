# DNS and ad blocking

Two related parts: how the router resolves names (DNS) and how it removes ads at that name level (AdGuard Home).

**Contents**
- [DNS modes](#dns-modes)
- [Local names](#local-names)
- [When the encrypted DNS stops working](#when-the-encrypted-dns-stops-working)
- [Ad blocking](#ad-blocking)
- [Filter lists](#filter-lists)
- [Own rules and exclusions](#own-rules-and-exclusions)
- [Where ads remain](#where-ads-remain)
- [Who bypasses the blocking](#who-bypasses-the-blocking)

## DNS modes

Every device's DNS queries go to the router (the firewall redirects them whatever the device is set to). The router then asks an upstream server — the DNS tab of the panel, four modes:

- **DoH** (the default) — encrypted DNS over HTTPS: Cloudflare, Google, Quad9, AdGuard DNS or your own `https://dns.example.com/dns-query`.
- **DNSCrypt** — another encryption protocol, the fallback when DoH is blocked on your line: AdGuard DNS, Quad9, dnscry.pt (Moscow, Stockholm) or your own `sdns://…` stamp from the [dnscrypt.info](https://dnscrypt.info/public-servers) list.
- **Plain (UDP)** — open DNS, the provider sees the queries: Cloudflare, Google, Quad9, AdGuard DNS, Yandex, the main router's DNS or your own IPs.
- **Through the tunnel** — the router resolves through the VPN. It helps when the provider blocks DoH and DNSCrypt by the resolver's name. It needs a working VPN and Xray v25.6.8 or newer on the server; with the VPN off the mode does not work and the watchdog puts DoH back and says so in the log. The mode is marked **experimental**: some servers do not answer through the tunnel, and the router then returns to the previous mode by itself.

Each mode keeps its own server, so switching modes does not reset it. The router checks the new DNS and keeps the previous one if it did not answer. Current mode: `flint-dns mode`; that answers come back: `flint-dns answercheck`; the Xray DNS inbound itself (without dnsmasq): `flint-dns forwardercheck`.

## Local names

"DNS → Local names" in the panel: the name (`nas01`) and the device IP. `nas01`, `nas01.lan` and `nas01.local` all work; a name with a dot (`nas.home`) is used as is. Adding the same name again changes its address. Local names live in `/etc/xray/dns-hosts`, travel with a backup and the settings file, and need no dnsmasq restart.

## When the encrypted DNS stops working

When the provider starts blocking encrypted DNS, it looks like "sites stopped opening" while the internet works. The order to try:

1. **Check that it is DNS:** `nslookup youtube.com 127.0.0.1` on the router. If there is no answer while `curl https://1.1.1.1` works, DNS is indeed being blocked.
2. **Changing the server inside DoH hardly helps.** What gets blocked is not an address but the **name** of the resolver (`cloudflare-dns.com` and the like): every DoH server is reached by name, and it falls under the same rule. Do not waste time on it.
3. **DNSCrypt** — a different protocol and different names, often gets through where DoH no longer does.
4. **"Through the tunnel"** — the query goes inside the VPN, and the provider sees neither the name nor the address of the resolver at all. The most reliable option, **if** your server resolves on its own. The mode is experimental: when there is no answer the router rolls back by itself.
5. **Plain UDP** (`1.1.1.1`, `8.8.8.8`) — the last resort when nothing else gets through: addresses are not encrypted, the provider sees them and can substitute answers.

## Ad blocking

Works at the DNS level for every device on the network, with no apps on the devices. It uses AdGuard Home, which already ships with GL.iNet firmware 4.x (`/usr/bin/AdGuardHome`): the project runs its own instance on `127.0.0.1:5054`. The stock AdGuard Home from the GL admin panel stays off — don't turn both on.

How it works:
- with blocking on, the firewall (`FLINT_DNS` chain) sends client DNS queries to AdGuard Home, which forwards them to dnsmasq, so local names and DoH keep working;
- devices in "Devices without blocking" (by MAC address) go straight to dnsmasq;
- every 2 minutes cron checks that AdGuard Home answers. If not, it restarts it, and if that fails, DNS bypasses it until it is back. The ad blocker never takes the internet down;
- the AdGuard Home web UI is not exposed (`127.0.0.1` only); everything is managed from the panel.

AdGuard Home uses 40–60 MB of RAM; with blocking off it is stopped.

**After a restore from a backup** the blocking comes back on its own: the filter list URLs, your rules and exclusions live in `/etc/xray` and are part of a backup and of the settings file, while the downloaded filter cache in `/etc/flint-adguard` is not (4–5 MB of flash, and it goes stale anyway). AdGuard Home downloads the lists again on its first start, so blocking works without you doing anything; only the last-24-hours statistics and "Recently blocked" start empty and fill up as requests come in. To make it quicker, press "Update the lists now".

## Filter lists

The default is [AdGuard DNS filter](https://github.com/AdguardTeam/AdGuardSDNSFilter): the DNS version of the filters in paid AdGuard products (Base, Tracking Protection, Mobile Ads, Russian and other regional ad servers, EasyList, EasyPrivacy). It is free and open. The panel adds ready-made lists from the [AdGuard registry](https://github.com/AdguardTeam/HostlistsRegistry) (Popup Hosts, HaGeZi Pro, OISD, Steven Black, phishing and malware protection) or any list by URL in AdGuard/Adblock or hosts format. More lists mean more false positives, so start with one.

**Updates.** Lists update automatically — once a day by default, from every hour to once a week, or off — and with the "Update the lists now" button.

## Own rules and exclusions

| What you enter | Result |
|---|---|
| `ads.example.com` or a link, "Block" | the domain is blocked with its subdomains (`\|\|ads.example.com^`) |
| the same, "Allow" | an exception (`@@\|\|ads.example.com^`) when a list blocks a site you need |
| `\|\|ads.*^`, `/^ad[0-9]+\./`, `@@\|\|site.com^` | a rule in [AdGuard syntax](https://adguard-dns.io/kb/general/dns-filtering-syntax/) as is |

Rules take effect in a few seconds.

**Sites without blocking.** If blocking broke a site you need, add it to "Sites without blocking" — the same "Allow" rule for a domain with its subdomains, kept as a separate list. Below it, "Recently blocked" lists the latest blocked domains with the device name, each with an Allow button. The query log is kept in memory only (the last 1000 queries); nothing is written to flash.

## Where ads remain

DNS blocking sees only the names of the sites a device connects to, not the page content. Hence the limits:

- **Ads from the same domain as the content stay.** VK (ad blocks in the feed and the left column), YouTube (pre-roll and mid-roll ads), Instagram, Facebook, Yandex search and Dzen serve ads from their own servers together with the feed, and the ad images come from the same hosts as post photos. DNS can block such ads only together with the site itself, so a "Block" rule for `vk.com` or `youtube.com` will not help — it just breaks the site.
- **Page elements are not hidden.** An empty frame or placeholder may stay where a blocked banner was.
- **In-app ads** (YouTube on a TV, social network apps on a phone) are removed only partly, for the same reason.

On such sites only a blocker on the device itself helps: the [uBlock Origin](https://ublockorigin.com/) extension in a desktop browser, Firefox with uBlock Origin on Android. It hides ad blocks right on the page and complements the router nicely: the router closes ad and tracker domains for every device, TVs and apps included, and the extension handles what comes from the site itself.

## Who bypasses the blocking

Devices whose DNS queries skip the router:

- Android with Private DNS on;
- browsers with secure DNS (DoH): Chrome, Edge, Firefox, Yandex Browser;
- devices running a VPN client (Happ, v2rayN, Hiddify, etc.): DNS and all traffic go into its tunnel, so neither the blocking nor the router's VPN apply. Behind Flint a VPN client isn't needed — turn it off.

If a site you need broke after turning blocking on, add it to "Sites without blocking" or add the device to "Devices without blocking".

---

**Next:** [Installation](install.md) · [Web panel](panel.md) · [Servers and subscriptions](servers.md) · [Telegram proxy](telegram-proxy.md) · [Maintenance](maintenance.md) · [Troubleshooting](troubleshooting.md) · [How it works](internals.md)
