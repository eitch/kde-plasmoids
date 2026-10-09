const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const market = { console };
vm.createContext(market);
vm.runInContext(
    fs.readFileSync(path.join(__dirname, "../contents/code/Market.js"), "utf8"),
    market
);

function testEndpoints() {
    assert.equal(market.endpoint({
        brokerProvider: "yahoo"
    }).url, "https://query1.finance.yahoo.com/v8/finance/chart");

    assert.equal(market.endpoint().url, "https://query1.finance.yahoo.com/v8/finance/chart");

    assert.equal(market.endpoint({
        brokerProvider: "custom",
        brokerEndpoint: "https://query2.finance.yahoo.com/v8/finance/chart/"
    }).url, "https://query2.finance.yahoo.com/v8/finance/chart");

    const invalidUrls = [
        "",
        "file:///tmp/quotes",
        "ftp://quotes.test",
        "https://broker.test/with space",
        "https://broker.test/with\ttab",
        "just-a-string"
    ];

    for (const url of invalidUrls) {
        assert.throws(() => market.endpoint({brokerProvider: "custom", brokerEndpoint: url}));
    }

    assert.notEqual(
        market.walletKey({brokerProvider: "yahoo", brokerEndpoint: "https://a.test"}),
        market.walletKey({brokerProvider: "yahoo", brokerEndpoint: "https://b.test"})
    );
}

function testYahooFinanceHelpers() {
    assert.equal(market.resolveYahooSymbol("SMI"), "^SSMI");
    assert.equal(market.resolveYahooSymbol("SPI"), "SPI20.SW");
    assert.equal(market.resolveYahooSymbol("SLI"), "SLI.SW");
    assert.equal(market.resolveYahooSymbol("EURCHF"), "EURCHF=X");
    assert.equal(market.resolveYahooSymbol("USDCHF"), "USDCHF=X");
    assert.equal(market.resolveYahooSymbol("NESN.SW"), "NESN.SW");
    assert.equal(market.resolveYahooSymbol("^GDAXI"), "^GDAXI");

    assert.equal(
        market.buildYahooChartUrl("https://query1.finance.yahoo.com/v8/finance/chart/", "SMI"),
        "https://query1.finance.yahoo.com/v8/finance/chart/%5ESSMI?interval=1d&range=1d"
    );

    const yahooPayload = {
        chart: {
            result: [
                {
                    meta: {
                        currency: "CHF",
                        symbol: "^SSMI",
                        exchangeName: "EBS",
                        regularMarketPrice: 13637.0,
                        chartPreviousClose: 13808.4,
                        previousClose: 13808.4,
                        regularMarketDayHigh: 13746.19,
                        regularMarketDayLow: 13617.92,
                        regularMarketTime: 1791473432,
                        shortName: "SMI PR",
                        regularMarketChangePercent: -1.241
                    }
                }
            ],
            error: null
        }
    };

    const parsed = market.parseYahooChartResponse(yahooPayload, { symbol: "SMI", name: "Swiss Market Index" });
    assert.equal(parsed.symbol, "SMI");
    assert.equal(parsed.price, 13637.0);
    assert.equal(parsed.prevClose, 13808.4);
    assert.equal(parsed.state, "down");
    assert.equal(parsed.currency, "CHF");
    assert.ok(parsed.formattedPrice.includes("13"));
    assert.ok(parsed.timestamp.length > 0);
    assert.ok(/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}$/.test(parsed.timestamp));
}

