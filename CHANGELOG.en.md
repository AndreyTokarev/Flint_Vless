# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [SemVer](https://semver.org). The current version is in `kit/VERSION`; every version has a `vX.Y.Z` git tag. [Русский](CHANGELOG.md)

Versions before 1.0.0 were assigned afterwards from the commit history.

## [Unreleased]

## [1.9.0] — 2026-10-05

### Added
- Devices without VPN: Routing → Devices without VPN — the chosen devices (by MAC) always go online directly, the rest still go via VPN. On the router — `flint-node direct`. The list is part of the settings file.

### Changed
- QUIC (UDP 443) is dropped by a separate `FLINT_QUIC` chain instead of a rule in `FORWARD`, so devices without VPN keep it; the old rule is removed on update.

## [1.8.1] — 2026-10-04

### Changed
- `install.sh` no longer shows the firmware firewall warnings (`[!] ...`) about GL's own rules; a failed firewall reload is still shown and stops the install.
- `tests/run.ps1` / `tests/run.sh`: install and the scenarios run in the background on the router (`tests/router/job.sh`); the script follows the log and survives a dropped connection. Running the same code with the same scenarios again follows the run in progress or the finished one instead of starting over; `-Force` / `--force` starts a new run. The `deploy -KeepKit` / `--keep-kit` switch is replaced with `-UploadOnly` / `--upload-only`: upload the kit without installing.

## [1.8.0] — 2026-10-04

### Added
- Uninstall Flint VPN: `uninstall.ps1` / `uninstall.sh` (on the router — `kit/uninstall.sh`). A backup runs first; network, Wi‑Fi and the firmware stay, devices go online directly.
- Local names for network devices in the panel: DNS → Local names (`nas01` → IP; `nas01.lan` and `nas01.local` work too). On the router — `flint-dns hosts`. The names are part of the settings file.

### Changed
- Completed audits and refactoring plans moved to `docs/archive/`.
- `LOCAL_HOSTS` in `flint.env` only seeds the local names on a fresh router; on update the existing names move to the panel.
- `restore.ps1` / `restore.sh` bring back every panel setting from the backup: the chosen server, VPN and routing modes, DNS, local names, ad blocking state, intervals and the watchdog. Before, only `flint.env`, servers, sites and ad blocking lists were restored.
- `flint-settings export <dir>` exports the settings from a copy of `/etc/xray`, e.g. from a backup.

### Fixed
- A redeploy no longer resets the routing mode chosen in the panel to `ROUTING` from `flint.env`.

## [1.7.2] — 2026-10-04

### Changed
- Panel tab order: Status, Subscriptions, Servers, Own servers, DNS, Routing, Ad blocking, Settings.
- The README screenshots are re-shot for the current design; the DNS and Settings tabs are added.

## [1.7.1] — 2026-10-04

### Changed
- DNS tab: removed the "Turn on …" buttons that duplicated "Use …".

## [1.7.0] — 2026-10-04

### Added
- DNS modes on the new DNS panel tab and in `flint-dns`: DoH (default, as before), DNSCrypt and plain DNS over UDP. Each mode keeps its own server; switching the mode does not reset it.
  - DNSCrypt: AdGuard DNS (filtering and not), Quad9 (filtering and not), dnscry.pt (Moscow, Stockholm) or your own `sdns://…` stamp. A fallback when DoH is blocked on the network.
  - UDP: Cloudflare, Google, Quad9, AdGuard DNS, Yandex, the main router's DNS or your own IP addresses. dnscrypt-proxy is stopped in this mode.
- A new DNS setup is checked; if it does not answer within 15 seconds, the previous one comes back.

### Changed
- The DNS settings moved from Settings to the DNS tab; the DNS link on Status leads there too.
- The dnsmasq upstream is set by `flint-dns` instead of the installer, so the chosen mode survives a redeploy.

## [1.6.0] — 2026-10-04

### Added
- DNS server (DoH) choice in the panel (Settings → DNS server) and with `flint-dns`: Cloudflare (default, as before), Google, Quad9, AdGuard DNS or your own `https://…` address. A new server is checked; if it does not answer, the previous one stays. The choice survives a redeploy and goes into the settings file.
- Status: besides the IP via VPN, the provider IP (before VPN) is shown, and the current DNS server.

