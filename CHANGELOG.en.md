# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow [SemVer](https://semver.org). The current version is in `kit/VERSION`; every version has a `vX.Y.Z` git tag. [Русский](CHANGELOG.md)

Versions before 1.0.0 were assigned afterwards from the commit history.

## [Unreleased]

### Changed
- Panel header: logo on the left, the RU | EN switch and "Sign out" in the top right corner on desktop and phone ("Sign out" used to get lost under the menu). The login page has the language switch at the top right too; the version moved to the bottom, under the motto.
- The Ad blocking tab explains where ads remain (VK, YouTube — ads from the same site) and who bypasses the blocking (Private DNS, browser DoH, a VPN client).
- README: a "Where ads remain" section (what DNS can't remove, uBlock Origin as a complement, who bypasses the blocking), a "Devices on the network" section in the English README; screenshots re-shot, a "No servers" screen added.

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

[Unreleased]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.7.0...v1.0.0
[0.7.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/AndreyTokarev/Flint_Vless/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/AndreyTokarev/Flint_Vless/releases/tag/v0.1.0
