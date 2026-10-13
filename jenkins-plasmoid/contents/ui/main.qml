import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../code/Jenkins.js" as Jenkins

PlasmoidItem {
    id: root

    property var entries: []
    property var servers: []
    property string overall: "unknown"
    property string configError: ""
    property bool settingsReady: false
    property int totalBuilds: 0

    Wallet {
        id: plasmoidWallet
    }

    readonly property var wallet: plasmoidWallet

    SettingsBackup {
        id: backup
        instanceId: String(Plasmoid.id)
    }

    function persistSettings() {
        if (!settingsReady) {
            return
        }

        try {
            backup.save(plasmoid.configuration.servers, plasmoid.configuration.pollInterval)
            plasmoid.configuration.settingsSaved = true
            plasmoid.configuration.writeConfig()
        } catch (error) {
            configError = "Could not back up the widget settings."
        }
    }

    function initializeSettings() {
        if (!plasmoid.configuration.settingsSaved && plasmoid.configuration.servers === "[]") {
            const savedSettings = backup.read()
            if (savedSettings) {
                plasmoid.configuration.servers = savedSettings.servers
                plasmoid.configuration.pollInterval = savedSettings.pollInterval
            }
        }

        settingsReady = true
        reload()
        persistSettings()
    }

    preferredRepresentation: compactRepresentation
    toolTipMainText: "Jenkins Builds"
    toolTipSubText: label(overall) + " · " + totalBuilds + " builds"

    function label(buildState) {
        const statusLabels = {
            success: "All builds passing",
            failure: "Build failure",
            unstable: "Build unstable",
            building: "Building in progress",
            aborted: "Aborted / disabled",
            unknown: "Unknown / unavailable"
        }

        return statusLabels[buildState] || "Unknown"
    }

    function tint(buildState) {
        const statusColors = {
            success: "#27ae60",
            failure: "#da4453",
            unstable: "#f6a800",
            building: "#3daee9",
            aborted: "#7f8c8d"
        }

        return statusColors[buildState] || Kirigami.Theme.disabledTextColor
    }

    function collect() {
        const serverSummaries = []
        let count = 0
        const allStates = []

        for (let sourceIndex = 0; sourceIndex < sources.count; ++sourceIndex) {
            const jenkinsSource = sources.objectAt(sourceIndex)
            if (jenkinsSource) {
                serverSummaries.push({
                    name: jenkinsSource.entry.name || jenkinsSource.entry.url,
                    url: jenkinsSource.entry.url,
                    state: jenkinsSource.status,
                    error: jenkinsSource.error,
                    builds: jenkinsSource.builds,
                    updated: jenkinsSource.updated
                })
                count += (jenkinsSource.builds ? jenkinsSource.builds.length : 0)
                if (jenkinsSource.builds && jenkinsSource.builds.length > 0) {
                    for (let j = 0; j < jenkinsSource.builds.length; j++) {
                        allStates.push(jenkinsSource.builds[j].state)
                    }
                } else if (jenkinsSource.status) {
                    allStates.push(jenkinsSource.status)
                }
            }
        }

        servers = serverSummaries
        totalBuilds = count
        overall = Jenkins.aggregate(allStates)
    }

    function configure() {
        const configureAction = Plasmoid.internalAction("configure")
        if (configureAction) {
            configureAction.trigger()
        }
    }

    function reload() {
        try {
            const configuredEntries = JSON.parse(plasmoid.configuration.servers)
            const nextEntries = Array.isArray(configuredEntries) ? configuredEntries : []
            if (JSON.stringify(nextEntries) !== JSON.stringify(entries)) {
                entries = nextEntries
            }
            configError = ""
        } catch (error) {
            entries = []
            configError = "Invalid server configuration."
        }
    }

    function refresh() {
        for (let sourceIndex = 0; sourceIndex < sources.count; ++sourceIndex) {
            const jenkinsSource = sources.objectAt(sourceIndex)
            if (jenkinsSource) {
                jenkinsSource.refresh()
            }
        }
    }

    Instantiator {
        id: sources
        model: root.entries
        delegate: JenkinsSource {
            required property var modelData
            entry: modelData
            wallet: root.wallet
            pollInterval: plasmoid.configuration.pollInterval
            onChanged: Qt.callLater(root.collect)
        }

        onObjectAdded: Qt.callLater(root.collect)
        onObjectRemoved: Qt.callLater(root.collect)
    }

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            source: Qt.resolvedUrl("../images/jenkins.svg")
            isMask: true
            color: root.tint(root.overall)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: "Jenkins"
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: Kirigami.Units.gridUnit * 0.7
                height: width
                radius: width / 2
                color: root.tint(root.overall)
                Layout.alignment: Qt.AlignVCenter
            }

            Controls.Label {
                Layout.fillWidth: true
                text: root.label(root.overall)
                color: root.tint(root.overall)
                font.bold: true
            }

            Controls.Label {
                text: root.totalBuilds + (root.totalBuilds === 1 ? " build" : " builds")
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            visible: root.entries.length === 0
            text: root.configError || "Add Jenkins servers in the widget settings to monitor builds."
            wrapMode: Text.WordWrap
        }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.mediumSpacing

                Repeater {
                    model: root.servers
                    delegate: ColumnLayout {
                        id: serverSection
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Separator {
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Controls.Label {
                                Layout.fillWidth: true
                                text: serverSection.modelData.name
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Controls.Button {
                                text: "Open Jenkins"
                                icon.name: "internet-services"
                                display: Controls.AbstractButton.IconOnly
                                Controls.ToolTip.text: "Open " + serverSection.modelData.url
                                Controls.ToolTip.visible: hovered
                                onClicked: Qt.openUrlExternally(serverSection.modelData.url)
                            }
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            text: root.label(serverSection.modelData.state)
                                + (serverSection.modelData.updated
                                    ? " · Last update " + serverSection.modelData.updated
                                    : "")
                            color: root.tint(serverSection.modelData.state)
                            font: Kirigami.Theme.smallFont
                            wrapMode: Text.WordWrap
                        }

                        Controls.Label {
                            Layout.fillWidth: true
                            visible: serverSection.modelData.error !== ""
                            text: serverSection.modelData.error
                            textFormat: Text.PlainText
                            color: Kirigami.Theme.negativeTextColor
                            wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: serverSection.modelData.builds
                            delegate: BuildRow {
                                id: buildDelegate
                                required property var modelData
                                build: modelData
                                statusColor: root.tint(modelData.state)
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: plasmoid.configuration
        function onServersChanged() {
            root.reload()
            root.persistSettings()
        }
        function onPollIntervalChanged() {
            root.persistSettings()
        }
    }

    Component.onCompleted: initializeSettings()
}
