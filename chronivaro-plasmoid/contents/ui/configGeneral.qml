import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.workspace.dbus as PlasmaDBus

KCM.SimpleKCM {
    id: configRoot

    property alias cfg_endpoint: endpoint.text
    property alias cfg_token: token.text
    property alias cfg_pollInterval: pollInterval.value
    property string cfg_workingLocation: "OFFICE"

    property string cfg_endpointDefault
    property string cfg_tokenDefault
    property int cfg_pollIntervalDefault
    property string cfg_workingLocationDefault

    readonly property string walletAppId: "Chronivaro"
    readonly property string walletFolder: "Chronivaro"
    readonly property string walletKey: "token"
    property string walletStatusMessage: ""
    property var connectionRequest: null
    property string connectionMessage: ""
    property bool connectionSucceeded: false

    Timer {
        id: connectionTimeout
        interval: 15000
        onTriggered: {
            const request = configRoot.connectionRequest
            configRoot.finishConnectionTest(false, "Connection timed out. Check the URL and network connection.")
            if (request) request.abort()
        }
    }

    Component.onDestruction: {
        const request = connectionRequest
        connectionRequest = null
        if (request) request.abort()
    }

    Controls.Dialog {
        id: connectionDialog
        parent: Controls.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(Kirigami.Units.gridUnit * 28, parent.width - Kirigami.Units.largeSpacing * 2)
        modal: true
        title: configRoot.connectionSucceeded ? "Connection successful" : "Connection failed"
        standardButtons: Controls.Dialog.Ok

        contentItem: Kirigami.SelectableLabel {
            text: configRoot.connectionMessage
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
        }
    }

    function finishConnectionTest(success, message) {
        connectionTimeout.stop()
        connectionRequest = null
        connectionSucceeded = success
        connectionMessage = message
        connectionDialog.open()
    }

    function testConnection() {
        if (connectionRequest) return
        const url = endpoint.text.trim()
        const tokenVal = token.text.trim()
        if (!/^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/i.test(url)) {
            finishConnectionTest(false, "Please enter a valid HTTP or HTTPS REST endpoint URL.")
            return
        }
        if (!tokenVal) {
            finishConnectionTest(false, "Please enter the API token to test.")
            return
        }

        const request = new XMLHttpRequest()
        connectionRequest = request
        request.onreadystatechange = function() {
            if (connectionRequest !== request || request.readyState !== XMLHttpRequest.DONE) return
            if (request.status === 0) {
                finishConnectionTest(false, "Unable to connect. Check the URL, network connection and TLS certificate.")
            } else if (request.status === 401 || request.status === 403) {
                finishConnectionTest(false, "Authentication or access denied (HTTP " + request.status + "). Check the token and its permissions.")
            } else if (request.status < 200 || request.status >= 300) {
                finishConnectionTest(false, "The server returned HTTP " + request.status + ". Check the REST endpoint URL.")
            } else {
                try {
                    const data = JSON.parse(request.responseText)
                    if (!data || typeof data.running !== "boolean" || !data.today || !data.month) {
                        finishConnectionTest(false, "The URL did not return a Chronivaro status response.")
                        return
                    }
                    finishConnectionTest(true, "Successfully connected to Chronivaro using the entered URL and API token.")
                } catch (e) {
                    finishConnectionTest(false, "The server did not return valid JSON. Check the REST endpoint URL.")
                }
            }
        }
        try {
            request.open("GET", url)
            request.setRequestHeader("Authorization", "Bearer " + tokenVal)
            request.setRequestHeader("Accept", "application/json")
            connectionTimeout.start()
            request.send()
        } catch (e) {
            finishConnectionTest(false, "Unable to send the request. Check the URL and token format.")
            request.abort()
        }
    }

    onWalletStatusMessageChanged: {
        if (walletStatusMessage !== "") walletStatusDialog.open()
    }

    Controls.Dialog {
        id: walletStatusDialog
        parent: Controls.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(Kirigami.Units.gridUnit * 28, parent.width - Kirigami.Units.largeSpacing * 2)
        modal: true
        title: configRoot.walletStatusMessage === "Token saved to KWallet successfully!"
            ? "KWallet — Token saved" : "KWallet — Unable to save token"
        standardButtons: Controls.Dialog.Ok

        contentItem: Kirigami.SelectableLabel {
            text: configRoot.walletStatusMessage
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
        }
    }

    function callDBus(member, signature, args, resolve, reject) {
        PlasmaDBus.SessionBus.asyncCall({
            service: "org.kde.kwalletd6",
            path: "/modules/kwalletd6",
            iface: "org.kde.KWallet",
            member: member,
            signature: "(" + signature + ")",
            arguments: args
        }, function (reply) {
            const val = (reply && reply.value !== undefined) ? reply.value : reply
            if (resolve) resolve(val !== null && typeof val === "object" && val.value !== undefined ? val.value : val)
        }, function (err) {
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

    function saveTokenToWallet() {
        walletStatusMessage = ""
        const tokenVal = token.text.trim()
        if (!tokenVal) {
            walletStatusMessage = "Please enter a token first."
            return
        }

        callDBus("networkWallet", "", [], function (walletName) {
            const name = (walletName && walletName.length > 0) ? walletName : "kdewallet"
            callDBus("open", "sxs", [name, 0, walletAppId], function (handle) {
                if (typeof handle !== "number" || handle < 0) {
                    walletStatusMessage = "Failed to open KWallet."
                    return
                }

                function doWrite() {
                    callDBus("writePassword", "issss", [handle, walletFolder, walletKey, tokenVal, walletAppId], function (res) {
                        callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                        if (res === 0) {
                            walletStatusMessage = "Token saved to KWallet successfully!"
                        } else {
                            walletStatusMessage = "Failed to write token to KWallet."
                        }
                    }, function (err) {
                        callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                        walletStatusMessage = "Error writing to KWallet: " + (err ? (err.message || err) : "")
                    })
                }

                callDBus("hasFolder", "iss", [handle, walletFolder, walletAppId], function (has) {
                    if (!has) {
                        callDBus("createFolder", "iss", [handle, walletFolder, walletAppId], function (created) {
                            if (created) {
                                doWrite()
                            } else {
                                callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                                walletStatusMessage = "Failed to create folder in KWallet."
                            }
                        }, function (err) {
                            callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                            walletStatusMessage = "Error creating folder: " + (err ? (err.message || err) : "")
                        })
                    } else {
                        doWrite()
                    }
                }, function (err) {
                    callDBus("close", "ibs", [handle, false, walletAppId], null, null)
                    walletStatusMessage = "Error checking folder: " + (err ? (err.message || err) : "")
                })
            }, function (err) {
                walletStatusMessage = "Error opening KWallet: " + (err ? (err.message || err) : "")
            })
        }, function (err) {
            walletStatusMessage = "Error accessing KWallet service: " + (err ? (err.message || err) : "")
        })
    }

    readonly property var workingLocations: [
        "OFFICE",
        "HOME_OFFICE",
        "FIELD",
        "REMOTE"
    ]

    Kirigami.FormLayout {
        Controls.TextField {
            id: endpoint
            Kirigami.FormData.label: "REST endpoint:"
            Layout.fillWidth: true
        }

        Controls.TextField {
            id: token
            Kirigami.FormData.label: "API token:"
            Layout.fillWidth: true
            placeholderText: "<tokenId>:<tokenSecret>"
            echoMode: TextInput.Password
        }

        RowLayout {
            Kirigami.FormData.label: "KWallet integration:"
            Layout.fillWidth: true

            Controls.Button {
                text: "Save Token to KWallet"
                icon.name: "security-high"
                onClicked: configRoot.saveTokenToWallet()
            }
        }

        Controls.Button {
            text: configRoot.connectionRequest ? "Testing…" : "Test Connection"
            icon.name: "network-connect"
            enabled: !configRoot.connectionRequest
            onClicked: configRoot.testConnection()
        }

        Controls.SpinBox {
            id: pollInterval
            Kirigami.FormData.label: "Refresh interval:"
            from: 5
            to: 3600

            textFromValue: function (value) {
                return value + " s"
            }

            valueFromText: function (text) {
                return parseInt(text)
            }
        }

        Controls.ComboBox {
            id: workingLocation
            Kirigami.FormData.label: "Default working location:"
            model: workingLocations
            currentIndex: Math.max(0, workingLocations.indexOf(cfg_workingLocation))

            onActivated: cfg_workingLocation = currentValue
        }
    }
}
