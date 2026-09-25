# KDE Plasmoids

A collection of KDE Plasma 6 widgets for tracking work time and monitoring service health from the desktop or panel. Each widget is an independent QML package with its own installer, configuration and tests.

## Available widgets

| Widget | Purpose | Documentation |
| --- | --- | --- |
| **Chronivaro Status** | View the current work timer, daily and monthly balances, and start or stop work with a location and optional comment. | [Chronivaro plasmoid](chronivaro-plasmoid/README.md) |
| **Uptime Kuma Status** | Combine health across multiple public status pages and authenticated instances, with grouped monitor lists and an overall status indicator. | [Uptime Kuma plasmoid](uptime-kuma-plasmoid/README.md) |

## Requirements

- KDE Plasma 6 and `kpackagetool6`.
- Plasma's `org.kde.plasma.workspace.dbus` QML module and KWallet 6 for credential storage.
- A reachable Chronivaro server or Uptime Kuma instance, depending on the widget. The Uptime Kuma integration targets version 2.5.x.
- Node.js on your `PATH` to run development tests. It is not required to use the widgets.

## Install or upgrade

Install or upgrade both widgets from this directory:

```bash
./install.sh
```

The root installer offers one Plasma restart after both installations succeed.

Alternatively, run the installer for an individual widget:

```bash
./chronivaro-plasmoid/install.sh
```

```bash
./uptime-kuma-plasmoid/install.sh
```

Each script detects an existing installation and upgrades it. After a fresh installation, open Plasma's **Add Widgets** interface, find **Chronivaro Status** or **Uptime Kuma Status**, and add it to your panel or desktop.

Configure the widget through its settings dialog:

- **Chronivaro:** set the REST endpoint and API token, refresh interval and default working location. Tokens can be stored in KWallet.
- **Uptime Kuma:** add one or more public status-page URLs or instance URLs with API-key or username/password authentication. Credentials are stored in KWallet. An optional status-page slug selects that page's monitors and grouping for authenticated sources.

See each widget's documentation for authentication requirements and configuration details.

### Reload after an upgrade

Keep the existing widget on the panel and apply any pending settings before upgrading. Both installers offer to restart Plasma after a successful installation; they only restart when you answer `y` or `yes`.

If updated code is not yet visible, you can restart Plasma manually:

```bash
systemctl --user restart plasma-plasmashell.service
```

The panel and desktop briefly disappear during the restart.

## Settings and credentials

Applied settings are stored by Plasma for each widget instance. Removing and re-adding a widget creates a new instance with fresh settings; it is not necessary for an upgrade.

Uptime Kuma also keeps a recovery snapshot per instance in `~/.config/uptime-kuma-plasmoidrc`, or under `$XDG_CONFIG_HOME` when configured. It restores the snapshot if that instance's Plasma configuration is missing. This file contains source configuration and the refresh interval, not credentials.

KWallet stores Chronivaro tokens in the `Chronivaro` folder and Uptime Kuma credentials in `UptimeKuma`. Chronivaro supports a fallback token in its ordinary widget settings; Uptime Kuma stores credentials only in KWallet. Removing a widget does not remove its KWallet entries.

## Development

The packages can be edited and installed directly; no build step or `npm install` is required.

```text
kde-plasmoids/
├── chronivaro-plasmoid/
│   ├── contents/          # Configuration schema and QML interface
│   ├── tests/             # Connection and regression checks
│   ├── metadata.json
│   ├── install.sh
│   └── remove.sh
└── uptime-kuma-plasmoid/
    ├── contents/
    │   ├── code/          # JavaScript data and settings helpers
    │   ├── config/        # Plasma configuration schema
    │   └── ui/            # QML interface, requests and KWallet integration
    ├── tests/             # Data, connection, persistence and wallet checks
    ├── metadata.json
    ├── install.sh
    └── remove.sh
```

Use descriptive identifiers, consistent indentation and small, focused functions. Follow the existing package conventions and Uptime Kuma's `.editorconfig`.

### Run automated checks

From this directory:

```bash
node chronivaro-plasmoid/tests/connection.js
node chronivaro-plasmoid/tests/regression.js
node uptime-kuma-plasmoid/tests/kuma.js
node uptime-kuma-plasmoid/tests/connection.js
node uptime-kuma-plasmoid/tests/settings.js
node uptime-kuma-plasmoid/tests/wallet.js
```

These tests use Node.js built-in modules and simulated responses. They do not require live servers, KWallet access or a Plasma session. Verify visual changes and live credential handling separately in Plasma.

### Preview an installed widget

```bash
plasmawindowed ch.eitchnet.chronivaro.status
plasmawindowed ch.eitchnet.uptimekuma.status
```

## Uninstall

Run the relevant removal script:

```bash
./chronivaro-plasmoid/remove.sh
```

```bash
./uptime-kuma-plasmoid/remove.sh
```

## License

Both widgets declare `AGPL` in their package metadata.
