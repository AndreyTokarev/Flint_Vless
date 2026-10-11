# How it works

Technical detail: what happens to traffic, what the project consists of, where everything lives and what about security.

**Contents**
- [Diagram](#diagram)
- [What happens to traffic](#what-happens-to-traffic)
- [Project layout](#project-layout)
- [Where everything lives on the router](#where-everything-lives-on-the-router)
- [Services](#services)
- [Versions and updates](#versions-and-updates)
- [Security](#security)
- [Contributing](#contributing)

## Diagram

```
 Phone / laptop / TV
          │  Wi-Fi or LAN, nothing to configure
          ▼
 ┌──────────────── Flint (OpenWrt) ────────────────┐
 │ DNS: [AdGuard Home] ──► dnsmasq ──► DoH         │
 │ iptables: TCP from br-lan ──► Xray :12345       │
 │           (devices without VPN — directly)      │
 │ Xray: Russia and own "direct" ──► direct        │
 │       everything else ──► VLESS + REALITY       │
 │ uhttpd :81 ──► web panel (CGI)                  │
 └─────────────────────────────────────────────────┘
          │
          ▼
 Main router ──► internet
```

## What happens to traffic

- `iptables` rules (through `/etc/firewall.user`) send LAN client TCP traffic into Xray's `dokodemo-door`. Local and private networks, and the VPN servers' addresses, bypass it.
- DNS queries from devices are forced to the router. With ad blocking on they hit AdGuard Home first, otherwise dnsmasq straight away; then dnscrypt-proxy (DoH or DNSCrypt) or, in UDP mode, the chosen DNS servers directly.
- QUIC (UDP 443) is blocked so browsers and apps fall back to TCP and end up in the tunnel. The rest of UDP goes directly. Devices without VPN keep QUIC.
- The Xray config is built from the `/etc/xray/template.json` template by `flint-node`: the chosen server, the geo filter, own sites. Before it is applied the config goes through `xray -test`, after it the exit IP is checked. If a new config does not come up, the previous one is put back.
- The router's own traffic (subscription and package updates) goes directly: interception only covers traffic from the local network.

## Project layout

| Path | What it is |
|---|---|
| `kit/install.sh` | the installer, runs on the router; safe to run again |
| `kit/state-files` | the list of user files in `/etc/xray` that a backup, a restore and a deploy carry |
| `kit/files/usr/share/flint/settings-files` | the list of files the panel's settings file carries; the `settings` scenario checks it against `state-files` |
| `kit/files/usr/share/flint/panel/` | the parts of the web panel: `ui.sh` (markup, language switch, the PIN gate, the settings export) and one file per tab (`status.sh`, `subs.sh`, `servers.sh`, `own.sh`, `dns.sh`, `routing.sh`, `adblock.sh`, `telegram.sh`, `settings.sh`). `panel.cgi` sources them; they are fragments rather than scripts, so the syntax check skips them |
| `tests/` | the scenarios that run on a router (`empty`, `redeploy`, `subscription`, `own-server`, `failover`, `panel`, `settings`, `adblock`): `tests/run.ps1` / `tests/run.sh` uploads the working copy and the install and the scenarios run in the background on the router, so a dropped connection does not interrupt them. Running the same code with the same scenarios again does not start over but reads the run that is already going or finished (`-Force` / `--force` starts it again). A scenario keeps a copy of `/etc/xray` and puts it back at the end (most of them delete every server on the way); only one runs at a time |
| `kit/migrate.sh` | migrates from older kit versions; `install.sh` calls it |
| `kit/files/` | the files for the router: the Xray template, init scripts, firewall, the `flint-*` commands (server, subscriptions, own servers, failover, ad blocking, DNS, Telegram, settings), the web panel |
| `kit/bin/` | the Telegram proxy archive (tg-ws-proxy-rs for aarch64) and its licence: a deploy installs the proxy from here instead of downloading it |
| `config/*.example` | sample settings |
| `config/flint.env`, `config/nodes.conf` | **your** settings and secrets — never in git |
| `config/nodes-custom.conf`, `config/custom-sites`, `config/subscriptions`, `config/adblock-*` | own servers, sites, subscriptions, ad blocking lists and rules from the panel; they appear after a backup |
| `deploy.ps1` / `deploy.sh` | upload the kit to the router and install it |
| `backup.ps1` / `backup.sh` | back the router up into `backup/` |
| `restore.ps1` / `restore.sh` | restore from `backup/` |
| `uninstall.ps1` / `uninstall.sh` | remove Flint VPN from the router (on the router use `kit/uninstall.sh`) |
| `fix.ps1` | one command that repairs: check the router, put DNS back on a working mode, deploy the kit and run the tests |
| `tools/run-tests.ps1` | upload the kit and run every scenario on the router, showing the output (independent of the working directory and of temporary variables) |
| `tools/check.ps1` | what the CI job does, on a developer machine: syntax, CRLF, the Xray template, secrets, shellcheck |
| `tools/screenshot.js` | panel screenshots through a headless browser for the README (`tests/demo.sh` prepares the pages) |
| `tools/check-secrets.sh` | refuse to commit a subscription link, the panel PIN, a Wi-Fi password or a private key |
| `tools/check-scripts.sh` | the checks that need no router: shell syntax, CRLF, the Xray template |
| `kit/VERSION` | the version number |
| `CHANGELOG.md` | the change history |
| `docs/` | this documentation, screenshots and the logo; finished audits and plans are in `docs/archive/` |

## Where everything lives on the router

| Path | What |
|---|---|
| `/etc/xray/` | settings and state: `template.json`, `config.json`, `nodes.conf`, `nodes.d/`, `nodes-custom.conf`, `subscriptions`, `current-node`, `flint.env`, `xray-opts`, `tgproxy`, the ad blocking lists and rules, `watchdog-last`, `switch-at`. Mode `600`; part of a backup |
| `/www/flint/` | the panel: `index.html`, `panel.css`, `cgi-bin/panel.cgi` |
| `/usr/share/flint/` | `lib.sh` (the shared library), `panel/` (panel parts), `settings-files`, `state-files`, `version` |
| `/usr/bin/flint-*` | the commands: `flint-node`, `flint-custom`, `flint-sub-update`, `flint-watchdog`, `flint-adblock`, `flint-dns`, `flint-tg`, `flint-settings`, `flint-geo-update` |
| `/etc/init.d/flint-*`, `/etc/init.d/xray` | procd services |
| `/etc/firewall.user` | traffic interception, DNS, QUIC blocking, access from the main router's network |
| `/lib/upgrade/keep.d/flint` | what to keep on a firmware upgrade with Keep Settings |
| `/etc/flint-adguard/` | the downloaded AdGuard Home list cache (not part of a backup) |

## Services

| Service | Port | What it does |
|---|---|---|
| `xray` | 12345 (interception), 1087 (HTTP inbound for the Telegram proxy) | the VLESS + REALITY tunnel and routing |
| `flint-ui` | 81 | the panel (`uhttpd` with CGI) |
| `flint-doh` | 5053 | dnscrypt-proxy: DoH or DNSCrypt |
| `flint-adblock` | 5054 (API 3054, `127.0.0.1` only) | AdGuard Home: ad blocking |
| `flint-tgproxy` | 1443 | the Telegram proxy |

Every service is procd-managed and restarts on crash. The watchdog and the subscription, list and geo database updates run from cron.

## Versions and updates

On the router the version is shown at the bottom of the panel menu and in `/usr/share/flint/version`; a deploy prints which version it installs and which one was there. Versions follow [SemVer](https://semver.org): `1.2.3` is major (incompatible changes), minor (new features), patch (fixes). The number is in `kit/VERSION`, every version has a `vX.Y.Z` git tag, and the changes are in [CHANGELOG.en.md](../../CHANGELOG.en.md).

Updating is a `git pull` and a redeploy — see [Maintenance](maintenance.md#updating-the-project).

## Security

- UUIDs, the PIN, subscription links and servers are kept only in `config/flint.env`, `config/nodes*.conf`, `config/subscriptions` and `backup/` — all of them are in `.gitignore`. Before publishing a fork, check that they did not get into commits.
- On the router these files live in `/etc/xray/` with mode `600`.
- The panel listens on port 81. The firewall lets in only the Flint LAN and the main router's network (`UPSTREAM_NET`); any other traffic to the router from outside is closed.
- The Telegram proxy (port 1443) is likewise reachable only from those two networks; the port is opened to the internet only while "Access from the internet" is on. Without the secret the proxy cannot be used.
- The proxy secret is not visible in the process list: it is passed as an environment variable.

## Contributing

Pull requests and issues are welcome: fixes, support for other routers, panel translations.

Before you start, read [CONTRIBUTING.md](../../CONTRIBUTING.md) (in Russian): it lists the project rules (POSIX shell, where paths and state live, the usage block, line endings) and the workflow — the version in `kit/VERSION`, an entry in both CHANGELOGs, the README in both languages, and a mandatory run of `tests/run.ps1` on a router. Issue forms are provided: [bug](../../.github/ISSUE_TEMPLATE/bug.md) and [router tested on](../../.github/ISSUE_TEMPLATE/router-compatibility.md), the latter feeding the list of verified devices.

By submitting a pull request you agree to the terms in [LICENSE.en.md](../../LICENSE.en.md#contributions).

## Credits

[Xray-core](https://github.com/XTLS/Xray-core), [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat), [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy), [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) and [AdGuard filters](https://github.com/AdguardTeam/AdGuardSDNSFilter), [tg-ws-proxy-rs](https://github.com/valnesfjord/tg-ws-proxy-rs) and [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy), [OpenWrt](https://openwrt.org), [GL.iNet](https://www.gl-inet.com).

---

**Next:** [Installation](install.md) · [Web panel](panel.md) · [Servers and subscriptions](servers.md) · [DNS and ad blocking](dns-adblock.md) · [Telegram proxy](telegram-proxy.md) · [Maintenance](maintenance.md) · [Troubleshooting](troubleshooting.md)
