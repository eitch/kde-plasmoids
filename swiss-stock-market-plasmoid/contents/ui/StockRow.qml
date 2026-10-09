import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../code/Market.js" as Market

Rectangle {
    id: card

    required property var quote
    property bool expanded: false

    Layout.fillWidth: true
    implicitWidth: layout.implicitWidth + Kirigami.Units.smallSpacing * 4
    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2
    color: Kirigami.Theme.alternateBackgroundColor
    border.color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.15)
    border.width: 1
    radius: 4

    function stateColor(quoteState) {
        if (quoteState === "up") return "#27ae60"
        if (quoteState === "down") return "#da4453"
        return Kirigami.Theme.disabledTextColor
    }

    function stateSymbol(quoteState) {
        if (quoteState === "up") return "▲"
        if (quoteState === "down") return "▼"
        return "–"
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // Main row
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            // Left side: Symbol, Name, Market Badge
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        text: card.quote ? card.quote.symbol : ""
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }

                    Rectangle {
                        color: Kirigami.Theme.alternateBackgroundColor
                        radius: 3
                        implicitWidth: marketLabel.implicitWidth + 8
                        implicitHeight: marketLabel.implicitHeight + 4

                        Controls.Label {
                            id: marketLabel
                            anchors.centerIn: parent
                            text: card.quote ? card.quote.market : "SIX"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: card.quote ? card.quote.name : ""
                    elide: Text.ElideRight
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            // Right side: Price and Change Pill
            ColumnLayout {
                spacing: 2
                Layout.alignment: Qt.AlignRight

                Controls.Label {
                    Layout.alignment: Qt.AlignRight
                    text: card.quote ? card.quote.formattedPrice : "—"
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
                }

                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    radius: 4
                    color: {
                        const st = card.quote ? card.quote.state : "unknown"
                        if (st === "up") return Qt.rgba(0.15, 0.68, 0.38, 0.2)
                        if (st === "down") return Qt.rgba(0.85, 0.27, 0.33, 0.2)
                        return Qt.rgba(0.5, 0.5, 0.5, 0.15)
                    }
                    implicitWidth: changeLabel.implicitWidth + 8
                    implicitHeight: changeLabel.implicitHeight + 4

                    Controls.Label {
                        id: changeLabel
                        anchors.centerIn: parent
                        text: {
                            if (!card.quote) return "—"
                            const arrow = card.stateSymbol(card.quote.state)
                            return arrow + " " + (card.quote.formattedPercent !== "—" ? card.quote.formattedPercent : card.quote.formattedChange)
                        }
                        font.bold: true
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        color: card.stateColor(card.quote ? card.quote.state : "unknown")
                    }
                }
            }
        }

        // Expanded details
        ColumnLayout {
            Layout.fillWidth: true
            visible: card.expanded
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.alternateBackgroundColor
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 4
                columnSpacing: Kirigami.Units.largeSpacing

                Controls.Label {
                    text: "Day Range:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                Controls.Label {
                    text: {
                        if (!card.quote || card.quote.low === null || card.quote.high === null) return "—"
                        return Market.formatPrice(card.quote.low) + " – " + Market.formatPrice(card.quote.high)
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                Controls.Label {
                    text: "Prev Close / Open:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                Controls.Label {
                    text: {
                        if (!card.quote) return "—"
                        const pc = card.quote.prevClose !== null ? Market.formatPrice(card.quote.prevClose) : "—"
                        const op = card.quote.open !== null ? Market.formatPrice(card.quote.open) : "—"
                        return pc + " / " + op
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                Controls.Label {
                    text: "Absolute Change:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                Controls.Label {
                    text: card.quote ? card.quote.formattedChange : "—"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: card.stateColor(card.quote ? card.quote.state : "unknown")
                }

                Controls.Label {
                    text: "Volume:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                Controls.Label {
                    text: {
                        if (!card.quote || card.quote.volume === null) return "—"
                        return card.quote.volume.toLocaleString()
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                }

                Controls.Label {
                    text: "Last Updated:"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                Controls.Label {
                    text: {
                        if (!card.quote) return "—"
                        if (card.quote.timestamp) return String(card.quote.timestamp)
                        return "—"
                    }
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.expanded = !card.expanded
        cursorShape: Qt.PointingHandCursor
    }
}
