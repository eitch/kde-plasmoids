import QtQuick
import QtCore as Core
import "../code/Settings.js" as SettingsData

QtObject {
    required property string instanceId

    property Core.Settings storage: Core.Settings {
        location: Core.StandardPaths.writableLocation(Core.StandardPaths.ConfigLocation) + "/swiss-stock-market-plasmoidrc"
        category: "Widget-" + instanceId
    }

    function read() {
        return SettingsData.decode(storage.value("snapshot", ""))
    }

    function save(watchlist, pollInterval, brokerProvider, brokerEndpoint, authType, displaySymbol, browser) {
        const serializedSnapshot = SettingsData.snapshot(
            watchlist,
            pollInterval,
            brokerProvider,
            brokerEndpoint,
            authType,
            displaySymbol,
            browser
        )
        storage.setValue("snapshot", serializedSnapshot)
        storage.sync()
    }
}