function testNormalizeQuote() {
    const sqQuote = market.normalizeQuote({
        symbol: "SQN",
        name: "Swissquote Group Holding SA",
        price: 35.24,
        change: -1.42,
        changePercent: -3.87,
        high: 37.20,
        low: 35.24,
        open: 36.98,
        prevClose: 36.66,
        volume: 329280,
        currency: "CHF",
        market: "SIX"
    });

    assert.equal(sqQuote.symbol, "SQN");
    assert.equal(sqQuote.price, 35.24);
    assert.equal(sqQuote.state, "down");
    assert.equal(sqQuote.formattedPercent, "-3.87%");
    assert.ok(sqQuote.formattedPrice.includes("35"));

    const sixQuote = market.normalizeQuote({
        valors: "NESN",
        last: 98.50,
        close: 97.00,
        dayHigh: 99.00,
        dayLow: 96.80,
        dayOpen: 97.20,
        currency: "CHF"
    }, { name: "Nestlé SA", market: "SIX" });

    assert.equal(sixQuote.symbol, "NESN");
    assert.equal(sixQuote.price, 98.50);
    assert.equal(sixQuote.prevClose, 97.00);
    assert.equal(sixQuote.change, 1.50);
    assert.equal(sixQuote.state, "up");
    assert.equal(sixQuote.name, "Nestlé SA");

    const neutralQuote = market.normalizeQuote({
        symbol: "SMI",
        price: 12000,
        change: 0,
        changePercent: 0
    });
    assert.equal(neutralQuote.state, "neutral");

    const emptyQuote = market.normalizeQuote(null, { symbol: "CUSTOM_STOCK", name: "Custom Stock", price: null });
    assert.equal(emptyQuote.symbol, "CUSTOM_STOCK");
    assert.equal(emptyQuote.name, "Custom Stock");
    assert.ok(emptyQuote.formattedPrice);
}

function testSearchSwissMarkets() {
    const watchlist = [
        { symbol: "SMI", name: "Swiss Market Index" },
        { symbol: "EURCHF", name: "EUR / CHF" }
    ];

    const logs = [];
    const customConsole = {
        log: function(...args) {
            logs.push(args.join(" "));
        }
    };
    const testMarket = { console: customConsole };
    vm.createContext(testMarket);
    vm.runInContext(
        fs.readFileSync(path.join(__dirname, "../contents/code/Market.js"), "utf8"),
        testMarket
    );

    // Search by ticker symbol
    const sliResults = testMarket.searchSwissMarkets("SLI", watchlist);
    assert.ok(sliResults.length > 0);
    assert.equal(sliResults[0].symbol, "SLI");
    assert.equal(sliResults[0].alreadyAdded, false);
    assert.ok(logs.some(l => l.includes("[SwissStockMarket]") && l.includes("SLI") && l.includes("Swiss Leader Index")));

    // Search by name / keyword
    const cryptoResults = testMarket.searchSwissMarkets("Bitcoin", watchlist);
    assert.ok(cryptoResults.length > 0);
    assert.equal(cryptoResults[0].symbol, "BTCCHF");
    assert.ok(logs.some(l => l.includes("[SwissStockMarket]") && l.includes("Bitcoin") && l.includes("BTCCHF")));

    // Search by ISIN
    const isinResults = testMarket.searchSwissMarkets("CH0030252883", watchlist);
    assert.ok(isinResults.length > 0);
    assert.equal(isinResults[0].symbol, "SLI");

    // Search for already added symbol
    const addedResults = testMarket.searchSwissMarkets("EURCHF", watchlist);
    assert.ok(addedResults.length > 0);
    assert.equal(addedResults[0].symbol, "EURCHF");
    assert.equal(addedResults[0].alreadyAdded, true);

    // Empty search returns all presets
    const allPresets = testMarket.searchSwissMarkets("", watchlist);
    assert.ok(allPresets.length > 0);
    assert.ok(logs.some(l => l.includes("[SwissStockMarket]") && l.includes("matches: " + allPresets.length)));
}

function testSimulatedQuotes() {
    const watchlist = [
        { symbol: "SMI", name: "Swiss Market Index", enabled: true },
        { symbol: "SPI", name: "Swiss Performance Index", enabled: true },
        { symbol: "EURCHF", name: "EUR / CHF", enabled: true }
    ];

    const quotes = market.generateSimulatedQuotes(watchlist);
    assert.equal(quotes.length, 3);
    assert.equal(quotes[0].symbol, "SMI");
    assert.ok(quotes[0].price > 10000);
    assert.equal(quotes[1].symbol, "SPI");
    assert.ok(quotes[1].price > 10000);
    assert.equal(quotes[2].symbol, "EURCHF");
    assert.ok(quotes[2].price < 2);
}

