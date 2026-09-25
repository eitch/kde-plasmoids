# Chronivaro Status Plasmoid

A KDE Plasma 6 widget for [Chronivaro](https://github.com/strolch-li/Chronivaro) to monitor work timer status, view daily and monthly balances, and start or stop the timer directly from the desktop panel.

The panel and popup use the Chronivaro application icon: green while the timer is running, red when stopped, and gray when unavailable.

## Features

- **Timer Status & Balances**: Displays current timer state, today's balance/actual/target hours, and current month balances.
- **Timer Control**: Start and stop the work timer with optional comments.
- **Work Locations**: Select from `OFFICE`, `HOME_OFFICE`, `FIELD`, or `REMOTE` (remembers last selection).

## Installation & Upgrade

To install or upgrade the plasmoid, run from the `chronivaro-plasmoid` directory:

```bash
./install.sh
```

The script automatically detects if the widget is already installed and performs an upgrade or fresh installation accordingly. After a successful installation, it asks whether to restart Plasma to load the widget. Answer `y` or `yes` to restart; Enter, any other answer, or closed input skips the restart. Apply pending widget settings first. Restarting briefly hides the panel and desktop.

Manual installation/upgrade commands with `kpackagetool6`:
```bash
# Fresh install
kpackagetool6 --type Plasma/Applet --install .

# Upgrade after changes
kpackagetool6 --type Plasma/Applet --upgrade .
```

Add **Chronivaro Status** to your Plasma panel and configure:

- **REST Endpoint**: Status URL (default: `http://localhost:8080/rest/chronivaro/v1/me/timer/status`). Start (`/start`) and stop (`/stop`) endpoints are automatically derived.
- **API Token**: User token in the format `<tokenId>:<tokenSecret>`.
- **Refresh Interval**: Polling interval in seconds (default: `30 s`).
- **Default Working Location**: Pre-selected location on timer start.

## Maintenance & Development

### Automated Tests

Prerequisite: Node.js (`node` on your PATH). The tests use only built-in Node.js modules; no `npm install`, running Chronivaro server, KWallet, or Plasma session is required.

From the repository root, run both test scripts:

```bash
node chronivaro-plasmoid/tests/connection.js && node chronivaro-plasmoid/tests/regression.js
```

Alternatively, from the `chronivaro-plasmoid` directory:

```bash
node tests/connection.js && node tests/regression.js
```

You can also run either script individually. Successful runs print:

```text
Connection test checks passed
Plasmoid regression checks passed
```

An assertion failure prints an error and exits with a non-zero status.

- `tests/connection.js` checks URL/token validation, request headers, successful and failed responses, timeout handling, duplicate requests, and send failures using simulated requests.
- `tests/regression.js` checks D-Bus signatures, reply/error handling, zero-valued wallet handles, and configuration-page declarations.

These scripts execute extracted JavaScript and inspect QML source; they do not render the UI or contact real services. After installing or upgrading the widget, manually verify saving/loading a token through KWallet, **Test Connection** with valid and invalid credentials, result dialogs, and switching settings pages in Plasma.

### Test Outside Panel

```bash
plasmawindowed ch.eitchnet.chronivaro.status
```

### Restart Plasma Shell

If Plasma does not reflect changes immediately after an upgrade:
```bash
systemctl --user restart plasma-plasmashell.service
```

### Remove / Uninstall

```bash
./remove.sh
# or: kpackagetool6 --type Plasma/Applet --remove ch.eitchnet.chronivaro.status
```

## Security Note & KWallet Integration

The widget supports storing your API token securely in **KWallet** (under the folder `Chronivaro` and key `token`).
- In the plasmoid settings dialog, you can click **"Save Token to KWallet"** to store your token encrypted in KWallet.
- When querying status or triggering timer actions, the plasmoid first checks KWallet for the stored token and falls back to the configured token in widget settings if KWallet is not available or empty.
