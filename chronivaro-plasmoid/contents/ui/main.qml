import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.dbus as PlasmaDBus

PlasmoidItem {
    id: root

    property bool running: false
    property bool reachable: false
    property bool loading: false
    property bool actionInProgress: false

    property string activeToken: ""
    property bool kwalletChecked: false

    property var currentWorkEntry: null

    property int todayTargetMinutes: 0
    property int todayActualMinutes: 0
    property int todayBalanceMinutes: 0

    property int monthTargetMinutes: 0
    property int monthActualMinutes: 0
    property int monthBalanceMinutes: 0

    property string errorMessage: ""
    property string actionErrorMessage: ""

    readonly property var workingLocations: [
        "OFFICE",
        "HOME_OFFICE",
        "FIELD",
        "REMOTE"
    ]

    preferredRepresentation: compactRepresentation

    toolTipMainText: "Chronivaro"
    toolTipSubText: {
        if (!reachable) {
            return "Chronivaro unavailable"
        }

        return running ? "Timer running" : "Timer stopped"
    }

    readonly property string walletAppId: "Chronivaro"
    readonly property string walletFolder: "Chronivaro"
    readonly property string walletKey: "token"

    function callDBus(member, signature, args, resolve, reject) {
        PlasmaDBus.SessionBus.asyncCall({
            service: "org.kde.kwalletd6",
            path: "/modules/kwalletd6",
            iface: "org.kde.KWallet",
            member: member,
            signature: "(" + signature + ")",
            arguments: args
        }, function(reply) {
            const val = (reply && reply.value !== undefined) ? reply.value : reply
            if (resolve) resolve(val !== null && typeof val === "object" && val.value !== undefined ? val.value : val)
        }, function(err) {
            if (err && err.error) err = err.error
            let msg = ""
            if (err) {
                if (err.message) {
                    msg = err.message
                } else if (err.name) {
                    msg = err.name
                } else if (typeof err === "object") {
                    try {
                        msg = JSON.stringify(err)
                    } catch (e) {
                        msg = String(err)
                    }
                } else {
                    msg = String(err)
                }
            } else {
                msg = "Unknown D-Bus error"
            }
            if (reject) reject(msg)
        })
    }

    function resolveToken(callback) {
        if (activeToken) {
            callback(activeToken)
            return
        }

        callDBus("networkWallet", "", [], function(walletName) {
            const name = (walletName && walletName.length > 0) ? walletName : "kdewallet"
            callDBus("open", "sxs", [name, 0, walletAppId], function(handle) {
                if (typeof handle !== "number" || handle < 0) {
                    fallbackConfigToken(callback)
                    return
                }

                callDBus("hasFolder", "iss", [handle, walletFolder, walletAppId], function(has) {
                    if (!has) {
                        callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                        fallbackConfigToken(callback)
                        return
                    }

                    callDBus("readPassword", "isss", [handle, walletFolder, walletKey, walletAppId], function(pass) {
                        callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                        if (pass && pass.length > 0) {
                            activeToken = pass
                            kwalletChecked = true
                            callback(pass)
                        } else {
                            fallbackConfigToken(callback)
                        }
                    }, function(err) {
                        callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                        fallbackConfigToken(callback)
                    })
                }, function(err) {
                    callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                    fallbackConfigToken(callback)
                })
            }, function(err) {
                fallbackConfigToken(callback)
            })
        }, function(err) {
            fallbackConfigToken(callback)
        })
    }

    function fallbackConfigToken(callback) {
        kwalletChecked = true
        activeToken = plasmoid.configuration.token || ""
        callback(activeToken)
    }

    function formatMinutes(minutes) {
        const sign = minutes < 0 ? "-" : "+"
        const absolute = Math.abs(minutes)
        const hours = Math.floor(absolute / 60)
        const mins = absolute % 60

        return sign + hours + "h " + mins.toString().padStart(2, "0") + "m"
    }

    function formatDuration(minutes) {
        const hours = Math.floor(minutes / 60)
        const mins = minutes % 60

        return hours + "h " + mins.toString().padStart(2, "0") + "m"
    }

    function formatStartTime(value) {
        if (!value) {
            return ""
        }

        const date = new Date(value)
        return Qt.formatTime(date, "HH:mm")
    }

    function refresh() {
        resolveToken(function(tok) {
            if (!tok) {
                reachable = false
                errorMessage = "No API token configured or stored in KWallet"
                return
            }

            loading = true

            const request = new XMLHttpRequest()

            request.onreadystatechange = function() {
                if (request.readyState !== XMLHttpRequest.DONE) {
                    return
                }

                loading = false

                if (request.status < 200 || request.status >= 300) {
                    reachable = false
                    errorMessage = "HTTP " + request.status + ": " + request.statusText
                    return
                }

                try {
                    const data = JSON.parse(request.responseText)

                    reachable = true
                    errorMessage = ""

                    running = data.running === true
                    currentWorkEntry = data.currentWorkEntry || null

                    if (data.today) {
                        todayTargetMinutes = data.today.targetMinutes || 0
                        todayActualMinutes = data.today.actualMinutes || 0
                        todayBalanceMinutes = data.today.dayBalanceMinutes || 0
                    }

                    if (data.month) {
                        monthTargetMinutes = data.month.targetMinutesToDate || 0
                        monthActualMinutes = data.month.actualMinutesToDate || 0
                        monthBalanceMinutes = data.month.periodBalanceMinutes || 0
                    }
                } catch (e) {
                    reachable = false
                    errorMessage = "Invalid response: " + e
                }
            }

            request.open("GET", plasmoid.configuration.endpoint)
            request.setRequestHeader(
                "Authorization",
                "Bearer " + tok
            )
            request.setRequestHeader("Accept", "application/json")
            request.send()
        })
    }

    function actionEndpoint(action) {
        const statusEndpoint = plasmoid.configuration.endpoint.replace(/\/$/, "")

        if (statusEndpoint.endsWith("/status")) {
            return statusEndpoint.slice(0, -"/status".length) + "/" + action
        }

        return statusEndpoint + "/" + action
    }

    function performTimerAction(action, workingLocation, comment) {
        resolveToken(function(tok) {
            if (!tok
                    || actionInProgress
                    || loading
                    || !reachable) {
                return
            }

            actionInProgress = true
            actionErrorMessage = ""

            const request = new XMLHttpRequest()

            request.onreadystatechange = function() {
                if (request.readyState !== XMLHttpRequest.DONE) {
                    return
                }

                actionInProgress = false

                if (request.status < 200 || request.status >= 300) {
                    const response = request.responseText
                        ? ": " + request.responseText.slice(0, 300)
                        : ""
                    actionErrorMessage =
                        "HTTP " + request.status + " " + request.statusText + response
                    return
                }

                actionComment.clear()
                refresh()
            }

            const body = action === "start"
                ? {
                    "workingLocation": workingLocation,
                    "comment": comment,
                    "isOnCall": false
                }
                : {
                    "comment": comment
                }

            request.open("POST", actionEndpoint(action))
            request.setRequestHeader(
                "Authorization",
                "Bearer " + tok
            )
            request.setRequestHeader("Content-Type", "application/json")
            request.setRequestHeader("Accept", "application/json")
            request.send(JSON.stringify(body))
        })
    }

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: Kirigami.Units.iconSizes.smallMedium

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            source: Qt.resolvedUrl("../images/chronivaro.svg")
            isMask: true

            color: {
                if (!root.reachable) {
                    return Kirigami.Theme.disabledTextColor
                }

                return root.running ? "#27ae60" : "#c0392b"
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                root.refresh()
                root.expanded = !root.expanded
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: implicitHeight
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Layout.preferredWidth
                source: Qt.resolvedUrl("../images/chronivaro.svg")
                isMask: true

                color: {
                    if (!root.reachable) {
                        return Kirigami.Theme.disabledTextColor
                    }

                    return root.running ? "#27ae60" : "#c0392b"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Kirigami.Heading {
                    level: 2

                    text: {
                        if (!root.reachable) {
                            return "Unavailable"
                        }

                        return root.running ? "Working" : "Not working"
                    }
                }

                PlasmaComponents.Label {
                    visible: root.running && root.currentWorkEntry !== null
                    text: root.currentWorkEntry
                        ? "Since " + root.formatStartTime(root.currentWorkEntry.start)
                        : ""
                    opacity: 0.7
                }
            }

            Controls.ToolButton {
                icon.name: "configure"
                onClicked: {
                    const cfgAction = Plasmoid.internalAction("configure")
                    if (cfgAction) {
                        cfgAction.trigger()
                    }
                }

                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: "Configure…"
            }

            Controls.ToolButton {
                icon.name: "view-refresh"
                enabled: !root.loading
                onClicked: root.refresh()

                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: "Refresh"
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                visible: !root.running
                Layout.fillWidth: true

                PlasmaComponents.Label {
                    text: "Working location"
                }

                Controls.ComboBox {
                    id: locationSelector
                    Layout.fillWidth: true
                    model: root.workingLocations
                    currentIndex: Math.max(
                        0,
                        root.workingLocations.indexOf(
                            plasmoid.configuration.workingLocation
                        )
                    )

                    onActivated: {
                        plasmoid.configuration.workingLocation = currentValue
                    }
                }
            }

            Controls.TextField {
                id: actionComment
                Layout.fillWidth: true
                enabled: !root.actionInProgress
                placeholderText: root.running
                    ? "Stop comment (optional)"
                    : "Start comment (optional)"
                onAccepted: {
                    if (actionButton.enabled) {
                        actionButton.clicked()
                    }
                }
            }

            Controls.Button {
                id: actionButton
                Layout.fillWidth: true
                enabled: root.reachable
                    && !root.loading
                    && !root.actionInProgress
                text: root.actionInProgress
                    ? (root.running ? "Stopping…" : "Starting…")
                    : (root.running ? "Stop timer" : "Start timer")
                icon.name: root.running
                    ? "media-playback-stop"
                    : "media-playback-start"

                onClicked: root.performTimerAction(
                    root.running ? "stop" : "start",
                    locationSelector.currentValue,
                    actionComment.text
                )
            }

            Kirigami.InlineMessage {
                id: actionErrorInline
                visible: root.actionErrorMessage !== ""
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                showCloseButton: true
                text: root.actionErrorMessage

                contentItem: Kirigami.SelectableLabel {
                    text: actionErrorInline.text
                    wrapMode: Text.WordWrap
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2

            PlasmaComponents.Label {
                text: "Today"
                font.bold: true
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignRight
                text: root.formatMinutes(root.todayBalanceMinutes)
                font.bold: true
            }

            PlasmaComponents.Label {
                text: "Worked"
                opacity: 0.7
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignRight
                text: root.formatDuration(root.todayActualMinutes)
            }

            PlasmaComponents.Label {
                text: "Target"
                opacity: 0.7
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignRight
                text: root.formatDuration(root.todayTargetMinutes)
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2

            PlasmaComponents.Label {
                text: "Month"
                font.bold: true
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignRight
                text: root.formatMinutes(root.monthBalanceMinutes)
                font.bold: true
            }

            PlasmaComponents.Label {
                text: "Worked"
                opacity: 0.7
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignRight
                text: root.formatDuration(root.monthActualMinutes)
            }

            PlasmaComponents.Label {
                text: "Target"
                opacity: 0.7
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignRight
                text: root.formatDuration(root.monthTargetMinutes)
            }
        }

        Kirigami.InlineMessage {
            id: statusErrorInline
            visible: !root.reachable && root.errorMessage !== ""
            Layout.fillWidth: true
            type: Kirigami.MessageType.Error
            showCloseButton: false
            text: root.errorMessage

            contentItem: Kirigami.SelectableLabel {
                text: statusErrorInline.text
                wrapMode: Text.WordWrap
            }
        }
    }

    Timer {
        interval: Math.max(5, plasmoid.configuration.pollInterval) * 1000
        running: true
        repeat: true
        onTriggered: {
            if (!root.actionInProgress) {
                root.refresh()
            }
        }
    }

    Connections {
        target: plasmoid.configuration
        function onTokenChanged() {
            root.activeToken = ""
            root.kwalletChecked = false
            root.refresh()
        }
        function onEndpointChanged() {
            root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
