import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "../code/Market.js" as Market

ColumnLayout {
    id: dashboard

    property var marketSource: null
    property var linkOpener: null
    property var quotes: (marketSource && marketSource.quotes && marketSource.quotes.length > 0)
        ? marketSource.quotes
        : ((marketSource && marketSource.watchlist && marketSource.watchlist.length > 0)
            ? Market.getInitialQuotes(marketSource.watchlist)
            : [])
    property string filterText: ""
    property string selectedCategory: "all"

    readonly property var displayedQuotes: {
        const sourceQuotes = (quotes && quotes.length > 0)
            ? quotes
            : ((marketSource && marketSource.quotes && marketSource.quotes.length > 0)
                ? marketSource.quotes
                : ((marketSource && marketSource.watchlist && marketSource.watchlist.length > 0)
                    ? Market.getInitialQuotes(marketSource.watchlist)
                    : []))

        if (!sourceQuotes || sourceQuotes.length === 0) return []
        const text = (filterText || "").trim().toLowerCase()
        const cat = selectedCategory || "all"

        const res = sourceQuotes.filter(function(q) {
            if (!q) return false
            if (cat !== "all") {
                const qCat = (q.category || "").toLowerCase()
                const mkt = (q.market || "").toLowerCase()
                if (cat === "forex" && mkt !== "forex" && qCat !== "forex") return false
                if (cat === "crypto" && mkt !== "crypto" && qCat !== "crypto" && mkt !== "precious metals") return false
                if (cat === "indices" && qCat !== "indices" && q.symbol !== "SMI" && q.symbol !== "SPI" && q.symbol !== "SLI" && q.symbol !== "SMIM") return false
                if (cat === "equities" && (mkt === "forex" || mkt === "crypto" || mkt === "precious metals" || qCat === "indices" || q.symbol === "SMI" || q.symbol === "SPI" || q.symbol === "SLI" || q.symbol === "SMIM")) return false
            }
            if (!text) return true
            const sym = (q.symbol || "").toLowerCase()
            const name = (q.name || "").toLowerCase()
            const isin = (q.isin || "").toLowerCase()
            const mkt = (q.market || "").toLowerCase()
            return sym.indexOf(text) !== -1 ||
                   name.indexOf(text) !== -1 ||
                   isin.indexOf(text) !== -1 ||
                   mkt.indexOf(text) !== -1
        })
        if (text || cat !== "all") {
            try {
                console.log("[SwissStockMarket Dashboard] Filtered watchlist quotes | query: '" + filterText + "', category: '" + cat + "' -> " + res.length + " matching quotes" + (res.length > 0 ? ": " + res.map(function(q) { return q.symbol; }).join(", ") : ""))
            } catch (e) {}
        }
        return res
    }

    signal requestConfigure()
    signal addStockRequested(var preset)

    spacing: Kirigami.Units.smallSpacing

    function brokerTitle() {
        if (!marketSource || !marketSource.brokerConfig) return "Yahoo Finance"
        const prov = marketSource.brokerConfig.brokerProvider
        if (prov === "yahoo" || prov === "yahoofinance") return "Yahoo Finance"
        return "Yahoo Finance"
    }

    function unaddedSearchResults() {
        if (!filterText || !filterText.trim()) return []
        const results = Market.searchSwissMarkets(filterText, marketSource ? marketSource.watchlist : [])
        const unadded = results.filter(function(r) { return !r.alreadyAdded })
        try {
            console.log("[SwissStockMarket Dashboard] Unadded suggestions search | query: '" + filterText + "' -> " + unadded.length + " suggestions available" + (unadded.length > 0 ? ": " + unadded.map(function(r) { return r.symbol + " (" + r.name + ")"; }).join(", ") : ""))
        } catch (e) {}
        return unadded
    }

    function addPresetToWatchlist(preset) {
        if (!preset || !preset.symbol) return
        dashboard.addStockRequested(preset)

        let configObj = null
        if (typeof plasmoid !== "undefined" && plasmoid && plasmoid.configuration) {
            configObj = plasmoid.configuration
        } else if (typeof Plasmoid !== "undefined" && Plasmoid && Plasmoid.configuration) {
            configObj = Plasmoid.configuration
        }

        if (configObj) {
            let currentWatchlist = []
            try {
                currentWatchlist = JSON.parse(configObj.watchlist)
            } catch (e) {
                currentWatchlist = (marketSource && marketSource.watchlist) ? marketSource.watchlist : Market.defaultWatchlist()
            }
            if (!Array.isArray(currentWatchlist)) {
                currentWatchlist = Market.defaultWatchlist()
            }

            const symUpper = preset.symbol.toUpperCase()
            const exists = currentWatchlist.some(function(it) { return it.symbol.toUpperCase() === symUpper })
            if (!exists) {
                currentWatchlist.push({
                    symbol: preset.symbol,
                    name: preset.name,
                    market: preset.market || "SIX",
                    currency: preset.currency || "CHF",
                    category: preset.category || "equities",
                    isin: preset.isin || "",
                    enabled: true
                })
                configObj.watchlist = JSON.stringify(currentWatchlist)
                if (typeof configObj.writeConfig === "function") {
                    configObj.writeConfig()
                }
                if (marketSource) {
                    marketSource.watchlist = currentWatchlist
                    marketSource.refresh()
                }
            }
        } else if (marketSource) {
            let currentWatchlist = marketSource.watchlist ? JSON.parse(JSON.stringify(marketSource.watchlist)) : Market.defaultWatchlist()
            const symUpper = preset.symbol.toUpperCase()
            const exists = currentWatchlist.some(function(it) { return it.symbol.toUpperCase() === symUpper })
            if (!exists) {
                currentWatchlist.push({
                    symbol: preset.symbol,
                    name: preset.name,
                    market: preset.market || "SIX",
                    currency: preset.currency || "CHF",
                    category: preset.category || "equities",
                    isin: preset.isin || "",
                    enabled: true
                })
                marketSource.watchlist = currentWatchlist
                marketSource.refresh()
            }
        }
    }

    // Header section
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Controls.Label {
                text: dashboard.brokerTitle()
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
            }

            Controls.Label {
                text: {
                    if (marketSource && marketSource.updated) {
                        return "Last update: " + marketSource.updated
                    }
                    return "Ready"
                }
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }

        // Market overall badge
        Rectangle {
            radius: 4
            color: {
                const st = marketSource ? marketSource.status : "unknown"
                if (st === "up") return Qt.rgba(0.15, 0.68, 0.38, 0.2)
                if (st === "down") return Qt.rgba(0.85, 0.27, 0.33, 0.2)
                return Qt.rgba(0.5, 0.5, 0.5, 0.15)
            }
            implicitWidth: summaryLabel.implicitWidth + 12
            implicitHeight: summaryLabel.implicitHeight + 6

            Controls.Label {
                id: summaryLabel
                anchors.centerIn: parent
                text: {
                    if (!marketSource || !marketSource.summary) return "Market: —"
                    const sm = marketSource.summary
                    if (sm.overall === "up") return "▲ Swiss Market +"
                    if (sm.overall === "down") return "▼ Swiss Market −"
                    return "Swiss Market"
                }
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: {
                    const st = marketSource ? marketSource.status : "unknown"
                    if (st === "up") return "#27ae60"
                    if (st === "down") return "#da4453"
                    return Kirigami.Theme.textColor
                }
            }
        }

        Controls.ToolButton {
            icon.name: "view-refresh"
            text: "Refresh"
            display: Controls.AbstractButton.IconOnly
            enabled: Boolean(marketSource && !marketSource.busy)
            onClicked: {
                if (marketSource) {
                    marketSource.refresh()
                }
            }
        }

        Controls.ToolButton {
            icon.name: "configure"
            text: "Settings"
            display: Controls.AbstractButton.IconOnly
            onClicked: {
                dashboard.requestConfigure()
                if (typeof Plasmoid !== "undefined" && Plasmoid && typeof Plasmoid.internalAction === "function") {
                    const configureAction = Plasmoid.internalAction("configure")
                    if (configureAction) {
                        configureAction.trigger()
                    }
                } else if (typeof plasmoid !== "undefined" && plasmoid && typeof plasmoid.internalAction === "function") {
                    const configureAction = plasmoid.internalAction("configure")
                    if (configureAction) {
                        configureAction.trigger()
                    }
                }
            }
        }
    }

    // Filter bar
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.SearchField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Search Swiss stocks, SMI, ISIN, or Forex…"
            onTextChanged: {
                dashboard.filterText = text
                try {
                    console.log("[SwissStockMarket Dashboard] Search query input: '" + text + "'")
                } catch (e) {}
            }
        }
    }

    // Category Selector
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: [
                { id: "all", name: "All" },
                { id: "indices", name: "Indices" },
                { id: "equities", name: "Equities" },
                { id: "forex", name: "Forex / CHF" },
                { id: "crypto", name: "Crypto & Metals" }
            ]

            delegate: Controls.Button {
                required property var modelData
                text: modelData.name
                checkable: true
                checked: dashboard.selectedCategory === modelData.id
                onClicked: {
                    dashboard.selectedCategory = modelData.id
                    try {
                        console.log("[SwissStockMarket Dashboard] Category filter switched to: '" + modelData.id + "'")
                    } catch (e) {}
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }

    // Error banner
    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: Boolean(marketSource && marketSource.error)
        type: Kirigami.MessageType.Error
        text: marketSource ? marketSource.error : ""
        actions: [
            Kirigami.Action {
                text: "Retry"
                icon.name: "view-refresh"
                onTriggered: {
                    if (marketSource) {
                        marketSource.refresh()
                    }
                }
            }
        ]
    }

    // Quotes list
    Controls.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 320
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: dashboard.displayedQuotes

                delegate: StockRow {
                    required property var modelData
                    Layout.fillWidth: true
                    quote: modelData
                    linkOpener: dashboard.linkOpener
                }
            }

            // Unadded matching Swiss market stocks suggestions when searching
            ColumnLayout {
                Layout.fillWidth: true
                visible: dashboard.unaddedSearchResults().length > 0
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Kirigami.Theme.alternateBackgroundColor
                }

                Controls.Label {
                    text: "Available Swiss Stocks to Add (" + dashboard.unaddedSearchResults().length + "):"
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.disabledTextColor
                }

                Repeater {
                    model: dashboard.unaddedSearchResults()

                    delegate: Rectangle {
                        id: unaddedRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: unaddedLayout.implicitHeight + 6
                        color: Kirigami.Theme.alternateBackgroundColor
                        radius: 3

                        RowLayout {
                            id: unaddedLayout
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: Kirigami.Units.smallSpacing

                            Controls.Label {
                                text: unaddedRow.modelData.symbol
                                font.bold: true
                                Layout.minimumWidth: 55
                            }

                            Controls.Label {
                                text: unaddedRow.modelData.name
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }

                            Controls.Button {
                                text: "+ Add"
                                icon.name: "list-add"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                onClicked: dashboard.addPresetToWatchlist(unaddedRow.modelData)
                            }
                        }
                    }
                }
            }

            // Empty state
            Controls.Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                visible: Boolean(dashboard.displayedQuotes.length === 0 && dashboard.unaddedSearchResults().length === 0 && (!marketSource || !marketSource.error))
                text: dashboard.filterText ? "No matching stocks found." : "No stocks configured in watchlist."
                horizontalAlignment: Text.AlignHCenter
                color: Kirigami.Theme.disabledTextColor
                font.italic: true
                padding: Kirigami.Units.largeSpacing
            }
        }
    }

    // Footer with last update status
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
            Layout.fillWidth: true
            text: {
                if (marketSource && marketSource.updated) {
                    return "Last updated: " + marketSource.updated
                }
                return "Not updated yet"
            }
            color: Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}
