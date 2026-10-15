// Swiss Stock Market data, formatting, search and broker helpers

var PRESET_MARKETS = [
    // --- Major Swiss Indices ---
    {
        symbol: "SMI",
        name: "Swiss Market Index (SMI)",
        market: "SIX",
        currency: "CHF",
        category: "indices",
        isin: "CH0009980894",
        refPrice: 12245.50,
        refChange: 38.20,
        refChangePct: 0.31
    },
    {
        symbol: "SPI",
        name: "Swiss Performance Index (SPI)",
        market: "SIX",
        currency: "CHF",
        category: "indices",
        isin: "CH0009987501",
        refPrice: 16180.20,
        refChange: 42.10,
        refChangePct: 0.26
    },
    {
        symbol: "SLI",
        name: "Swiss Leader Index (SLI)",
        market: "SIX",
        currency: "CHF",
        category: "indices",
        isin: "CH0030252883",
        refPrice: 1980.75,
        refChange: 5.40,
        refChangePct: 0.27
    },

    // --- Forex Pairs in CHF ---
    {
        symbol: "EURCHF",
        name: "EUR / CHF (Euro / Swiss Franc)",
        market: "Forex",
        currency: "CHF",
        category: "forex",
        isin: "EU0009654078",
        refPrice: 0.9385,
        refChange: 0.0012,
        refChangePct: 0.13
    },
    {
        symbol: "USDCHF",
        name: "USD / CHF (US Dollar / Swiss Franc)",
        market: "Forex",
        currency: "CHF",
        category: "forex",
        isin: "US0000000001",
        refPrice: 0.8640,
        refChange: -0.0018,
        refChangePct: -0.21
    },

    // --- Cryptocurrencies in CHF ---
    {
        symbol: "BTCCHF",
        name: "Bitcoin / CHF",
        market: "Crypto",
        currency: "CHF",
        category: "crypto",
        isin: "CRYPTO-BTC-CHF",
        refPrice: 54200.00,
        refChange: 850.00,
        refChangePct: 1.59
    },
    {
        symbol: "ETHCHF",
        name: "Ethereum / CHF",
        market: "Crypto",
        currency: "CHF",
        category: "crypto",
        isin: "CRYPTO-ETH-CHF",
        refPrice: 2240.00,
        refChange: 35.00,
        refChangePct: 1.59
    }
];

var BROKER_PROVIDERS = [
    {
        id: "yahoo",
        name: "Yahoo Finance",
        defaultUrl: "https://query1.finance.yahoo.com/v8/finance/chart/",
        description: "Real-time market quotes from Yahoo Finance (Indices, Stocks, Forex, Crypto)"
    }
];

function defaultWatchlist() {
    return [
        {
            symbol: "SMI",
            name: "Swiss Market Index",
            market: "SIX",
            currency: "CHF",
            enabled: true
        },
        {
            symbol: "EURCHF",
            name: "EUR / CHF",
            market: "Forex",
            currency: "CHF",
            enabled: true
        }
    ];
}

function findPresetBySymbol(symbol) {
    if (!symbol) return null;
    var symUpper = String(symbol).trim().toUpperCase();
    for (var i = 0; i < PRESET_MARKETS.length; i++) {
        if (PRESET_MARKETS[i].symbol.toUpperCase() === symUpper) {
            return PRESET_MARKETS[i];
        }
    }
    return null;
}

function stripAccents(str) {
    if (!str || typeof str !== "string") return "";
    try {
        return str.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    } catch (e) {
        return str.toLowerCase()
            .replace(/[éèêë]/g, "e")
            .replace(/[âàä]/g, "a")
            .replace(/[îïì]/g, "i")
            .replace(/[ôöò]/g, "o")
            .replace(/[ûüù]/g, "u");
    }
}

