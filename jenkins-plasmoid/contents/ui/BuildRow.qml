import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../code/Jenkins.js" as Jenkins

RowLayout {
    id: buildRow

    required property var build
    required property color statusColor

    Layout.fillWidth: true
    Layout.minimumHeight: Kirigami.Units.gridUnit * 2.2
    spacing: Kirigami.Units.mediumSpacing

    readonly property var statusLabels: ({
        success: "Success",
        failure: "Failed",
        unstable: "Unstable",
        building: "Building",
        aborted: "Aborted",
        unknown: "Unknown"
    })

    Controls.Label {
        id: statusBadge

        Layout.preferredWidth: badgeMetrics.advanceWidth("Building") + Kirigami.Units.largeSpacing * 2
        Layout.alignment: Qt.AlignVCenter
        text: buildRow.statusLabels[buildRow.build.state] || "Unknown"
        color: buildRow.statusColor
        font: Kirigami.Theme.smallFont
        horizontalAlignment: Text.AlignHCenter
        topPadding: Kirigami.Units.smallSpacing
        bottomPadding: Kirigami.Units.smallSpacing

        background: Rectangle {
            radius: Kirigami.Units.smallSpacing
            color: statusBadge.color
            opacity: 0.15
        }

        FontMetrics {
            id: badgeMetrics
            font: statusBadge.font
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                Layout.fillWidth: true
                text: buildRow.build.name + (buildRow.build.buildNumber ? " " + buildRow.build.buildNumber : "")
                textFormat: Text.PlainText
                font.bold: true
                elide: Text.ElideRight
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: {
                const details = []
                if (buildRow.build.duration) {
                    details.push("Duration: " + buildRow.build.duration)
                }
                if (buildRow.build.timestamp) {
                    details.push(Jenkins.formatRelativeTime(buildRow.build.timestamp))
                }
                if (buildRow.build.health) {
                    details.push(buildRow.build.health)
                }
                return details.join(" · ")
            }
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
    }

    Controls.Button {
        id: jumpButton
        Layout.alignment: Qt.AlignVCenter
        text: "Open Build"
        icon.name: "network-connect"
        display: Controls.AbstractButton.TextBesideIcon
        Controls.ToolTip.text: "Jump to build page"
        Controls.ToolTip.visible: hovered
        onClicked: {
            if (buildRow.build.buildUrl) {
                Qt.openUrlExternally(buildRow.build.buildUrl)
            } else if (buildRow.build.jobUrl) {
                Qt.openUrlExternally(buildRow.build.jobUrl)
            }
        }
    }
}