function testParseQuotesResponse() {
    const watchlist = [
        { symbol: "SMI", name: "Swiss Market Index", enabled: true },
        { symbol: "SPI", name: "Swiss Performance Index", enabled: true },
        { symbol: "EURCHF", name: "EUR / CHF", enabled: true }
    ];

    // Array format
    const arrayPayload = JSON.stringify([
        { symbol: "SMI", price: 12150.40, change: 45.20, changePercent: 0.37 },
        { symbol: "SPI", price: 16200.50, change: 30.10, changePercent: 0.19 }
    ]);
    const arrayResult = market.parseQuotesResponse(arrayPayload, watchlist);
    assert.equal(arrayResult.length, 3);
    assert.equal(arrayResult[0].symbol, "SMI");
    assert.equal(arrayResult[0].price, 12150.40);
    assert.equal(arrayResult[1].symbol, "SPI");
    assert.equal(arrayResult[2].symbol, "EURCHF");

    // Object with data array
    const dataObjPayload = {
        data: [
            { symbol: "SPI", price: 16180.20, change: 42.10 }
        ]
    };
    const dataObjResult = market.parseQuotesResponse(dataObjPayload, watchlist);
    assert.equal(dataObjResult.find(q => q.symbol === "SPI").price, 16180.20);

    // Dictionary format
    const dictPayload = {
        quotes: {
            "SMI": { price: 12150.40, change: 45.20 },
            "SPI": { price: 16200.50, change: 30.10 }
        }
    };
    const dictResult = market.parseQuotesResponse(dictPayload, watchlist);
    assert.equal(dictResult.find(q => q.symbol === "SPI").price, 16200.50);

    // Single item format
    const singlePayload = { symbol: "SMI", price: 12150.40, change: 10 };
    const singleResult = market.parseQuotesResponse(singlePayload, watchlist);
    assert.equal(singleResult.find(q => q.symbol === "SMI").price, 12150.40);

    // Malformed JSON
    assert.throws(() => market.parseQuotesResponse("{broken-json", watchlist));
    assert.throws(() => market.parseQuotesResponse(null, watchlist));
}

function testAggregation() {
    const bullishQuotes = [
        { state: "up" },
        { state: "up" },
        { state: "down" }
    ];
    assert.equal(market.aggregateMarket(bullishQuotes).overall, "up");
    assert.equal(market.aggregateMarket(bullishQuotes).gainers, 2);
    assert.equal(market.aggregateMarket(bullishQuotes).losers, 1);

    const bearishQuotes = [
        { state: "down" },
        { state: "down" },
        { state: "up" }
    ];
    assert.equal(market.aggregateMarket(bearishQuotes).overall, "down");

    const neutralQuotes = [
        { state: "up" },
        { state: "down" }
    ];
    assert.equal(market.aggregateMarket(neutralQuotes).overall, "neutral");

    assert.equal(market.aggregateMarket([]).overall, "unknown");
}

function testFormattingAndQuery() {
    assert.equal(market.formatPrice(null), "—");
    assert.equal(market.formatPrice(12.5, "CHF"), "12.50 CHF");
    assert.equal(market.formatPrice(0.9345, "CHF"), "0.9345 CHF");

    assert.equal(market.formatChange(1.5, 2.3), "+1.50 (+2.30%)");
    assert.equal(market.formatChange(-0.8, -1.2), "-0.80 (-1.20%)");
    assert.equal(market.formatChange(null), "—");

    const query = market.buildSymbolsQuery([
        { symbol: "SMI", enabled: true },
        { symbol: "SQN", enabled: true },
        { symbol: "HIDDEN", enabled: false }
    ]);
    assert.equal(query, "SMI,SQN");
}

testEndpoints();
testYahooFinanceHelpers();
testNormalizeQuote();
testSearchSwissMarkets();
testSimulatedQuotes();
testParseQuotesResponse();
testAggregation();
testFormattingAndQuery();

console.log("Market helpers, broker endpoints, search, simulation, normalization and aggregation checks passed");