function searchSwissMarkets(query, currentWatchlist) {
    var rawQuery = stripAccents(query).trim();
    var watchlistSymbols = {};
    if (Array.isArray(currentWatchlist)) {
        currentWatchlist.forEach(function(item) {
            if (item && item.symbol) {
                watchlistSymbols[String(item.symbol).toUpperCase()] = true;
            }
        });
    }

    var results = [];
    PRESET_MARKETS.forEach(function(item) {
        var matches = false;
        if (!rawQuery) {
            matches = true;
        } else {
            var sym = stripAccents(item.symbol);
            var name = stripAccents(item.name);
            var isin = stripAccents(item.isin || "");
            var market = stripAccents(item.market || "");
            var category = stripAccents(item.category || "");

            if (sym.indexOf(rawQuery) !== -1 ||
                name.indexOf(rawQuery) !== -1 ||
                isin.indexOf(rawQuery) !== -1 ||
                market.indexOf(rawQuery) !== -1 ||
                category.indexOf(rawQuery) !== -1) {
                matches = true;
            }
        }

        if (matches) {
            var isAdded = Boolean(watchlistSymbols[item.symbol.toUpperCase()]);
            results.push({
                symbol: item.symbol,
                name: item.name,
                market: item.market,
                currency: item.currency,
                category: item.category,
                isin: item.isin,
                refPrice: item.refPrice,
                refChange: item.refChange,
                refChangePct: item.refChangePct,
                alreadyAdded: isAdded
            });
        }
    });

    try {
        console.log("[SwissStockMarket] Search executed | query: '" + (query || "") + "' (normalized: '" + rawQuery + "') | matches: " + results.length + (results.length > 0 ? " -> " + results.map(function(r) { return r.symbol + " (" + r.name + (r.isin ? ", " + r.isin : "") + ", " + (r.alreadyAdded ? "added" : "new") + ")"; }).join("; ") : ""));
    } catch (e) {}

    return results;
}

