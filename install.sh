#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Error: kpackagetool6 is required to install the widgets." >&2
    exit 1
fi

install_widget() {
    local package_directory="$1"
    local plugin_id="$2"

    if kpackagetool6 --type Plasma/Applet --show "$plugin_id" >/dev/null 2>&1; then
        echo "Upgrading $plugin_id..."
        kpackagetool6 --type Plasma/Applet --upgrade "$SCRIPT_DIRECTORY/$package_directory"
    else
        echo "Installing $plugin_id..."
        kpackagetool6 --type Plasma/Applet --install "$SCRIPT_DIRECTORY/$package_directory"
    fi
}

install_widget chronivaro-plasmoid ch.eitchnet.chronivaro.status
install_widget uptime-kuma-plasmoid ch.eitchnet.uptimekuma.status

echo "Both widgets installed. Restarting Plasma reloads them and briefly hides the panel and desktop."
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
