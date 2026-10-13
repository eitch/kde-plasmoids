# Jenkins Status Plasmoid

A Plasma 6 widget that displays the status of Jenkins builds directly on your desktop or panel. The compact widget
presents the overall build health indicator, and clicking on the widget opens an expanded view showing all configured
Jenkins servers, jobs/builds and their statuses, along with buttons to jump directly to each build page in your web
browser.

## Features

- **Panel overall status indicator:** Tinted icon representing the combined health across all monitored Jenkins jobs and
  servers.
- **Detailed popup view:** Lists all builds with their name, build number, completion duration, relative timestamp,
  health description, and current state badge (Success, Failure, Unstable, Building, Aborted).
- **Direct navigation button:** Includes an explicit button on each build to jump directly to its build page in your
  default browser.
- **Multiple servers and views support:** Connect to multiple Jenkins instances, views, or job endpoints simultaneously.
- **Secure credential management:** Username/password and API tokens are securely stored in KWallet (in the `Jenkins`
  folder) without leaking secrets into plain settings.
- **Automatic backup and recovery:** Automatically maintains instance recovery snapshots in
  `~/.config/jenkins-plasmoidrc`.

## Install

From this directory:

```bash
./install.sh
```

To remove the widget:

```bash
./remove.sh
```

To preview the widget:

```bash
plasmawindowed ch.eitchnet.jenkins.status
```

## Configuration

Open the widget settings to configure Jenkins instances:

1. **Server URL:** Enter the base Jenkins URL (e.g., `https://jenkins.example.com`), a view URL (e.g.,
   `https://jenkins.example.com/view/MyTeam`), or a specific job URL.
2. **Authentication Type:**
    - **API Token:** Enter your Jenkins username and User API token, then click **Save to KWallet**.
    - **Username & Password:** Enter your username and password, then click **Save to KWallet**.
    - **Anonymous:** For public/unauthenticated Jenkins instances.
3. **Refresh interval:** Configurable polling interval in seconds (default: 60s).

## Status Aggregation

The widget aggregates build states using the following priority:
**Failure (red) → Unstable (yellow) → Building (blue) → Unknown → Aborted / Disabled (gray) → Success (green)**.

## Tests

Run the test suite using Node.js:

```bash
node tests/jenkins.js
node tests/connection.js
node tests/settings.js
node tests/wallet.js
```