### Changed
- The dnscrypt-proxy config (`/etc/dnscrypt-proxy2/flint-doh.toml`) is now written by `flint-dns` instead of being copied by the installer.
- README: PIN change, moving settings with a file, "Sites without blocking" and "Recently blocked", fixed addresses for main-network devices, new troubleshooting rows.

## [1.5.5] — 2026-10-04

### Fixed
- PIN change: characters other than letters and digits are rejected with a message instead of being silently dropped (`ab#12` used to be saved as `ab12`).

## [1.5.4] — 2026-10-04

### Changed
- Restored the previous panel logo: SVG mark and text (`UI_TITLE` / `UI_TAGLINE`), as before 1.5.3.

## [1.5.3] — 2026-10-04

### Changed
- Panel logo and favicon: new skeleton-pirate brand image instead of the SVG mark and text. `UI_TITLE` remains the browser tab title.

## [1.5.2] — 2026-10-04

### Added
- Settings tab: change the panel PIN (current, new and confirmation). The PIN is written to `flint.env` on the router; a deploy from the computer will use the PIN from `config/flint.env` again.

## [1.5.1] — 2026-10-04

### Changed
- The "YOUR NETWORK. YOUR RULES." strip at the bottom of the panel is no wider than the menu and content instead of the whole window.

## [1.5.0] — 2026-10-04

### Added
- Settings tab: export the settings to a file and import them from a file (works from a phone too). The file holds subscriptions, own and manual servers, sites, ad blocking, modes and intervals; the PIN and network (`flint.env`) are not included, so the file also fits another Flint. Import replaces these settings and applies them at once; the previous ones stay in `/tmp/flint-settings-prev.txt` until a reboot.
- Command `flint-settings export` / `flint-settings import [file]`.

### Fixed
- Test scenarios no longer run at the same time (lock `/tmp/flint-test.lock`), each has its own `/etc/xray` snapshot, and `/etc/xray` is never removed without one. Two parallel runs could wipe the router's settings before.

## [1.4.0] — 2026-10-04

### Added
- Ad blocking tab: a "Sites without blocking" card — the site and its subdomains are not blocked (an `@@||site^` exception). Ads from other domains on that site are still blocked at the DNS level.
- Next to it, a "Recently blocked" list (domain and device) with an Allow button, to find the domain a broken site needs. AdGuard Home keeps the last 1000 queries for it in memory only; command `flint-adblock blocked`.

