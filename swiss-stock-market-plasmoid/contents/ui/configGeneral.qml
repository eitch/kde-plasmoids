import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../code/Market.js" as Market

KCM.SimpleKCM {
    id: configRoot

    property string cfg_brokerProvider: "yahoo"
    property alias cfg_brokerEndpoint: endpointField.text
    property string cfg_authType: "none"
    property alias cfg_token: tokenField.text
    property alias cfg_pollInterval: intervalSpinBox.value
    property string cfg_displaySymbol: "SMI"
    property string cfg_watchlist: "[]"
    property bool cfg_settingsSaved: false

    property string cfg_brokerProviderDefault
    property string cfg_brokerEndpointDefault
    property string cfg_authTypeDefault
    property string cfg_tokenDefault
    property int cfg_pollIntervalDefault
    property string cfg_displaySymbolDefault
    property string cfg_watchlistDefault
    property bool cfg_settingsSavedDefault

    property var items: []
    property string presetSearchText: ""
    property string presetCategoryFilter: "all"
    property string connectionMessage: ""
    property bool connectionSucceeded: false
    property var connectionRequest: null
    property string walletStatus: ""

    readonly property var providerList: Market.BROKER_PROVIDERS

    readonly property var authList: [
        { id: "none", name: "None (Public / Open)" },
        { id: "apikey", name: "API Key (Bearer / Token)" },
        { id: "basic", name: "Basic Auth (Username / Password)" }
    ]

    function loadWatchlist() {
        try {
            const parsed = JSON.parse(cfg_watchlist)
            if (Array.isArray(parsed) && parsed.length > 0) {
                items = parsed
            } else {
                items = Market.defaultWatchlist()
                cfg_watchlist = JSON.stringify(items)
            }
        } catch (e) {
            items = Market.defaultWatchlist()
            cfg_watchlist = JSON.stringify(items)
        }
    }

    function saveWatchlist(newItems) {
        items = newItems
        cfg_watchlist = JSON.stringify(newItems)
    }

    function filteredPresetList() {
        const rawResults = Market.searchSwissMarkets(presetSearchText, items)
        let filtered = rawResults
        if (presetCategoryFilter !== "all") {
            filtered = rawResults.filter(function(item) {
                if (presetCategoryFilter === "indices") return item.category === "indices"
                if (presetCategoryFilter === "equities") return item.category === "equities"
                if (presetCategoryFilter === "forex") return item.category === "forex"
                if (presetCategoryFilter === "crypto") return item.category === "crypto"
                return true
            })
        }
        if (presetSearchText || presetCategoryFilter !== "all") {
            try {
                console.log("[SwissStockMarket Settings] Preset search filter | query: '" + presetSearchText + "', category: '" + presetCategoryFilter + "' -> " + filtered.length + " matching presets" + (filtered.length > 0 ? ": " + filtered.map(function(p) { return p.symbol + (p.alreadyAdded ? " [added]" : ""); }).join(", ") : ""))
            } catch (e) {}
        }
        return filtered
    }

    function addPreset(preset) {
        const symbolUpper = preset.symbol.toUpperCase()
        const exists = items.some(function(it) { return it.symbol.toUpperCase() === symbolUpper })
        if (exists) return

        const updated = items.slice()
        updated.push({
            symbol: preset.symbol,
            name: preset.name,
            market: preset.market || "SIX",
            currency: preset.currency || "CHF",
            category: preset.category || "equities",
            isin: preset.isin || "",
            enabled: true
        })
        saveWatchlist(updated)
    }

    function removeWatchlistItem(index) {
        if (index < 0 || index >= items.length) return
        const updated = items.slice()
        updated.splice(index, 1)
        saveWatchlist(updated)
    }

    function toggleWatchlistItem(index) {
        if (index < 0 || index >= items.length) return
        const updated = items.slice()
        updated[index].enabled = !updated[index].enabled
        saveWatchlist(updated)
    }

    function moveWatchlistItem(fromIndex, toIndex) {
        if (fromIndex < 0 || fromIndex >= items.length || toIndex < 0 || toIndex >= items.length) return
        const updated = items.slice()
        const element = updated.splice(fromIndex, 1)[0]
        updated.splice(toIndex, 0, element)
        saveWatchlist(updated)
    }

    function addCustomSymbol() {
        const sym = newSymbolField.text.trim().toUpperCase()
        if (!sym) return
        const nm = newNameField.text.trim() || sym
        const mkt = newMarketCombo.currentText || "SIX"
        const ccy = newCurrencyField.text.trim().toUpperCase() || "CHF"

        const exists = items.some(function(it) { return it.symbol.toUpperCase() === sym })
        if (exists) return

        const updated = items.slice()
        updated.push({
            symbol: sym,
            name: nm,
            market: mkt,
            currency: ccy,
            category: mkt === "Forex" ? "forex" : (mkt === "Crypto" ? "crypto" : "equities"),
            isin: "",
            enabled: true
        })
        saveWatchlist(updated)

        newSymbolField.text = ""
        newNameField.text = ""
    }

    function saveCredentialToWallet() {
        if (!tokenField.text) {
            walletStatus = "No credential entered."
            return
        }
        const key = Market.walletKey({
            brokerProvider: cfg_brokerProvider,
            brokerEndpoint: cfg_brokerEndpoint
        })
        wallet.access(key, tokenField.text, true, function(err) {
            if (err) {
                walletStatus = "KWallet error: " + err
            } else {
                walletStatus = "Credential saved securely in KWallet."
            }
        })
    }

    function testConnection() {
        if (connectionRequest) {
            return
        }

        let resolvedUrl = endpointField.text.trim()
        if (!resolvedUrl) {
            connectionSucceeded = false
            connectionMessage = "Please enter a broker endpoint URL."
            return
        }

        if (!resolvedUrl.match(/^https?:\/\//i)) {
            connectionSucceeded = false
            connectionMessage = "Invalid URL protocol. Use http:// or https://."
            return
        }

        const isChart = resolvedUrl.indexOf("/chart") !== -1 || cfg_brokerProvider === "yahoo"
        if (isChart) {
            const testSym = (items && items.length > 0) ? items[0].symbol : "SMI"
            resolvedUrl = Market.buildYahooChartUrl(resolvedUrl, testSym)
        } else {
            const symbols = Market.buildSymbolsQuery(items)
            if (symbols) {
                resolvedUrl += (resolvedUrl.indexOf("?") === -1 ? "?" : "&") + "symbols=" + symbols
            }
        }

        const request = new XMLHttpRequest()
        connectionRequest = request
        connectionMessage = "Testing connection to broker…"
        connectionTimeout.start()

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || connectionRequest !== request) {
                return
            }
            connectionTimeout.stop()
            finishConnectionTest(request.status, request.responseText)
        }

        try {
            request.open("GET", resolvedUrl)
            request.setRequestHeader("Accept", "application/json")
            request.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
            if (tokenField.text) {
                if (cfg_authType === "apikey") {
                    request.setRequestHeader("Authorization", "Bearer " + tokenField.text.trim())
                    request.setRequestHeader("X-API-KEY", tokenField.text.trim())
                } else if (cfg_authType === "basic") {
                    request.setRequestHeader("Authorization", "Basic " + Qt.btoa("user:" + tokenField.text.trim()))
                }
            }
            request.send()
        } catch (e) {
            connectionTimeout.stop()
            connectionRequest = null
            connectionSucceeded = false
            connectionMessage = "Could not send connection test request."
        }
    }

    function finishConnectionTest(status, responseText) {
        connectionRequest = null
        if (status >= 200 && status < 300) {
            try {
                const quotes = Market.parseQuotesResponse(responseText, items)
                connectionSucceeded = true
                connectionMessage = "Connected successfully! Retrieved " + quotes.length + " quote(s)."
            } catch (err) {
                connectionSucceeded = false
                connectionMessage = "Connected (HTTP " + status + "), but response format was invalid: " + err.message
            }
        } else {
            connectionSucceeded = false
            connectionMessage = "Broker returned error status: HTTP " + status
        }
    }

    Timer {
        id: connectionTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            if (connectionRequest) {
                connectionRequest.abort()
                connectionRequest = null
                connectionSucceeded = false
                connectionMessage = "Broker connection test timed out after 15 seconds."
            }
        }
    }

    Wallet {
        id: wallet
    }

    Component.onCompleted: {
        loadWatchlist()
    }

    ColumnLayout {
        spacing: Kirigami.Units.mediumSpacing

        // --- BROKER CONFIGURATION ---
        Controls.GroupBox {
        Layout.fillWidth: true
        title: "Swiss Broker API Connection"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    text: "Broker Provider:"
                    Layout.minimumWidth: 140
                }
                Controls.ComboBox {
                    id: providerCombo
                    Layout.fillWidth: true
                    textRole: "name"
                    valueRole: "id"
                    model: configRoot.providerList
                    currentIndex: {
                        for (let i = 0; i < configRoot.providerList.length; i++) {
                            if (configRoot.providerList[i].id === configRoot.cfg_brokerProvider) return i
                        }
                        return 0
                    }
                    onActivated: {
                        const chosen = configRoot.providerList[currentIndex]
                        configRoot.cfg_brokerProvider = chosen.id
                        if (chosen.defaultUrl) {
                            endpointField.text = chosen.defaultUrl
                        }
                    }
                }
            }

            Controls.Label {
                Layout.fillWidth: true
                text: {
                    const chosen = configRoot.providerList[providerCombo.currentIndex]
                    return chosen ? chosen.description : ""
                }
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    text: "Broker REST URL:"
                    Layout.minimumWidth: 140
                }
                Controls.TextField {
                    id: endpointField
                    Layout.fillWidth: true
                    placeholderText: "https://query1.finance.yahoo.com/v8/finance/chart/"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    text: "Authentication:"
                    Layout.minimumWidth: 140
                }
                Controls.ComboBox {
                    id: authCombo
                    Layout.fillWidth: true
                    textRole: "name"
                    valueRole: "id"
                    model: configRoot.authList
                    currentIndex: {
                        for (let i = 0; i < configRoot.authList.length; i++) {
                            if (configRoot.authList[i].id === configRoot.cfg_authType) return i
                        }
                        return 0
                    }
                    onActivated: {
                        configRoot.cfg_authType = configRoot.authList[currentIndex].id
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: configRoot.cfg_authType !== "none"
                Controls.Label {
                    text: "API Token / Password:"
                    Layout.minimumWidth: 140
                }
                Controls.TextField {
                    id: tokenField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "Enter broker API token or password"
                }
                Controls.Button {
                    text: "Store in KWallet"
                    icon.name: "security-high"
                    onClicked: configRoot.saveCredentialToWallet()
                }
            }

            Controls.Label {
                Layout.fillWidth: true
                visible: Boolean(configRoot.walletStatus)
                text: configRoot.walletStatus
                color: Kirigami.Theme.positiveTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Controls.Button {
                    text: "Test Broker Connection"
                    icon.name: "network-connect"
                    enabled: configRoot.connectionRequest === null
                    onClicked: configRoot.testConnection()
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: configRoot.connectionMessage
                    color: configRoot.connectionSucceeded ? "#27ae60" : "#da4453"
                    wrapMode: Text.WordWrap
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
    }

    // --- DISPLAY & REFRESH SETTINGS ---
    Controls.GroupBox {
        Layout.fillWidth: true
        title: "Display & Refresh"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    text: "Primary Panel Symbol:"
                    Layout.minimumWidth: 140
                }
                Controls.ComboBox {
                    id: displaySymbolCombo
                    Layout.fillWidth: true
                    model: {
                        const syms = configRoot.items.map(function(it) { return it.symbol })
                        return syms.length > 0 ? syms : ["SMI"]
                    }
                    currentIndex: {
                        const idx = model.indexOf(configRoot.cfg_displaySymbol)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: {
                        configRoot.cfg_displaySymbol = currentText
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    text: "Refresh Interval (sec):"
                    Layout.minimumWidth: 140
                }
                Controls.SpinBox {
                    id: intervalSpinBox
                    from: 10
                    to: 3600
                    value: 60
                    editable: true
                }
            }
        }
    }

    // --- WATCHLIST MANAGER & SWISS SEARCH ---
    Controls.GroupBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        title: "Swiss Stock Search & Watchlist Manager"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Controls.Label {
                text: "Search Swiss Stocks, SMI, Forex & Cryptos to Add:"
                font.bold: true
            }

            // Search Bar for Presets
            Kirigami.SearchField {
                id: presetSearchField
                Layout.fillWidth: true
                placeholderText: "Search Swiss stocks, SMI, ISIN, or Forex (e.g. Logitech, UBS, Gold, CHF)…"
                onTextChanged: {
                    configRoot.presetSearchText = text
                    try {
                        console.log("[SwissStockMarket Settings] Preset search query input: '" + text + "'")
                    } catch (e) {}
                }
            }

            // Category Filter Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: [
                        { id: "all", name: "All Swiss Markets" },
                        { id: "equities", name: "SMI & Equities" },
                        { id: "indices", name: "Indices" },
                        { id: "forex", name: "Forex / CHF" },
                        { id: "crypto", name: "Crypto & Metals" }
                    ]

                    delegate: Controls.Button {
                        required property var modelData
                        text: modelData.name
                        checkable: true
                        checked: configRoot.presetCategoryFilter === modelData.id
                        onClicked: {
                            configRoot.presetCategoryFilter = modelData.id
                            try {
                                console.log("[SwissStockMarket Settings] Preset category filter switched to: '" + modelData.id + "'")
                            } catch (e) {}
                        }
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            // Search Results List
            Controls.ScrollView {
                Layout.fillWidth: true
                implicitHeight: 160
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: configRoot.filteredPresetList()

                        delegate: Rectangle {
                            id: presetRow
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: presetRowLayout.implicitHeight + 6
                            color: presetRow.modelData.alreadyAdded ? Qt.rgba(0.15, 0.68, 0.38, 0.1) : (presetRow.index % 2 === 0 ? Kirigami.Theme.backgroundColor : Kirigami.Theme.alternateBackgroundColor)
                            radius: 3

                            RowLayout {
                                id: presetRowLayout
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: Kirigami.Units.smallSpacing

                                Controls.Label {
                                    text: presetRow.modelData.symbol
                                    font.bold: true
                                    Layout.minimumWidth: 65
                                }

                                Controls.Label {
                                    text: presetRow.modelData.name
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                }

                                Rectangle {
                                    color: Kirigami.Theme.alternateBackgroundColor
                                    radius: 3
                                    implicitWidth: pMarketLabel.implicitWidth + 8
                                    implicitHeight: pMarketLabel.implicitHeight + 4
                                    Controls.Label {
                                        id: pMarketLabel
                                        anchors.centerIn: parent
                                        text: presetRow.modelData.market || "SIX"
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                                        color: Kirigami.Theme.disabledTextColor
                                    }
                                }

                                Controls.Label {
                                    text: presetRow.modelData.isin || ""
                                    color: Kirigami.Theme.disabledTextColor
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                                    Layout.minimumWidth: 100
                                    elide: Text.ElideRight
                                    visible: Boolean(presetRow.modelData.isin)
                                }

                                Controls.Button {
                                    text: presetRow.modelData.alreadyAdded ? "✓ In Watchlist" : "+ Add"
                                    enabled: !presetRow.modelData.alreadyAdded
                                    icon.name: presetRow.modelData.alreadyAdded ? "dialog-ok-apply" : "list-add"
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    onClicked: configRoot.addPreset(presetRow.modelData)
                                }
                            }
                        }
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        visible: configRoot.filteredPresetList().length === 0
                        text: "No matching Swiss stocks or markets found."
                        horizontalAlignment: Text.AlignHCenter
                        color: Kirigami.Theme.disabledTextColor
                        font.italic: true
                        padding: Kirigami.Units.smallSpacing
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.alternateBackgroundColor
            }

            Controls.Label {
                text: "Add Custom Stock / Symbol:"
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Controls.TextField {
                    id: newSymbolField
                    placeholderText: "Symbol (e.g. SQN)"
                    Layout.preferredWidth: 120
                }

                Controls.TextField {
                    id: newNameField
                    placeholderText: "Company / Market Name"
                    Layout.fillWidth: true
                }

                Controls.ComboBox {
                    id: newMarketCombo
                    model: ["SIX", "Swissquote", "Forex", "Crypto", "Other"]
                    Layout.preferredWidth: 110
                }

                Controls.TextField {
                    id: newCurrencyField
                    text: "CHF"
                    placeholderText: "CCY"
                    Layout.preferredWidth: 70
                }

                Controls.Button {
                    text: "Add"
                    icon.name: "list-add"
                    onClicked: configRoot.addCustomSymbol()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.alternateBackgroundColor
            }

            Controls.Label {
                text: "Configured Watchlist (" + configRoot.items.length + " items):"
                font.bold: true
            }

            // List of watchlist items
            Controls.ScrollView {
                Layout.fillWidth: true
                implicitHeight: 180
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: configRoot.items

                        delegate: Rectangle {
                            id: itemRow
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: rowLayout.implicitHeight + 8
                            color: itemRow.index % 2 === 0 ? Kirigami.Theme.backgroundColor : Kirigami.Theme.alternateBackgroundColor
                            radius: 3

                            RowLayout {
                                id: rowLayout
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: Kirigami.Units.smallSpacing

                                Controls.CheckBox {
                                    checked: itemRow.modelData.enabled !== false
                                    onToggled: configRoot.toggleWatchlistItem(itemRow.index)
                                }

                                Controls.Label {
                                    text: itemRow.modelData.symbol
                                    font.bold: true
                                    Layout.minimumWidth: 60
                                }

                                Controls.Label {
                                    text: itemRow.modelData.name
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    color: Kirigami.Theme.alternateBackgroundColor
                                    radius: 3
                                    implicitWidth: rowMarketLabel.implicitWidth + 8
                                    implicitHeight: rowMarketLabel.implicitHeight + 4
                                    Controls.Label {
                                        id: rowMarketLabel
                                        anchors.centerIn: parent
                                        text: itemRow.modelData.market || "SIX"
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                                        color: Kirigami.Theme.disabledTextColor
                                    }
                                }

                                Controls.Label {
                                    text: itemRow.modelData.currency || "CHF"
                                    color: Kirigami.Theme.disabledTextColor
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    Layout.minimumWidth: 40
                                }

                                Controls.ToolButton {
                                    icon.name: "arrow-up"
                                    enabled: itemRow.index > 0
                                    onClicked: configRoot.moveWatchlistItem(itemRow.index, itemRow.index - 1)
                                }

                                Controls.ToolButton {
                                    icon.name: "arrow-down"
                                    enabled: itemRow.index < configRoot.items.length - 1
                                    onClicked: configRoot.moveWatchlistItem(itemRow.index, itemRow.index + 1)
                                }

                                Controls.ToolButton {
                                    icon.name: "edit-delete"
                                    onClicked: configRoot.removeWatchlistItem(itemRow.index)
                                }
                            }
                        }
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        visible: configRoot.items.length === 0
                        text: "Watchlist is empty. Search above or click presets to add Swiss stocks."
                        horizontalAlignment: Text.AlignHCenter
                        color: Kirigami.Theme.disabledTextColor
                        font.italic: true
                        padding: Kirigami.Units.largeSpacing
                    }
                }
            }
        }
    }
}
}
