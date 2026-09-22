import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

RowLayout {
    id: monitorRow

    required property var monitor
    required property color statusColor

    Layout.fillWidth: true
    Layout.minimumHeight: Kirigami.Units.gridUnit * 2
    spacing: Kirigami.Units.largeSpacing

    readonly property var statusLabels: ({
        up: "Up",
        down: "Down",
        pending: "Pending",
        maintenance: "Maintenance",
        paused: "Paused",
        "no-data": "No data"
    })

    Controls.Label {
        id: statusBadge

        Layout.preferredWidth: badgeMetrics.advanceWidth("Maintenance") + Kirigami.Units.largeSpacing * 2
        Layout.alignment: Qt.AlignVCenter
        text: monitorRow.statusLabels[monitorRow.monitor.state] || "Unknown"
        color: monitorRow.statusColor
        font: Kirigami.Theme.smallFont
        horizontalAlignment: Text.AlignHCenter
        topPadding: Kirigami.Units.smallSpacing
        bottomPadding: Kirigami.Units.smallSpacing

        background: Rectangle {
            radius: Kirigami.Units.smallSpacing
            color: statusBadge.color
            opacity: 0.12
        }

        FontMetrics {
            id: badgeMetrics
            font: statusBadge.font
        }
    }

    Controls.Label {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: monitorRow.monitor.name
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
}