function normalizeUrl(rawUrl) {
    if (!rawUrl || typeof rawUrl !== "string") {
        throw new Error("Broker endpoint URL is required.");
    }

    var trimmed = rawUrl.trim();
    if (!trimmed.match(/^https?:\/\//i)) {
        throw new Error("Invalid URL protocol. Use http:// or https://.");
    }

    if (trimmed.indexOf(" ") !== -1 || trimmed.indexOf("\t") !== -1 || trimmed.indexOf("\n") !== -1) {
        throw new Error("URL must not contain whitespace.");
    }

    return trimmed.replace(/\/+$/, "");
}

function endpoint(config) {
    var provider = (config && config.brokerProvider) || "yahoo";
    var rawUrl = config ? config.brokerEndpoint : "";

    if (rawUrl === undefined || rawUrl === null || (rawUrl === "" && provider !== "custom")) {
        var found = BROKER_PROVIDERS.filter(function(p) { return p.id === provider; })[0];
        rawUrl = found ? found.defaultUrl : "https://query1.finance.yahoo.com/v8/finance/chart/";
    }

    var cleanUrl = normalizeUrl(rawUrl);
    var authType = (config && config.authType) || "none";

    return {
        provider: provider,
        url: cleanUrl,
        authType: authType
    };
}

function walletKey(config) {
    var provider = (config && config.brokerProvider) || "yahoo";
    var url = (config && config.brokerEndpoint) || "";
    var user = (config && config.username) || "";
    return "stockmarket:" + provider + ":" + url.trim().toLowerCase() + (user ? ":" + user.trim().toLowerCase() : "");
}

function resolveYahooSymbol(symbol) {
    if (!symbol) return "";
    var s = String(symbol).trim().toUpperCase();
    var mapping = {
        "SMI": "^SSMI",
        "^SSMI": "^SSMI",
        "SPI": "SPI20.SW",
        "SPI20.SW": "SPI20.SW",
        "SLI": "SLI.SW",
        "SLI.SW": "SLI.SW",
        "EURCHF": "EURCHF=X",
        "EUR/CHF": "EURCHF=X",
        "EURCHF=X": "EURCHF=X",
        "USDCHF": "USDCHF=X",
        "USD/CHF": "USDCHF=X",
        "USDCHF=X": "USDCHF=X",
        "BTCCHF": "BTC-USD",
        "BTC/CHF": "BTC-USD",
        "ETHCHF": "ETH-USD",
        "ETH/CHF": "ETH-USD"
    };
    if (mapping[s]) {
        return mapping[s];
    }
    return s;
}

function buildYahooChartUrl(baseUrl, symbol) {
    var rawUrl = baseUrl || "https://query1.finance.yahoo.com/v8/finance/chart/";
    var cleanBase = rawUrl.trim().replace(/\/+$/, "");
    var yahooSym = resolveYahooSymbol(symbol);
    return cleanBase + "/" + encodeURIComponent(yahooSym) + "?interval=1d&range=1d";
}

function formatPrice(price, currency) {
    if (price === null || price === undefined || isNaN(price)) {
        return "—";
    }

    var num = Number(price);
    var formatted;
    if (Math.abs(num) < 2 && Math.abs(num) > 0 && String(num).indexOf(".") !== -1) {
        formatted = num.toFixed(4);
    } else {
        formatted = num.toLocaleString("de-CH", {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    return currency ? formatted + " " + currency : formatted;
}

function formatChange(change, changePercent) {
    if (change === null || change === undefined || isNaN(change)) {
        return "—";
    }

    var chgNum = Number(change);
    var pctNum = (changePercent !== null && changePercent !== undefined && !isNaN(changePercent))
        ? Number(changePercent)
        : null;

    var sign = chgNum > 0 ? "+" : (chgNum < 0 ? "" : "");
    var chgStr = sign + chgNum.toFixed(2);

    if (pctNum !== null) {
        var pctSign = pctNum > 0 ? "+" : (pctNum < 0 ? "" : "");
        return chgStr + " (" + pctSign + pctNum.toFixed(2) + "%)";
    }

    return chgStr;
}

function formatPercentOnly(changePercent) {
    if (changePercent === null || changePercent === undefined || isNaN(changePercent)) {
        return "—";
    }

    var pct = Number(changePercent);
    var sign = pct > 0 ? "+" : "";
    return sign + pct.toFixed(2) + "%";
}

function getQuoteState(change, changePercent, price) {
    if (price === null || price === undefined || isNaN(price)) {
        return "unknown";
    }

    var chg = Number(change !== null && change !== undefined ? change : (changePercent || 0));
    if (chg > 0) return "up";
    if (chg < 0) return "down";
    return "neutral";
}

function formatTimestamp(value) {
    if (!value) return "";
    var date = null;
    if (typeof value === "number") {
        date = new Date(value > 1e11 ? value : value * 1000);
    } else if (value instanceof Date) {
        date = value;
    } else if (typeof value === "string") {
        if (/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}/.test(value)) {
            return value;
        }
        var parsed = Date.parse(value);
        if (!isNaN(parsed)) {
            date = new Date(parsed);
        } else {
            return value;
        }
    }
    if (date && !isNaN(date.getTime())) {
        var pad = function(n) { return n < 10 ? "0" + n : "" + n; };
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate()) + " " +
               pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds());
    }
    return String(value);
}

function normalizeQuote(raw, fallbackItem) {
    fallbackItem = fallbackItem || {};
    raw = raw || {};

    var symbol = raw.symbol || raw.ticker || raw.valors || raw.isin || fallbackItem.symbol || "UNKNOWN";
    var preset = findPresetBySymbol(symbol);
    var name = raw.name || raw.companyName || raw.description || fallbackItem.name || (preset ? preset.name : symbol);
    var market = raw.market || raw.exchange || fallbackItem.market || (preset ? preset.market : "SIX");
    var currency = raw.currency || raw.ccy || fallbackItem.currency || (preset ? preset.currency : "CHF");
    var category = raw.category || fallbackItem.category || (preset ? preset.category : "equities");
    var isin = raw.isin || fallbackItem.isin || (preset ? preset.isin : "");

    var price = (raw.price !== undefined && raw.price !== null) ? Number(raw.price) :
                (raw.last !== undefined && raw.last !== null) ? Number(raw.last) :
                (raw.close !== undefined && raw.close !== null) ? Number(raw.close) :
                (raw.value !== undefined && raw.value !== null) ? Number(raw.value) : null;

    var prevClose = (raw.prevClose !== undefined && raw.prevClose !== null) ? Number(raw.prevClose) :
                    (raw.previousClose !== undefined && raw.previousClose !== null) ? Number(raw.previousClose) :
                    (raw.close !== undefined && price !== null && raw.close !== price) ? Number(raw.close) : null;

    var change = (raw.change !== undefined && raw.change !== null) ? Number(raw.change) :
                 (raw.diff !== undefined && raw.diff !== null) ? Number(raw.diff) : null;

    var changePercent = (raw.changePercent !== undefined && raw.changePercent !== null) ? Number(raw.changePercent) :
                        (raw.changePct !== undefined && raw.changePct !== null) ? Number(raw.changePct) :
                        (raw.diffPct !== undefined && raw.diffPct !== null) ? Number(raw.diffPct) : null;

    // Use preset ref prices if no price was provided in raw data
    if (price === null && preset && preset.refPrice !== undefined) {
        price = preset.refPrice;
        if (change === null) change = preset.refChange || 0;
        if (changePercent === null) changePercent = preset.refChangePct || 0;
        if (prevClose === null && price !== null && change !== null) prevClose = price - change;
    }

    // Calculate change if missing but price & prevClose available
    if (change === null && price !== null && prevClose !== null && prevClose > 0) {
        change = price - prevClose;
    }
    if (changePercent === null && change !== null && prevClose !== null && prevClose > 0) {
        changePercent = (change / prevClose) * 100;
    } else if (changePercent === null && change !== null && price !== null && (price - change) > 0) {
        changePercent = (change / (price - change)) * 100;
    }

    var high = (raw.high !== undefined && raw.high !== null) ? Number(raw.high) :
               (raw.dayHigh !== undefined && raw.dayHigh !== null) ? Number(raw.dayHigh) :
               (price !== null ? (price * 1.008) : null);

    var low = (raw.low !== undefined && raw.low !== null) ? Number(raw.low) :
              (raw.dayLow !== undefined && raw.dayLow !== null) ? Number(raw.dayLow) :
              (price !== null ? (price * 0.992) : null);

    var open = (raw.open !== undefined && raw.open !== null) ? Number(raw.open) :
               (raw.dayOpen !== undefined && raw.dayOpen !== null) ? Number(raw.dayOpen) :
               (prevClose !== null ? prevClose : price);

    var volume = (raw.volume !== undefined && raw.volume !== null) ? Number(raw.volume) : null;

    var timestamp = formatTimestamp(raw.timestamp || raw.time || raw.updated || raw.date || "");

    var state = getQuoteState(change, changePercent, price);

    return {
        symbol: String(symbol).toUpperCase(),
        name: String(name),
        market: String(market),
        currency: String(currency),
        category: String(category),
        isin: String(isin),
        price: price,
        prevClose: prevClose,
        change: change,
        changePercent: changePercent,
        high: high,
        low: low,
        open: open,
        volume: volume,
        timestamp: timestamp,
        state: state,
        formattedPrice: formatPrice(price, currency),
        formattedChange: formatChange(change, changePercent),
        formattedPercent: formatPercentOnly(changePercent)
    };
}

function generateSimulatedQuotes(watchlist) {
    var items = Array.isArray(watchlist) && watchlist.length > 0 ? watchlist : defaultWatchlist();
    var quotes = [];

    items.forEach(function(item) {
        if (!item || !item.symbol || item.enabled === false) return;
        var preset = findPresetBySymbol(item.symbol);
        var basePrice = (preset && preset.refPrice) ? preset.refPrice : 100.0;
        var baseChange = (preset && preset.refChange) ? preset.refChange : 0.50;
        var baseChangePct = (preset && preset.refChangePct) ? preset.refChangePct : 0.50;

        // Subtle realistic jitter (+/- 0.2%)
        var jitterFactor = 1 + (Math.sin(Date.now() / 60000 + item.symbol.charCodeAt(0)) * 0.002);
        var price = Number((basePrice * jitterFactor).toFixed(4));
        var change = Number((baseChange * jitterFactor).toFixed(4));
        var changePercent = Number((baseChangePct * jitterFactor).toFixed(2));

        quotes.push(normalizeQuote({
            symbol: item.symbol,
            name: item.name || (preset ? preset.name : item.symbol),
            market: item.market || (preset ? preset.market : "SIX"),
            currency: item.currency || (preset ? preset.currency : "CHF"),
            category: item.category || (preset ? preset.category : "equities"),
            isin: item.isin || (preset ? preset.isin : ""),
            price: price,
            change: change,
            changePercent: changePercent,
            prevClose: price - change,
            high: price * 1.006,
            low: price * 0.994,
            open: price - (change * 0.5),
            volume: Math.floor(150000 + Math.random() * 500000),
            timestamp: formatTimestamp(new Date())
        }, item));
    });

    return quotes;
}

function getInitialQuotes(watchlist) {
    var items = Array.isArray(watchlist) && watchlist.length > 0 ? watchlist : defaultWatchlist();
    var quotes = [];
    items.forEach(function(item) {
        if (!item || !item.symbol || item.enabled === false) return;
        quotes.push(normalizeQuote(null, item));
    });
    return quotes;
}

function parseYahooChartResponse(payload, fallbackItem) {
    fallbackItem = fallbackItem || {};
    if (typeof payload === "string") {
        try {
            payload = JSON.parse(payload);
        } catch (e) {
            throw new Error("Invalid JSON response from Yahoo Finance.");
        }
    }

    if (!payload || typeof payload !== "object") {
        throw new Error("Empty response from Yahoo Finance.");
    }

    if (payload.chart && payload.chart.error) {
        throw new Error(payload.chart.error.description || payload.chart.error.code || "Yahoo Finance error");
    }

    var result = (payload.chart && Array.isArray(payload.chart.result)) ? payload.chart.result[0] : null;
    if (!result || !result.meta) {
        return normalizeQuote(payload, fallbackItem);
    }

    var meta = result.meta;
    var symbol = fallbackItem.symbol || meta.symbol || "UNKNOWN";
    var preset = findPresetBySymbol(symbol);
    var name = fallbackItem.name || meta.shortName || meta.longName || (preset ? preset.name : symbol);
    var market = fallbackItem.market || (meta.exchangeName === "EBS" ? "SIX" : (meta.exchangeName || (preset ? preset.market : "SIX")));
    var currency = meta.currency || fallbackItem.currency || (preset ? preset.currency : "CHF");
    var category = fallbackItem.category || (preset ? preset.category : "equities");
    var isin = fallbackItem.isin || (preset ? preset.isin : "");

    var price = (meta.regularMarketPrice !== undefined && meta.regularMarketPrice !== null)
        ? Number(meta.regularMarketPrice)
        : null;

    var prevClose = (meta.chartPreviousClose !== undefined && meta.chartPreviousClose !== null)
        ? Number(meta.chartPreviousClose)
        : ((meta.previousClose !== undefined && meta.previousClose !== null) ? Number(meta.previousClose) : null);

    var change = (price !== null && prevClose !== null)
        ? (price - prevClose)
        : ((meta.fulldayChange !== undefined && meta.fulldayChange !== null) ? Number(meta.fulldayChange) : null);

    var changePercent = (meta.regularMarketChangePercent !== undefined && meta.regularMarketChangePercent !== null)
        ? Number(meta.regularMarketChangePercent)
        : (change !== null && prevClose !== null && prevClose > 0 ? (change / prevClose) * 100 : null);

    var high = (meta.regularMarketDayHigh !== undefined && meta.regularMarketDayHigh !== null)
        ? Number(meta.regularMarketDayHigh)
        : (price !== null ? price * 1.008 : null);

    var low = (meta.regularMarketDayLow !== undefined && meta.regularMarketDayLow !== null)
        ? Number(meta.regularMarketDayLow)
        : (price !== null ? price * 0.992 : null);

    var open = (prevClose !== null) ? prevClose : price;
    var volume = (meta.regularMarketVolume !== undefined && meta.regularMarketVolume !== null)
        ? Number(meta.regularMarketVolume)
        : null;

    var timestamp = meta.regularMarketTime
        ? formatTimestamp(meta.regularMarketTime)
        : formatTimestamp(new Date());

    return normalizeQuote({
        symbol: symbol,
        name: name,
        market: market,
        currency: currency,
        category: category,
        isin: isin,
        price: price,
        prevClose: prevClose,
        change: change,
        changePercent: changePercent,
        high: high,
        low: low,
        open: open,
        volume: volume,
        timestamp: timestamp
    }, fallbackItem);
}

function parseQuotesResponse(payload, watchlist) {
    if (typeof payload === "string") {
        try {
            payload = JSON.parse(payload);
        } catch (e) {
            throw new Error("Invalid JSON response from Swiss broker.");
        }
    }

    if (!payload || typeof payload !== "object") {
        throw new Error("Empty or invalid broker response.");
    }

    if (payload.chart) {
        if (payload.chart.error) {
            throw new Error(payload.chart.error.description || payload.chart.error.code || "Yahoo Finance error");
        }
        var singleFallback = (Array.isArray(watchlist) && watchlist.length > 0) ? watchlist[0] : {};
        return [parseYahooChartResponse(payload, singleFallback)];
    }

    var rawList = [];

    if (Array.isArray(payload)) {
        rawList = payload;
    } else if (Array.isArray(payload.data)) {
        rawList = payload.data;
    } else if (Array.isArray(payload.quotes)) {
        rawList = payload.quotes;
    } else if (Array.isArray(payload.instruments)) {
        rawList = payload.instruments;
    } else if (payload.quotes && typeof payload.quotes === "object") {
        Object.keys(payload.quotes).forEach(function(k) {
            var item = payload.quotes[k];
            if (item && typeof item === "object") {
                if (!item.symbol) item.symbol = k;
                rawList.push(item);
            }
        });
    } else if (payload.symbol || payload.price || payload.last) {
        rawList = [payload];
    } else {
        Object.keys(payload).forEach(function(k) {
            var item = payload[k];
            if (item && typeof item === "object" && (item.price !== undefined || item.last !== undefined || item.close !== undefined)) {
                if (!item.symbol) item.symbol = k;
                rawList.push(item);
            }
        });
    }

    var watchlistMap = {};
    if (Array.isArray(watchlist)) {
        watchlist.forEach(function(w) {
            if (w && w.symbol) {
                watchlistMap[String(w.symbol).toUpperCase()] = w;
            }
        });
    }

    var normalized = [];
    var seen = {};

    rawList.forEach(function(raw) {
        if (!raw || typeof raw !== "object") return;
        var rawSym = raw.symbol || raw.ticker || raw.valors || raw.isin || "";
        var symKey = String(rawSym).toUpperCase();
        var fallback = watchlistMap[symKey] || {};
        var item = normalizeQuote(raw, fallback);
        if (item.symbol && !seen[item.symbol]) {
            seen[item.symbol] = true;
            normalized.push(item);
        }
    });

    if (Array.isArray(watchlist)) {
        watchlist.forEach(function(w) {
            if (!w || !w.symbol) return;
            var symKey = String(w.symbol).toUpperCase();
            if (!seen[symKey] && w.enabled !== false) {
                seen[symKey] = true;
                normalized.push(normalizeQuote(null, w));
            }
        });
    }

    return normalized;
}

function aggregateMarket(quotes) {
    if (!Array.isArray(quotes) || quotes.length === 0) {
        return {
            overall: "unknown",
            total: 0,
            gainers: 0,
            losers: 0,
            unchanged: 0
        };
    }

    var gainers = 0;
    var losers = 0;
    var unchanged = 0;
    var known = 0;

    quotes.forEach(function(q) {
        if (q.state === "up") {
            gainers++;
            known++;
        } else if (q.state === "down") {
            losers++;
            known++;
        } else if (q.state === "neutral") {
            unchanged++;
            known++;
        }
    });

    var overall = "unknown";
    if (known > 0) {
        if (gainers > losers) {
            overall = "up";
        } else if (losers > gainers) {
            overall = "down";
        } else {
            overall = "neutral";
        }
    }

    return {
        overall: overall,
        total: quotes.length,
        gainers: gainers,
        losers: losers,
        unchanged: unchanged
    };
}

function buildSymbolsQuery(watchlist) {
    if (!Array.isArray(watchlist)) return "";
    var symbols = watchlist
        .filter(function(item) { return item && item.symbol && item.enabled !== false; })
        .map(function(item) { return encodeURIComponent(item.symbol.trim()); });
    return symbols.join(",");
}

function getSwissquoteUrl(quote) {
    if (!quote) {
        return "https://www.swissquote.ch";
    }
    if (typeof quote === "string") {
        var trimmed = quote.trim();
        if (!trimmed) return "https://www.swissquote.ch";
        return "https://en.swissquote.com/trading/markets/search?query=" + encodeURIComponent(trimmed);
    }
    if (quote.isin && typeof quote.isin === "string" && quote.isin.trim().length === 12) {
        return "https://en.swissquote.com/trading/markets/search?query=" + encodeURIComponent(quote.isin.trim());
    }
    if (quote.symbol && typeof quote.symbol === "string" && quote.symbol.trim().length > 0) {
        return "https://en.swissquote.com/trading/markets/search?query=" + encodeURIComponent(quote.symbol.trim());
    }
    return "https://www.swissquote.ch";
}

function base64Encode(str) {
    const text = String(str || "");
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    let encoded = "";
    let c1, c2, c3, e1, e2, e3, e4;
    let i = 0;
    const utf8 = unescape(encodeURIComponent(text));
    while (i < utf8.length) {
        c1 = utf8.charCodeAt(i++);
        c2 = utf8.charCodeAt(i++);
        c3 = utf8.charCodeAt(i++);
        e1 = c1 >> 2;
        e2 = ((c1 & 3) << 4) | (c2 >> 4);
        e3 = ((c2 & 15) << 2) | (c3 >> 6);
        e4 = c3 & 63;
        if (isNaN(c2)) {
            e3 = e4 = 64;
        } else if (isNaN(c3)) {
            e4 = 64;
        }
        encoded += chars.charAt(e1) + chars.charAt(e2) + chars.charAt(e3) + chars.charAt(e4);
    }
    return encoded;
}
