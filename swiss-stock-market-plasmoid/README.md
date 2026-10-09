# Swiss Stock Market Plasmoid

A KDE Plasma 6 widget to monitor user-selectable stock market equities, indices, and currency rates with live market information from Yahoo Finance.

The compact panel representation shows your primary selected stock ticker, current price, and color-coded change percentage with trend indicators. The expanded popup view displays a full watchlist with day ranges, open/previous close prices, volumes, and category filtering.

## Features

- **Yahoo Finance Broker Integration**: Real-time quotes for Swiss indices (SMI, SPI, SLI), Forex rates (EUR/CHF, USD/CHF), and equities.
- **Selectable Stock Markets & Search**: Interactive search across Swiss market presets with 1-click addition and custom ticker symbol support.
- **Instant Search & Add**: Find stocks by ticker symbol, company name, ISIN, or category directly in the widget dashboard and settings watchlist manager with 1-click addition.
- **Offline & Fallback Resilience**: Preserves configured watchlist stocks and reference prices even during connection transitions or offline states.
- **Compact & Full Representations**: View primary stock quotes directly in your KDE panel and expand to see a detailed multi-card watchlist with real-time status indicators.
- **KWallet Integration**: Securely stores broker API tokens and credentials in KWallet under the `SwissStockMarket` folder.
- **Crash & Migration Recovery**: Backs up non-sensitive widget configuration to `~/.config/swiss-stock-market-plasmoidrc`.

## Installation & Upgrade

To install or upgrade the plasmoid, run from the `swiss-stock-market-plasmoid` directory:

```bash
./install.sh
```

The script automatically detects if the widget is already installed and performs an upgrade or fresh installation accordingly. After installation, restart Plasma when prompted to load the widget.

Manual installation/upgrade commands with `kpackagetool6`:
```bash
# Fresh install
kpackagetool6 --type Plasma/Applet --install .

# Upgrade after changes
kpackagetool6 --type Plasma/Applet --upgrade .
```

Add **Swiss Stock Market** to your Plasma panel and configure:

- **Broker Provider**: Yahoo Finance.
- **Broker REST URL**: Endpoint for retrieving market quotes (default: `https://query1.finance.yahoo.com/v8/finance/chart/`).
- **Primary Panel Symbol**: Choose which stock or index is shown in the compact panel view.
- **Refresh Interval**: Polling interval in seconds (default: `60 s`, range 10–3600 s).
- **Watchlist Manager**: Add one-click Swiss market presets or configure custom ticker symbols, names, and markets.

## Maintenance & Development

### Automated Tests

Prerequisite: Node.js (`node` on your PATH). The tests use built-in Node.js modules; no live broker connections or Plasma sessions are required.

From the repository root, run the test suites:

```bash
node swiss-stock-market-plasmoid/tests/market.js
node swiss-stock-market-plasmoid/tests/connection.js
node swiss-stock-market-plasmoid/tests/settings.js
node swiss-stock-market-plasmoid/tests/wallet.js
```

### Preview Outside Panel

```bash
plasmawindowed ch.eitchnet.stockmarket.status
```

### Remove / Uninstall

```bash
./remove.sh
# or: kpackagetool6 --type Plasma/Applet --remove ch.eitchnet.stockmarket.status
```
