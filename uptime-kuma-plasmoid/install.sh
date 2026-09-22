#!/usr/bin/env bash
set -e

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIRECTORY"

PLUGIN_ID="ch.eitchnet.uptimekuma.status"

if kpackagetool6 --type Plasma/Applet --show "$PLUGIN_ID" >/dev/null 2>&1; then
    echo "Upgrading $PLUGIN_ID..."
    kpackagetool6 --type Plasma/Applet --upgrade .
else
    echo "Installing $PLUGIN_ID..."
    kpackagetool6 --type Plasma/Applet --install .
fi

echo "Installation complete. Restarting Plasma reloads the widget and briefly hides the panel and desktop."
if read -r -p "Restart Plasma now? [y/N] " restart_reply; then
    case "$restart_reply" in
        [yY]|[yY][eE][sS])
            systemctl --user restart plasma-plasmashell.service
            exit 0
            ;;
    esac
fi

echo "Plasma was not restarted. To reload it later, run:"
echo "  systemctl --user restart plasma-plasmashell.service"
