import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../code/Jenkins.js" as Jenkins

KCM.SimpleKCM {
    id: config

    property string cfg_servers: "[]"
    property alias cfg_pollInterval: interval.value
    property bool cfg_settingsSaved: false
    property string cfg_serversDefault: "[]"
    property int cfg_pollIntervalDefault: 60
    property bool cfg_settingsSavedDefault: false
    property var entries: []
    property string message: ""
    readonly property var authTypes: ["token", "password", "anonymous"]

    function load() {
        try {
            entries = JSON.parse(cfg_servers)
        } catch (error) {
            entries = []
            message = "Invalid saved configuration."
        }
    }

    function update(entryIndex, fieldName, fieldValue) {
        const updatedEntries = entries.slice()
        updatedEntries[entryIndex][fieldName] = fieldValue
        cfg_servers = JSON.stringify(updatedEntries)
    }

    onCfg_serversChanged: {
        if (JSON.stringify(entries) !== cfg_servers) {
            load()
        }
    }

    Component.onCompleted: load()

    Wallet {
        id: wallet
    }

    ColumnLayout {
        spacing: Kirigami.Units.mediumSpacing

        Controls.Label {
            Layout.fillWidth: true
            text: "Add Jenkins server URLs, views, or job URLs to monitor build statuses. Credentials and API tokens are securely stored in KWallet."
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Controls.Label {
                text: "Refresh interval (seconds)"
            }

            Controls.SpinBox {
                id: interval
                from: 10
                to: 3600
                value: 60
                editable: true
            }
        }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: 420
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.largeSpacing

                Repeater {
                    model: config.entries
                    delegate: Controls.GroupBox {
                        id: serverBox
                        required property int index
                        required property var modelData
                        property bool saving: false
                        Layout.fillWidth: true
                        title: "Jenkins Server " + (index + 1)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Controls.TextField {
                                Layout.fillWidth: true
                                placeholderText: "Display name (e.g. Production CI)"
                                text: serverBox.modelData.name || ""
                                onTextEdited: config.update(serverBox.index, "name", text)
                            }

                            Controls.ComboBox {
                                id: authTypeSelector
                                Layout.fillWidth: true
                                model: [
                                    "API Token (Username + Token)",
                                    "Username & Password",
                                    "Anonymous (No authentication)"
                                ]
                                currentIndex: Math.max(0, config.authTypes.indexOf(serverBox.modelData.type || "token"))
                                onActivated: config.update(serverBox.index, "type", config.authTypes[currentIndex])
                            }

                            Controls.TextField {
                                Layout.fillWidth: true
                                placeholderText: "https://jenkins.example.com or https://jenkins.example.com/view/MyView"
                                text: serverBox.modelData.url || ""
                                onTextEdited: config.update(serverBox.index, "url", text)
                            }

                            Controls.TextField {
                                visible: authTypeSelector.currentIndex !== 2
                                Layout.fillWidth: true
                                placeholderText: "Username"
                                text: serverBox.modelData.username || ""
                                onTextEdited: config.update(serverBox.index, "username", text)
                            }

                            RowLayout {
                                visible: authTypeSelector.currentIndex !== 2
                                Layout.fillWidth: true

                                Controls.TextField {
                                    id: secretField
                                    Layout.fillWidth: true
                                    echoMode: TextInput.Password
                                    placeholderText: authTypeSelector.currentIndex === 0 ? "Jenkins API token" : "Password"
                                }

                                Controls.Button {
                                    text: serverBox.saving ? "Saving…" : "Save to KWallet"
                                    enabled: !serverBox.saving && secretField.text.length > 0
                                    onClicked: {
                                        try {
                                            const walletStorageKey = Jenkins.walletKey(serverBox.modelData)
                                            serverBox.saving = true
                                            wallet.access(walletStorageKey, secretField.text, true, function(errorMessage) {
                                                serverBox.saving = false
                                                if (errorMessage) {
                                                    config.message = errorMessage
                                                } else {
                                                    secretField.text = ""
                                                    config.message = "Credentials saved to KWallet for " + (serverBox.modelData.name || serverBox.modelData.url) + "."
                                                }
                                            })
                                        } catch (error) {
                                            serverBox.saving = false
                                            config.message = error.message
                                        }
                                    }
                                }
                            }

                            Controls.Button {
                                text: "Remove Server"
                                icon.name: "edit-delete"
                                onClicked: {
                                    const updatedEntries = config.entries.slice()
                                    updatedEntries.splice(serverBox.index, 1)
                                    config.cfg_servers = JSON.stringify(updatedEntries)
                                }
                            }
                        }
                    }
                }

                Controls.Button {
                    text: "Add Jenkins Server"
                    icon.name: "list-add"
                    onClicked: {
                        const updatedEntries = config.entries.slice()
                        updatedEntries.push({
                            name: "",
                            url: "",
                            type: "token",
                            username: ""
                        })
                        config.cfg_servers = JSON.stringify(updatedEntries)
                    }
                }

                Controls.Label {
                    Layout.fillWidth: true
                    visible: config.message !== ""
                    text: config.message
                    color: Kirigami.Theme.highlightColor
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