### Changed
- The panel reads `/etc/xray/flint.env` directly; the deploy removes the `/usr/share/flint/env` link.
- The panel takes the action from the request parameter itself: hidden `a=` fields are gone from every form, and parameters are read only in their action's branch.
- On the Servers tab, manual servers next to a subscription are titled "Manual" instead of repeating "Servers".
- `flint-adblock` parses AdGuard Home replies with `jsonfilter` instead of regular expressions; the installer checks that `jsonfilter` is present.
- New `tests/router/panel.sh` scenario: panel tabs and the main actions through `panel.cgi`. Scenarios no longer start when `/etc/xray` could not be snapshotted (the scenario's exit could wipe it before).

## [1.3.0] — 2026-10-04

### Removed
- `kit/upstream-access.sh`: the deploy sets up access from the main router's network from `UPSTREAM_IF` / `UPSTREAM_NET` in `flint.env` (the script had the network and interface hard-coded). After a network change, edit `flint.env` and redeploy.

### Changed
- Migrations from older kits (`gru-*` leftovers, `#@` groups in `nodes.conf`) moved from `install.sh` to `kit/migrate.sh`; each one says when it can be deleted.
- dnsmasq settings and firewall rules are applied with one `uci batch` instead of dozens of separate `uci set` calls; the resulting settings are the same.
- `flint-node` and `flint-custom` no longer use `set -e`: failures to write files or restart Xray are checked explicitly with a clear message. Only `install.sh` keeps `set -e`.

## [1.2.2] — 2026-10-04

### Changed
- The user files (`flint.env`, servers, subscriptions, sites, ad blocking) are listed once, in `kit/state-files`. Deploy, backup, restore and the installer read it; before, the list was copied into seven places.
- The backup pulls these files as one archive, `backup/<date>/state.tar.gz` (one connection instead of nine), and unpacks it into `config/`.
- `tests/run.ps1` / `tests/run.sh` deploy the working copy first, so every scenario checks the current code. `deploy` got a `-KeepKit` / `--keep-kit` switch.

## [1.2.1] — 2026-10-04

### Fixed
- A redeploy no longer replaces subscription servers with a stale copy: `config/nodes.conf` holds only manually set servers, and an old file with `#@` groups no longer overwrites existing `nodes.d/<id>.conf` files.
- A `nodes.d/<id>.conf` file of a subscription that is not listed (e.g. after a restore) no longer works invisibly: its servers are not used, and the file is removed on update.
- `flint-custom del` exited with an error when the deleted server was not the current one.

### Removed
- `tools/sub2nodes.py`: the router builds the subscription server list itself, no Python needed on the computer.

### Changed
- The server file layout and line parsing live in one place (`/usr/share/flint/lib.sh`), used by `flint-node`, `flint-custom`, `flint-sub-update`, the firewall and the tests.

### Added
- Second code quality audit and fix plan (in Russian): `docs/archive/code-quality-audit-1.2.md`, `docs/archive/refactoring-plan-1.2.md`.

## [1.2.0] — 2026-10-04

### Changed
- Each subscription's servers live in `/etc/xray/nodes.d/<id>.conf`, own servers in `nodes-custom.conf`, manual ones in `nodes.conf`. The `#@` markers in a single file are gone.
- On install, a legacy `nodes.conf` with `#@` groups is split into files (a copy is kept as `nodes.conf.bak`).
- Backup, restore and deploy carry the `nodes.d/` directory.

### Added
- Code quality audit and refactoring plan: `docs/archive/code-quality-audit.md`, `docs/archive/refactoring-plan.md`.

## [1.1.2] — 2026-10-04

### Changed
- Panel styles moved to `/panel.css`.
- Panel actions go through an `a=` parameter (one `case` instead of a long `elif` chain).
- The panel reads state via `flint-node current`, `flint-sub-update status` and `flint-watchdog last`, not by opening `/etc/xray/` files directly.

## [1.1.1] — 2026-10-04

### Added
- Router test scenarios: `tests/router/` and `tests/run.ps1` / `tests/run.sh` wrappers (no-servers mode, subscription, own server, failover when the current server disappears).
- Shared library `/usr/share/flint/lib.sh` (`t`, `node_lines`, `host_of`).

### Changed
- `flint-node apply` picks the server itself: the current one if it is still listed; otherwise the first with a switch message; otherwise the no-servers mode. Firewall and watchdog treat a missing `config.json` as "no servers".
- Panel header: logo on the left, the RU | EN switch and "Sign out" in the top right on desktop and phone. The login page has the language switch at the top right too; the version moved to the bottom, under the motto.
- The Ad blocking tab explains where ads remain and who bypasses the blocking.
- README: a "Where ads remain" section, a "Devices on the network" section in the English README; screenshots re-shot, a "No servers" screen added.

### Fixed
- The "Add a subscription" and "Add an own server" links in the no-servers mode were barely visible on the dark background — they are buttons now.

## [1.1.0] — 2026-10-03

### Added
- Install without servers: a deploy needs only `config/flint.env` with `UI_PIN`; `config/nodes.conf`, `SUB_URL` and `VLESS_UUID` are optional. While there are no servers, Xray stays down and devices go online directly; the Status and Servers tabs link to "Add a subscription" and "add an own server". The first subscription or own server added turns the VPN on by itself.
- With `SUB_URL` set and no servers yet, the install downloads the subscription's servers right away.

### Changed
- The last subscription can now be deleted: the router switches to the no-servers mode.
- "Copy and edit" on the Own servers tab is hidden while there is nothing to copy.

### Fixed
- Deleting the last own server while it was the current one no longer leaves Xray on the old config.

## [1.0.0] — 2026-10-03

### Added
- Subscriptions tab: several subscriptions from different VPN providers (v2rayN / Happ / Hiddify format — a list of `vless://` links, plain or base64). Add a subscription by link, change its link or name, delete it.
- The subscription name comes from the `profile-title` header, the expiry date and traffic from `subscription-userinfo`; both are shown in the subscription list.
- The Servers tab groups servers by subscription, own servers in a card of their own.
- `flint-sub-update list | add | set | url | del` commands.
- Versioning: `kit/VERSION`, the version at the bottom of the panel menu and on the login page, `/usr/share/flint/version` on the router; a deploy prints the version it installs and the one that was there. This changelog.

### Changed
- Subscription refresh and the auto-update interval moved from the Servers tab to Subscriptions; "Update all subscriptions now" refreshes every subscription.
- A subscription that fails to download keeps its previous servers; the error is shown next to it.
- `SUB_URL` in `flint.env` is now only the first subscription on a fresh router; the list lives in `/etc/xray/subscriptions` and goes into backups (`config/subscriptions`).
- A redeploy no longer replaces the router's `nodes.conf` with the PC copy when the router has subscriptions.
- The hosts of all subscriptions bypass the VPN.

### Fixed
- Installation no longer fails when the `DEFAULT_NODE` server is missing: the first server is used.
- Russian messages say "серверов: 3" instead of the ungrammatical "3 серверов".

## [0.7.0] — 2026-10-03

### Changed
- The project is renamed: the `gru-` prefix is now `flint-` in all scripts, services and paths (`flint-node`, `flint-adblock`, `/www/flint`, the `FLINT_DNS` chain, the `FLINT_LANG` variable); the settings file is `config/flint.env`.
- Provider mentions are gone: the project works with any VLESS + REALITY subscription.

### Added
- `install.sh` migrates an installed router to the new names: removes the old services, files, cron jobs, firewall rules and the `GRU_DNS` chain, and keeps the downloaded AdGuard filters.
- `restore` accepts backups made before the rename (`gru.env`).

## [0.6.0] — 2026-10-03

### Added
- DNS ad blocking with the AdGuard Home binary from GL firmware, a separate instance in front of dnsmasq. Turned on with a button on the Ad blocking tab.
- Filter lists: AdGuard DNS filter by default, ready-made lists (HaGeZi, OISD, Steven Black and more) and your own by URL; auto-update and "Update the lists now".
- Own "Block" / "Allow" rules in AdGuard syntax.
- Devices without blocking (by MAC address), picked from the connected devices.
- 24-hour stats; if AdGuard Home fails, the watchdog restarts it, and if that does not help, DNS goes straight to dnsmasq.

### Fixed
- Installation no longer aborts when the VPN check after switching the server times out; the final check makes three attempts.

## [0.5.0] — 2026-10-03

### Added
- English panel: language from the browser or `UI_LANG`, RU · EN switch, the choice is remembered.
- Script messages and background records (subscription check, failures) in the panel language.
- Full backup and restore instructions in the English README.

## [0.4.0] — 2026-10-03

### Added
- Public README in Russian and English with screenshots, setup, troubleshooting and limitations.
- Flint VPN Noncommercial License 1.0 (based on PolyForm Noncommercial 1.0.0) with Russian and English summaries.
- Vector logo and panel icon.

## [0.3.0] — 2026-10-03

### Added
- Failover: the VPN is checked every 2 minutes; the subscription is refreshed and the first working server is picked.
- Subscription auto-update interval in the panel.
- "White list" servers (bare IPs) in a block of their own; gRPC transport.
- Logo, icon and the motto at the bottom of the panel.

### Changed
- The subscription host always bypasses the VPN.

## [0.2.0] — 2026-10-03

### Added
- The server list is built from the subscription (`tools/sub2nodes.py`, `flint-sub-update` on the router) with readable names; provider servers bypass the VPN.
- Panel: own servers, own sites, geo filter, VPN button, subscription auto-update, custom logo text, PIN login screen, sidebar with tabs.
- Panel address `vpn.lan`.
- `restore.ps1` / `restore.sh`; `-Full` also brings back network, Wi‑Fi and firewall.

## [0.1.0] — 2026-10-03

### Added
- Install kit for GL.iNet GL-BE6500: transparent Xray (VLESS + REALITY) for the whole network, DNS over DoH (dnscrypt-proxy), panel on port 81.
- Russia geo filter: Russian sites and IPs go direct.
- Access to the main router's network without the VPN.
- Packages installed from scratch; deploy and backup for Windows, macOS and Linux.

[Unreleased]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.9.0...HEAD
[1.9.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.8.1...v1.9.0
[1.8.1]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.8.0...v1.8.1
[1.8.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.7.2...v1.8.0
[1.7.2]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.5.5...v1.6.0
[1.5.5]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.5.4...v1.5.5
[1.5.4]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.5.3...v1.5.4
[1.5.3]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.5.2...v1.5.3
[1.5.2]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.5.1...v1.5.2
[1.5.1]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.7.0...v1.0.0
[0.7.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/AndreyTokarev/Flint_Vless/releases/tag/v0.1.0
