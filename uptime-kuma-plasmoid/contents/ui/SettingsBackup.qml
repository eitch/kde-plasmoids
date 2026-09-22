import QtQuick
import QtCore as Core
import "../code/Settings.js" as SettingsData

QtObject {
    required property string instanceId

    property Core.Settings storage: Core.Settings {
        location: Core.StandardPaths.writableLocation(Core.StandardPaths.ConfigLocation) + "/uptime-kuma-plasmoidrc"
        category: "Widget-" + instanceId
    }

    function read() {
        return SettingsData.decode(storage.value("snapshot", ""))
    }

    function save(dashboards, pollInterval) {
        const serializedSnapshot = SettingsData.snapshot(dashboards, pollInterval)
        storage.setValue("snapshot", serializedSnapshot)
        storage.sync()
    }
}
