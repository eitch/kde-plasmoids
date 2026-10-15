import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "../code/Market.js" as Market

PlasmoidItem {
    id: root

    readonly property bool isVertical: plasmoid && typeof PlasmaCore !== "undefined" && plasmoid.formFactor === PlasmaCore.Types.Vertical
    property string configError: ""
    property bool settingsReady: false
    property var quotes: (marketSource && marketSource.quotes && marketSource.quotes.length > 0)
        ? marketSource.quotes
        : ((marketSource && marketSource.watchlist && marketSource.watchlist.length > 0)
            ? Market.getInitialQuotes(marketSource.watchlist)
            : [])

    SettingsBackup {
        id: backup
        instanceId: String(Plasmoid.id)
    }

    readonly property var linkOpener: opener

    LinkOpener {
        id: opener
        customBrowser: plasmoid.configuration.browser || ""
    }

    MarketSource {
        id: marketSource
        onChanged: {
            root.quotes = marketSource.quotes
        }
    }

    function primaryQuote() {
        const qList = (marketSource && marketSource.quotes && marketSource.quotes.length > 0)
            ? marketSource.quotes
            : root.quotes
        if (!qList || qList.length === 0) {
            return null
        }
        const targetSym = (plasmoid.configuration.displaySymbol || "SMI").toUpperCase()
        for (let i = 0; i < qList.length; i++) {
            if (qList[i].symbol === targetSym) {
                return qList[i]
            }
        }
        return qList[0]
    }

    function persistSettings() {
        if (!settingsReady) {
            return
        }

        try {
            backup.save(
                plasmoid.configuration.watchlist,
                plasmoid.configuration.pollInterval,
                plasmoid.configuration.brokerProvider,
                plasmoid.configuration.brokerEndpoint,
                plasmoid.configuration.authType,
                plasmoid.configuration.displaySymbol,
                plasmoid.configuration.browser
            )
            plasmoid.configuration.settingsSaved = true
            plasmoid.configuration.writeConfig()
        } catch (error) {
            configError = "Could not back up the widget settings."
        }
    }

    function initializeSettings() {
        // Only restore a missing configuration, never an intentionally empty list.
        if (!plasmoid.configuration.settingsSaved && (plasmoid.configuration.watchlist === "[]" || !plasmoid.configuration.watchlist)) {
            const savedSettings = backup.read()
            if (savedSettings) {
                plasmoid.configuration.watchlist = savedSettings.watchlist
                plasmoid.configuration.pollInterval = savedSettings.pollInterval
                plasmoid.configuration.brokerProvider = savedSettings.brokerProvider
                plasmoid.configuration.brokerEndpoint = savedSettings.brokerEndpoint
                plasmoid.configuration.authType = savedSettings.authType
                plasmoid.configuration.displaySymbol = savedSettings.displaySymbol
                if (savedSettings.browser !== undefined) {
                    plasmoid.configuration.browser = savedSettings.browser
                }
            }
        }

        settingsReady = true
        reload()
        persistSettings()
    }

    function reload() {
        try {
            const configuredWatchlist = JSON.parse(plasmoid.configuration.watchlist)
            marketSource.watchlist = configuredWatchlist
        } catch (e) {
            marketSource.watchlist = Market.defaultWatchlist()
        }

        marketSource.brokerConfig = {
            brokerProvider: plasmoid.configuration.brokerProvider || "yahoo",
            brokerEndpoint: plasmoid.configuration.brokerEndpoint || "",
            authType: plasmoid.configuration.authType || "none",
            token: plasmoid.configuration.token || ""
        }
        marketSource.pollInterval = plasmoid.configuration.pollInterval || 60
        marketSource.refresh()
    }

    function configure() {
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

    function addPresetToWatchlist(preset) {
        if (!preset || !preset.symbol) return
        let currentWatchlist = []
        try {
            currentWatchlist = JSON.parse(plasmoid.configuration.watchlist)
        } catch (e) {
            currentWatchlist = Market.defaultWatchlist()
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
            plasmoid.configuration.watchlist = JSON.stringify(currentWatchlist)
            persistSettings()
            if (marketSource) {
                marketSource.watchlist = currentWatchlist
                marketSource.refresh()
            }
        }
    }

    preferredRepresentation: compactRepresentation

    toolTipMainText: "Swiss Stock Market"
    toolTipSubText: {
        const quote = primaryQuote()
        let text = ""
        if (quote) {
            text = quote.symbol + ": " + quote.formattedPrice + " (" + quote.formattedPercent + ")"
        } else if (marketSource.error) {
            text = marketSource.error
        } else {
            text = "Connecting to Swiss broker…"
        }
        if (marketSource && marketSource.updated) {
            text += " · Last update: " + marketSource.updated
        }
        return text
    }

    compactRepresentation: MouseArea {
        id: compactArea
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        implicitWidth: root.isVertical
            ? Math.max(compactLayout.implicitWidth, Kirigami.Units.iconSizes.smallMedium)
            : (compactLayout.implicitWidth + Kirigami.Units.smallSpacing * 2)
        implicitHeight: root.isVertical
            ? (compactLayout.implicitHeight + Kirigami.Units.smallSpacing * 2)
            : Math.max(compactLayout.implicitHeight, Kirigami.Units.iconSizes.smallMedium)

        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight

        onClicked: {
            root.expanded = !root.expanded
        }

        GridLayout {
            id: compactLayout
            anchors.centerIn: parent
            columns: root.isVertical ? 1 : 4
            rowSpacing: Kirigami.Units.smallSpacing / 2
            columnSpacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "view-financial-category"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignCenter
            }

            Controls.Label {
                id: symbolLabel
                text: {
                    const quote = root.primaryQuote()
                    return quote ? quote.symbol : (plasmoid.configuration.displaySymbol || "SMI")
                }
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                Layout.alignment: Qt.AlignCenter
            }

            Controls.Label {
                id: priceLabel
                text: {
                    const quote = root.primaryQuote()
                    return quote ? quote.formattedPrice : "—"
                }
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                Layout.alignment: Qt.AlignCenter
            }

            Rectangle {
                id: compactChangeBadge
                radius: 3
                color: {
                    const quote = root.primaryQuote()
                    const st = quote ? quote.state : "unknown"
                    if (st === "up") return Qt.rgba(0.15, 0.68, 0.38, 0.25)
                    if (st === "down") return Qt.rgba(0.85, 0.27, 0.33, 0.25)
                    return Qt.rgba(0.5, 0.5, 0.5, 0.15)
                }
                implicitWidth: compactChangeText.implicitWidth + Kirigami.Units.smallSpacing * 2
                implicitHeight: compactChangeText.implicitHeight + 2
                Layout.alignment: Qt.AlignCenter

                Controls.Label {
                    id: compactChangeText
                    anchors.centerIn: parent
                    text: {
                        const quote = root.primaryQuote()
                        if (!quote) return "—"
                        const arrow = quote.state === "up" ? "▲" : (quote.state === "down" ? "▼" : "")
                        return (arrow ? arrow + " " : "") + (quote.formattedPercent !== "—" ? quote.formattedPercent : quote.formattedChange)
                    }
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    color: {
                        const quote = root.primaryQuote()
                        const st = quote ? quote.state : "unknown"
                        if (st === "up") return "#27ae60"
                        if (st === "down") return "#da4453"
                        return Kirigami.Theme.textColor
                    }
                }
            }
        }
    }

    fullRepresentation: Dashboard {
        id: dashboardView
        marketSource: marketSource
        quotes: root.quotes
        linkOpener: root.linkOpener
        onRequestConfigure: root.configure()
        onAddStockRequested: function(preset) {
            root.addPresetToWatchlist(preset)
        }
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 28
    }

    Connections {
        target: plasmoid.configuration
        function onWatchlistChanged() {
            persistSettings()
            reload()
        }
        function onPollIntervalChanged() {
            persistSettings()
            reload()
        }
        function onBrokerProviderChanged() {
            persistSettings()
            reload()
        }
        function onBrokerEndpointChanged() {
            persistSettings()
            reload()
        }
        function onAuthTypeChanged() {
            persistSettings()
            reload()
        }
        function onDisplaySymbolChanged() {
            persistSettings()
        }
        function onBrowserChanged() {
            console.log("[SwissStockMarket] plasmoid.configuration.browser changed to:", plasmoid.configuration.browser)
            persistSettings()
        }
    }

    Component.onCompleted: initializeSettings()
}
