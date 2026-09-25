# Uptime Kuma Status Plasmoid

A Plasma 6 widget that combines monitor health from multiple Uptime Kuma sources into one panel indicator. Expand it to see each source and its monitors; click a source name to open its URL.

Supports Uptime Kuma 2.5.x public status pages and private instances through their Prometheus metrics endpoint. No Node.js service, browser login session or additional WebSocket module is needed.

The panel uses the Uptime Kuma application icon, colored green when operational, red during an outage, amber while pending, blue during maintenance, and gray when paused or unavailable. Status text remains available in the tooltip and popup.

## Install

From this directory:

```bash
./install.sh
```

Add **Uptime Kuma Status** to your panel or desktop. Dependencies: Plasma 6, its `org.kde.plasma.workspace.dbus` QML module, and KWallet 6 for credentials (the same integration used by the Chronivaro widget).

The installer installs or upgrades `ch.eitchnet.uptimekuma.status`. To remove it, run `./remove.sh`. To preview an installed widget, run `plasmawindowed ch.eitchnet.uptimekuma.status`.

## Upgrades and saved settings

Run `./install.sh` with the widget still on the panel, after applying any pending settings. After a successful install or upgrade, the script asks whether to restart Plasma to load the updated widget. Answer `y` or `yes` to restart; Enter, any other answer, or closed input skips the restart. Restarting briefly hides the panel and desktop. You can also restart later:

```bash
systemctl --user restart plasma-plasmashell.service
```

Applied settings use Plasma's normal configuration storage. The widget also immediately syncs a recovery snapshot to `~/.config/uptime-kuma-plasmoidrc` (or `$XDG_CONFIG_HOME/uptime-kuma-plasmoidrc`). Each widget instance has its own section. On startup it restores that snapshot if the instance's Plasma configuration is missing. Existing settings are backed up automatically when this version first loads. An intentionally cleared dashboard list remains empty.

The snapshot contains dashboard URLs, names, types, slugs, usernames and the refresh interval; passwords and API keys remain in KWallet. Settings drafts are saved only when applied. Removing and re-adding a widget creates a different instance, so its old snapshot is not automatically applied. This recovery mechanism cannot recover settings lost before a snapshot existed.

## Configure sources

Open widget settings and select **Add dashboard** for each source. Supply an optional display name and choose a mode:

- **Public status page:** enter `https://status.example.com/status/services`. For a custom-domain root such as `https://status.example.com`, also enter the page's slug (`services`), which you can find in Uptime Kuma's status-page settings. `/status` uses the `default` slug.
- **Dashboard — API key:** recommended for private instances. Enable API keys under Uptime Kuma **Settings → API Keys**, create a key, enter the instance URL (base URL, `/dashboard`, or `/metrics`), paste the key and select **Save credential to KWallet**. No username is needed. Optionally enter a **Status-page slug for grouping** (for `/status/internal`, enter `internal`). This selects only that page’s monitors and group ordering, using the API-key metrics for health. The page configuration must be accessible at the same instance without interactive login; API keys do not grant access to protected status-page configuration. Leave the slug blank to show all metric monitors. This also works independently of interactive two-factor login.
- **Dashboard — username/password:** enter the instance URL and native Uptime Kuma username/password, then save the credential to KWallet. This accesses `/metrics` using HTTP Basic authentication and requires API-key authentication to be disabled on that instance. It does not perform an interactive web login or external SSO.

Select **Apply** to save the source list, then use **Refresh** in the popup. The default refresh interval is 60 seconds; settings allow 10–3600 seconds. Uptime Kuma itself can cache public responses for up to several minutes.

API keys and passwords are stored only in KWallet's `UptimeKuma` folder. Entries are scoped by authentication mode and normalized server URL; password entries also include the username. Two sources using the same server and authentication identity share that credential. Saving a credential takes effect immediately, even if you later cancel the settings dialog. Removing a source leaves its credential in KWallet; remove it using KWallet Manager if no longer needed. Source URLs, display names and usernames are ordinary Plasma settings. Credentials are never placed in those settings or request URLs. Use HTTPS for remote authenticated instances.

## Status meaning

The panel combines all configured sources with this priority: **outage → unknown/unavailable → pending → maintenance → operational**. A confirmed outage stays visible even if another source cannot be reached. Green requires every source to have reporting monitors and no down, unknown, pending or maintenance states among them. Public monitors with an explicitly empty heartbeat list display **No data** and do not affect aggregation; the public API does not distinguish a disabled monitor from one that has not recorded any heartbeats. A source containing only such monitors remains unknown. Empty sources, missing heartbeat data, failed authentication, malformed responses and request timeouts are unknown. Paused monitors are excluded from failure states when the source explicitly identifies them.

Public pages include only the monitors published on that page, grouped under the same headings and in the same group and monitor order. Private metrics sources use the selected status page’s groups when a slug is configured; otherwise they remain a single list. A selected monitor missing from metrics is **No data** when its public heartbeat history is explicitly empty, and unknown otherwise. An existing metric always supplies its status, even if the public heartbeat history is empty. A missing or inaccessible selected page reports an error instead of silently switching to all monitors. Private sources include the `monitor_status` series exposed by `/metrics`; metrics do not provide a complete inventory of paused/uninitialized monitors or status-page incident announcements. Consequently the indicator reflects reported monitor health, not editorial incident text or every monitor in the administration UI. The popup's last-update time is the successful fetch time, not the original heartbeat time. Failed requests clear current monitor rows and report unknown after at most the 30-second request deadline.

Reverse proxies must allow access to the public status APIs or `/metrics` as appropriate. External SSO/Authelia sessions and proxy-specific authentication are not supported.

## Tests

Node.js is used only for development tests:

```bash
node tests/kuma.js
node tests/connection.js
node tests/settings.js
node tests/wallet.js
```

Tests cover URL handling, source aggregation, public response decoding, Prometheus metrics parsing, Basic authorization, failed credentials, duplicate refreshes, timeouts and stale responses. Settings tests cover snapshot validation, recovery, migration and intentional deletion. Wallet tests verify D-Bus signatures, zero-valued handles, reads, writes and closing handles after failures. A separate isolated Plasma test verified save/restart persistence and recovery after removing the test instance’s Plasma settings. The widget and all three settings modes have also been loaded in an isolated offscreen Plasma session. Live integration with your Uptime Kuma instances and KWallet must still be verified after configuring them.

## Code style

The package's `.editorconfig` defines indentation and whitespace. Use descriptive variable and callback names, `const` for values that are not reassigned, and `let` where reassignment is necessary. Expand control flow into braced blocks, keep QML properties on separate lines, and avoid nested ternaries. Standalone JavaScript files use semicolons; QML follows the surrounding Qt style without them.

Keep data transformations in `contents/code`, request handling in `Dashboard.qml`, credential handling in `Wallet.qml`, and monitor presentation in `MonitorRow.qml`. Tests use named scenarios and mocked requests or D-Bus replies; they do not need a running server or access to real credentials.

## Upstream interfaces

- [Uptime Kuma 2.5.5 authentication](https://github.com/louislam/uptime-kuma/blob/2.5.5/server/auth.js): API keys authenticate `/metrics` as the Basic password with an empty username; native credentials are used when API keys are disabled.
- [Prometheus metrics](https://github.com/louislam/uptime-kuma/blob/2.5.5/server/prometheus.js): `monitor_status`, `monitor_id` and `monitor_name`.
- [Public status-page routes](https://github.com/louislam/uptime-kuma/blob/2.5.5/server/routers/status-page-router.js): page configuration and heartbeat data.
