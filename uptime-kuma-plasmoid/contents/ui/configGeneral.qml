import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../code/Kuma.js" as Kuma

KCM.SimpleKCM {
    id: config

    property string cfg_dashboards: "[]"
    property alias cfg_pollInterval: interval.value
    property string cfg_browser: ""
    property bool cfg_settingsSaved: false
    property string cfg_dashboardsDefault: "[]"
    property int cfg_pollIntervalDefault: 60
    property string cfg_browserDefault: ""
    property bool cfg_settingsSavedDefault: false
    property var entries: []
    property string message: ""
    readonly property var sourceTypes: ["public", "admin", "password"]

    function load() {
        try {
            entries = JSON.parse(cfg_dashboards)
        } catch (error) {
            entries = []
            message = "Invalid saved configuration."
        }
    }

    function update(entryIndex, fieldName, fieldValue) {
        const updatedEntries = entries.slice()
        updatedEntries[entryIndex][fieldName] = fieldValue
        cfg_dashboards = JSON.stringify(updatedEntries)
    }

    onCfg_dashboardsChanged: {
        // Avoid recreating focused delegates on every keystroke.
        if (JSON.stringify(entries) !== cfg_dashboards) {
            load()
        }
    }

    Component.onCompleted: load()

    data: [
        Wallet {
            id: wallet
        }
    ]

    ColumnLayout {
        spacing: Kirigami.Units.mediumSpacing

        Controls.Label {
            Layout.fillWidth: true
            text: "Add public status pages and administration dashboards. API keys and passwords are stored only in KWallet."
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

    RowLayout {
        Layout.fillWidth: true

        Controls.Label {
            text: "Web browser:"
        }

        Controls.ComboBox {
            id: browserCombo
            Layout.fillWidth: true
            textRole: "name"
            valueRole: "id"
            model: [
                { id: "", name: "System Default" },
                { id: "brave", name: "Brave" },
                { id: "firefox", name: "Mozilla Firefox" },
                { id: "google-chrome", name: "Google Chrome" },
                { id: "chromium", name: "Chromium" },
                { id: "custom", name: "Custom Command..." }
            ]
            currentIndex: {
                const val = (config.cfg_browser || "").trim()
                for (let i = 0; i < model.length - 1; i++) {
                    if (model[i].id === val) return i
                }
                return model.length - 1
            }
            onActivated: {
                const selectedId = model[currentIndex].id
                if (selectedId !== "custom") {
                    config.cfg_browser = selectedId
                } else {
                    config.cfg_browser = customBrowserField.text.trim() || "brave"
                }
                console.log("[Kuma Settings] Web browser changed to:", config.cfg_browser)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: browserCombo.currentIndex === browserCombo.model.length - 1

        Controls.Label {
            text: "Custom command:"
        }

        Controls.TextField {
            id: customBrowserField
            Layout.fillWidth: true
            placeholderText: "e.g. brave, firefox, or /usr/bin/brave %u"
            text: {
                const val = (config.cfg_browser || "").trim()
                const standardIds = ["", "brave", "firefox", "google-chrome", "chromium"]
                if (standardIds.indexOf(val) === -1) {
                    return val
                }
                return ""
            }
            onTextChanged: {
                if (browserCombo.currentIndex === browserCombo.model.length - 1) {
                    config.cfg_browser = text.trim()
                    console.log("[Kuma Settings] Custom browser command set to:", config.cfg_browser)
                }
            }
        }
    }

    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 400
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            Repeater {
                model: config.entries
                delegate: Controls.GroupBox {
                    id: account
                    required property int index
                    required property var modelData
                    property bool saving: false
                    Layout.fillWidth: true
                    title: "Dashboard " + (index + 1)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Controls.TextField {
                            Layout.fillWidth: true
                            placeholderText: "Display name"
                            text: account.modelData.name || ""
                            onTextEdited: config.update(account.index, "name", text)
                        }

                        Controls.ComboBox {
                            id: sourceTypeSelector
                            Layout.fillWidth: true
                            model: [
                                "Public status page",
                                "Dashboard — API key",
                                "Dashboard — username/password"
                            ]
                            currentIndex: Math.max(0, config.sourceTypes.indexOf(account.modelData.type))
                            onActivated: config.update(account.index, "type", config.sourceTypes[currentIndex])
                        }

                        Controls.TextField {
                            Layout.fillWidth: true
                            placeholderText: sourceTypeSelector.currentIndex === 0
                                ? "https://status.example.com/status/services"
                                : "https://kuma.example.com/dashboard"
                            text: account.modelData.url || ""
                            onTextEdited: config.update(account.index, "url", text)
                        }

                        Controls.TextField {
                            Layout.fillWidth: true
                            placeholderText: sourceTypeSelector.currentIndex === 0
                                ? "Status-page slug (required for custom-domain URLs)"
                                : "Status-page slug for grouping (optional, e.g. internal)"
                            text: account.modelData.slug || ""
                            onTextEdited: config.update(account.index, "slug", text)
                        }

                        Controls.Label {
                            visible: sourceTypeSelector.currentIndex > 0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "To match a status page, enter its slug: /status/internal → internal. "
                                + "Only that page’s monitors will be shown. Leave blank for all monitors. "
                                + "The page’s group information must be accessible on this instance without a web login."
                        }

                        Controls.TextField {
                            visible: sourceTypeSelector.currentIndex === 2
                            Layout.fillWidth: true
                            placeholderText: "Uptime Kuma username"
                            text: account.modelData.username || ""
                            onTextEdited: config.update(account.index, "username", text)
                        }

                        Controls.TextField {
                            id: credentialInput
                            visible: sourceTypeSelector.currentIndex > 0
                            Layout.fillWidth: true
                            placeholderText: sourceTypeSelector.currentIndex === 1
                                ? "API key (save to KWallet below)"
                                : "Password (save to KWallet below)"
                            echoMode: TextInput.Password
                        }

                        Controls.Label {
                            visible: sourceTypeSelector.currentIndex > 0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: sourceTypeSelector.currentIndex === 1
                                ? "Enable API keys in Uptime Kuma Settings → API Keys and paste a key above."
                                : "Username/password metrics access requires API-key authentication to be disabled in Uptime Kuma."
                        }

                        RowLayout {
                            Controls.Button {
                                visible: sourceTypeSelector.currentIndex > 0
                                text: account.saving ? "Saving…" : "Save credential to KWallet"
                                enabled: !account.saving && credentialInput.text.length > 0
                                onClicked: {
                                    let credentialKey
                                    try {
                                        credentialKey = Kuma.walletKey(config.entries[account.index])
                                    } catch (error) {
                                        config.message = error.message
                                        return
                                    }
                                    account.saving = true
                                    wallet.access(credentialKey, credentialInput.text, true, function(errorMessage) {
                                        account.saving = false
                                        config.message = errorMessage
                                            || "Credential saved to KWallet. Apply settings, then refresh the widget."
                                        if (!errorMessage) {
                                            credentialInput.clear()
                                        }
                                    })
                                }
                            }

                            Controls.Button {
                                text: "Remove"
                                enabled: !account.saving
                                onClicked: {
                                    const updatedEntries = config.entries.slice()
                                    updatedEntries.splice(account.index, 1)
                                    config.cfg_dashboards = JSON.stringify(updatedEntries)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Controls.Button {
        text: "Add dashboard"
        icon.name: "list-add"
        onClicked: {
            const updatedEntries = config.entries.slice()
            updatedEntries.push({
                name: "",
                type: "public",
                url: "",
                slug: "",
                username: ""
            })
            config.cfg_dashboards = JSON.stringify(updatedEntries)
        }
    }

    Controls.Label {
        Layout.fillWidth: true
        text: config.message
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
    }
}
}
