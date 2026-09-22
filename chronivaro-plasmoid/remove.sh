#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PLUGIN_ID="ch.eitchnet.chronivaro.status"

if kpackagetool6 --type Plasma/Applet --show "$PLUGIN_ID" >/dev/null 2>&1; then
    echo "Removing $PLUGIN_ID..."
    kpackagetool6 --type Plasma/Applet --remove "$PLUGIN_ID"
else
    echo "$PLUGIN_ID is not installed."
fi
