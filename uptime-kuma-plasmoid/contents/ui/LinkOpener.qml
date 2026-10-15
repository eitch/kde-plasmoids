import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: linkOpener

    property string customBrowser: ""

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            console.log("[LinkOpener] Process completed for command:", sourceName, "exit code:", data["exit code"])
            if (data["stderr"]) {
                console.warn("[LinkOpener] Process stderr:", data["stderr"])
            }
            if (data["stdout"]) {
                console.log("[LinkOpener] Process stdout:", data["stdout"])
            }
            disconnectSource(sourceName)
        }
    }

    function escapeShellArg(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function openUrl(url) {
        if (!url) {
            console.warn("[LinkOpener] openUrl called with empty URL")
            return
        }
        const targetUrl = String(url).trim()
        if (!targetUrl) {
            console.warn("[LinkOpener] openUrl called with whitespace-only URL")
            return
        }

        const browser = (customBrowser || "").trim()
        console.log("[LinkOpener] Request to open URL:", targetUrl, "| Configured browser:", browser ? browser : "(default / system)")

        if (!browser || browser === "default") {
            console.log("[LinkOpener] Delegating to Qt.openUrlExternally:", targetUrl)
            Qt.openUrlExternally(targetUrl)
            return
        }

        const safeUrl = escapeShellArg(targetUrl)
        let command = browser
        if (command.indexOf("%u") !== -1 || command.indexOf("%s") !== -1) {
            command = command.replace(/%u/g, safeUrl).replace(/%s/g, safeUrl)
        } else {
            command = command + " " + safeUrl
        }

        console.log("[LinkOpener] Executing custom browser command:", command)
        executable.connectSource(command)
    }
}
