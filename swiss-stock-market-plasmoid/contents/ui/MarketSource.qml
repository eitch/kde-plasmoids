import QtQuick
import "../code/Market.js" as Market

Item {
    id: source

    property var brokerConfig: ({
        brokerProvider: "yahoo",
        brokerEndpoint: "https://query1.finance.yahoo.com/v8/finance/chart/",
        authType: "none",
        token: ""
    })
    property var watchlist: []
    property int pollInterval: 60

    property var quotes: []
    property var summary: ({
        overall: "unknown",
        total: 0,
        gainers: 0,
        losers: 0,
        unchanged: 0
    })
    property string error: ""
    property string status: "unknown"
    property string updated: ""
    property var requests: []
    property int generation: 0
    property bool busy: false
    property double deadline: 0

    signal changed()

    Wallet {
        id: wallet
    }

    onWatchlistChanged: {
        initFallbackQuotes()
        changed()
    }

    function initFallbackQuotes() {
        if (!quotes || quotes.length === 0 || (watchlist && quotes.length !== watchlist.length)) {
            quotes = Market.getInitialQuotes(watchlist)
            summary = Market.aggregateMarket(quotes)
            status = summary.overall
            changed()
        }
    }

    function publish(quoteList) {
        quotes = quoteList
        summary = Market.aggregateMarket(quoteList)
        status = summary.overall
        error = ""
        updated = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm:ss")
        busy = false
        changed()
    }

    function fail(errorMessage) {
        ++generation
        busy = false
        error = errorMessage
        if (!quotes || quotes.length === 0) {
            quotes = Market.getInitialQuotes(watchlist)
        }
        summary = Market.aggregateMarket(quotes)
        status = "unknown"

        const pendingRequests = requests
        requests = []
        pendingRequests.forEach(function(request) {
            request.abort()
        })
        changed()
    }

    function executeSingleRequest(requestUrl, requestGeneration, onSuccess, onError, credential, fallbackItem) {
        const request = new XMLHttpRequest()
        requests.push(request)

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || requestGeneration !== generation) {
                return
            }

            if (request.status < 200 || request.status >= 300) {
                if (typeof onError === "function") {
                    onError("HTTP " + request.status)
                } else {
                    fail("Yahoo Finance request failed (HTTP " + request.status + ").")
                }
                return
            }

            try {
                const quote = Market.parseYahooChartResponse(request.responseText, fallbackItem)
                onSuccess(quote)
            } catch (err) {
                if (typeof onError === "function") {
                    onError(err.message || "Invalid response")
                } else {
                    fail(err.message || "Invalid response from Yahoo Finance.")
                }
            }
        }

        try {
            request.open("GET", requestUrl)
            request.setRequestHeader("Accept", "application/json")
            request.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
            if (credential) {
                if (brokerConfig.authType === "apikey") {
                    request.setRequestHeader("Authorization", "Bearer " + credential)
                    request.setRequestHeader("X-API-KEY", credential)
                } else if (brokerConfig.authType === "basic") {
                    const username = brokerConfig.username || "user"
                    request.setRequestHeader("Authorization", "Basic " + Market.base64Encode(username + ":" + credential))
                }
            } else if (brokerConfig.token) {
                request.setRequestHeader("Authorization", "Bearer " + brokerConfig.token)
            }
            request.send()
        } catch (err) {
            if (typeof onError === "function") {
                onError("Could not send request")
            } else {
                fail("Could not send request to Yahoo Finance.")
            }
        }
    }

    function executeRequest(requestUrl, requestGeneration, onSuccess, credential) {
        const request = new XMLHttpRequest()
        requests.push(request)

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || requestGeneration !== generation) {
                return
            }

            if (request.status < 200 || request.status >= 300) {
                fail("Broker request failed (HTTP " + request.status + ").")
                return
            }

            try {
                const quoteList = Market.parseQuotesResponse(request.responseText, watchlist)
                onSuccess(quoteList)
            } catch (err) {
                fail(err.message || "Invalid response from Swiss broker.")
            }
        }

        try {
            request.open("GET", requestUrl)
            request.setRequestHeader("Accept", "application/json")
            request.setRequestHeader("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36")
            if (credential) {
                if (brokerConfig.authType === "apikey") {
                    request.setRequestHeader("Authorization", "Bearer " + credential)
                    request.setRequestHeader("X-API-KEY", credential)
                } else if (brokerConfig.authType === "basic") {
                    const username = brokerConfig.username || "user"
                    request.setRequestHeader("Authorization", "Basic " + Market.base64Encode(username + ":" + credential))
                }
            } else if (brokerConfig.token) {
                request.setRequestHeader("Authorization", "Bearer " + brokerConfig.token)
            }
            request.send()
        } catch (err) {
            fail("Could not send request to Swiss broker.")
        }
    }

    function refreshWithCredential(resolvedEndpoint, requestGeneration, credential) {
        const activeItems = (watchlist || []).filter(function(it) { return it && it.enabled !== false })
        if (activeItems.length === 0) {
            publish([])
            requests = []
            return
        }

        const isChartEndpoint = (resolvedEndpoint.url && resolvedEndpoint.url.indexOf("/chart") !== -1) || resolvedEndpoint.provider === "yahoo"
        if (isChartEndpoint) {
            let collectedQuotes = []
            let pendingCount = activeItems.length

            activeItems.forEach(function(item) {
                const itemUrl = Market.buildYahooChartUrl(resolvedEndpoint.url, item.symbol)
                executeSingleRequest(itemUrl, requestGeneration, function(quote) {
                    if (requestGeneration !== generation) return
                    collectedQuotes.push(quote)
                    pendingCount--
                    if (pendingCount <= 0) {
                        const sortedQuotes = activeItems.map(function(act) {
                            const found = collectedQuotes.find(function(q) { return q.symbol.toUpperCase() === act.symbol.toUpperCase() })
                            return found || Market.normalizeQuote(null, act)
                        })
                        publish(sortedQuotes)
                        requests = []
                    }
                }, function(errMsg) {
                    if (requestGeneration !== generation) return
                    collectedQuotes.push(Market.normalizeQuote(null, item))
                    pendingCount--
                    if (pendingCount <= 0) {
                        const sortedQuotes = activeItems.map(function(act) {
                            const found = collectedQuotes.find(function(q) { return q.symbol.toUpperCase() === act.symbol.toUpperCase() })
                            return found || Market.normalizeQuote(null, act)
                        })
                        publish(sortedQuotes)
                        requests = []
                    }
                }, credential, item)
            })
        } else {
            const symbolsParam = Market.buildSymbolsQuery(watchlist)
            let requestUrl = resolvedEndpoint.url
            if (symbolsParam) {
                requestUrl += (requestUrl.indexOf("?") === -1 ? "?" : "&") + "symbols=" + symbolsParam
            }

            executeRequest(requestUrl, requestGeneration, function(quoteList) {
                publish(quoteList)
                requests = []
            }, credential)
        }
    }

    function refresh() {
        if (busy) {
            return
        }

        let resolvedEndpoint
        try {
            resolvedEndpoint = Market.endpoint(brokerConfig)
        } catch (err) {
            fail(err.message)
            return
        }

        const requestGeneration = ++generation
        busy = true
        deadline = Date.now() + 30000

        if (brokerConfig.authType && brokerConfig.authType !== "none") {
            wallet.access(Market.walletKey(brokerConfig), "", false, function(walletErr, credential) {
                if (requestGeneration !== generation) {
                    return
                }
                const effectiveToken = credential || brokerConfig.token || ""
                if (walletErr && !effectiveToken) {
                    fail(walletErr)
                    return
                }
                requests = []
                refreshWithCredential(resolvedEndpoint, requestGeneration, effectiveToken)
            })
        } else {
            requests = []
            refreshWithCredential(resolvedEndpoint, requestGeneration, brokerConfig.token || "")
        }
    }

    Timer {
        interval: Math.max(10, source.pollInterval) * 1000
        running: true
        repeat: true
        onTriggered: source.refresh()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (source.busy && Date.now() > source.deadline) {
                source.fail("Swiss broker connection timed out.")
            }
        }
    }

    Component.onCompleted: {
        initFallbackQuotes()
        refresh()
    }

    Component.onDestruction: {
        ++generation
        requests.forEach(function(request) {
            request.abort()
        })
    }
}
