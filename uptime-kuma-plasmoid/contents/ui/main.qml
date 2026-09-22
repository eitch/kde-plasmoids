import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../code/Kuma.js" as Kuma

PlasmoidItem {
    id: root

    property var entries: []
    property var dashboards: []
    property string overall: "unknown"
    property string configError: ""
    property bool settingsReady: false

    SettingsBackup {
        id: backup
        instanceId: String(Plasmoid.id)
    }

    function persistSettings() {
        if (!settingsReady) {
            return
        }

        try {
            backup.save(plasmoid.configuration.dashboards, plasmoid.configuration.pollInterval)
            plasmoid.configuration.settingsSaved = true
            plasmoid.configuration.writeConfig()
        } catch (error) {
            configError = "Could not back up the widget settings."
        }
    }

    function initializeSettings() {
        // Only restore a missing configuration, never an intentionally empty list.
        if (!plasmoid.configuration.settingsSaved && plasmoid.configuration.dashboards === "[]") {
            const savedSettings = backup.read()
            if (savedSettings) {
                plasmoid.configuration.dashboards = savedSettings.dashboards
                plasmoid.configuration.pollInterval = savedSettings.pollInterval
            }
        }

        settingsReady = true
        reload()
        persistSettings()
    }

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Uptime Kuma"
    toolTipSubText: label(overall) + " · " + entries.length + " dashboards"

    function label(monitorState) {
        const statusLabels = {
            up: "All operational",
            down: "Outage",
            unknown: "Unknown / unavailable",
            pending: "Pending",
            maintenance: "Maintenance",
            paused: "Paused"
        }

        return statusLabels[monitorState] || "Unknown"
    }

    function tint(monitorState) {
        const statusColors = {
            up: "#27ae60",
            down: "#da4453",
            pending: "#f6a800",
            maintenance: "#3daee9"
        }

        return statusColors[monitorState] || Kirigami.Theme.disabledTextColor
    }

    function collect() {
        const dashboardSummaries = []
        for (let sourceIndex = 0; sourceIndex < sources.count; ++sourceIndex) {
            const dashboardSource = sources.objectAt(sourceIndex)
            if (dashboardSource) {
                dashboardSummaries.push({
                    name: dashboardSource.entry.name || dashboardSource.entry.url,
                    url: dashboardSource.entry.url,
                    state: dashboardSource.status,
                    error: dashboardSource.error,
                    rows: dashboardSource.rows,
                    groups: dashboardSource.groups,
                    updated: dashboardSource.updated
                })
            }
        }

        dashboards = dashboardSummaries
        overall = Kuma.aggregate(dashboardSummaries.map(function(dashboardSummary) {
            return dashboardSummary.state
        }))
    }

    function configure() {
        const configureAction = Plasmoid.internalAction("configure")
        if (configureAction) {
            configureAction.trigger()
        }
    }

    function reload() {
        try {
            const configuredEntries = JSON.parse(plasmoid.configuration.dashboards)
            if (!Array.isArray(configuredEntries)) {
                throw new Error("Invalid dashboard list")
            }

            configError = ""
            entries = configuredEntries
        } catch (error) {
            entries = []
            configError = "Invalid dashboard configuration. Open settings to correct it."
        }

        Qt.callLater(collect)
    }

    function refresh() {
        for (let sourceIndex = 0; sourceIndex < sources.count; ++sourceIndex) {
            const dashboardSource = sources.objectAt(sourceIndex)
            if (dashboardSource) {
                dashboardSource.refresh()
            }
        }
    }

    Instantiator {
        id: sources
        model: root.entries
        delegate: Dashboard {
            required property var modelData
            entry: modelData
            pollInterval: plasmoid.configuration.pollInterval
            onChanged: Qt.callLater(root.collect)
        }

        onObjectAdded: Qt.callLater(root.collect)
        onObjectRemoved: Qt.callLater(root.collect)
    }

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.8
            height: width
            radius: width / 2
            color: root.tint(root.overall)
            Controls.Label {
                anchors.centerIn: parent
                text: ({
                    up: "✓",
                    down: "!",
                    unknown: "?",
                    pending: "…",
                    maintenance: "−",
                    paused: "Ⅱ"
                })[root.overall]
                color: "white"
                font.bold: true
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28
        RowLayout {
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: "Uptime Kuma"
            }

            Controls.ToolButton {
                icon.name: "view-refresh"
                text: "Refresh"
                onClicked: root.refresh()
            }

            Controls.ToolButton {
                icon.name: "configure"
                text: "Configure"
                onClicked: root.configure()
            }
        }

        Controls.Label {
            text: root.label(root.overall)
            color: root.tint(root.overall)
            font.bold: true
        }

        Controls.Label {
            Layout.fillWidth: true
            visible: root.entries.length === 0
            text: root.configError || "Add dashboards in the widget settings."
            wrapMode: Text.WordWrap
        }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width
                Repeater {
                    model: root.dashboards
                    delegate: ColumnLayout {
                        id: dashboard
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Separator {
                            Layout.fillWidth: true
                        }

                        Controls.Button {
                            Layout.fillWidth: true
                            text: dashboard.modelData.name
                            onClicked: Qt.openUrlExternally(dashboard.modelData.url)
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            text: root.label(dashboard.modelData.state)
                                + (dashboard.modelData.updated
                                    ? " · Last update " + dashboard.modelData.updated
                                    : "")
                            color: root.tint(dashboard.modelData.state)
                            wrapMode: Text.WordWrap
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            visible: dashboard.modelData.error !== ""
                            text: dashboard.modelData.error
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: dashboard.modelData.groups
                            delegate: ColumnLayout {
                                id: monitorGroup
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing
                                Controls.Label {
                                    visible: monitorGroup.modelData.name !== ""
                                    Layout.fillWidth: true
                                    topPadding: Kirigami.Units.largeSpacing
                                    bottomPadding: Kirigami.Units.smallSpacing
                                    text: monitorGroup.modelData.name
                                    textFormat: Text.PlainText
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                }

                                Repeater {
                                    model: monitorGroup.modelData.rows
                                    delegate: MonitorRow {
                                        required property var modelData
                                        monitor: modelData
                                        statusColor: root.tint(modelData.state)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: plasmoid.configuration
        function onDashboardsChanged() {
            if (!root.settingsReady) {
                return
            }

            root.reload()
            Qt.callLater(root.persistSettings)
        }

        function onPollIntervalChanged() {
            Qt.callLater(root.persistSettings)
        }
    }

    Component.onCompleted: initializeSettings()
}
