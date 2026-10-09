const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const marketSourceCode = fs.readFileSync(
    path.join(__dirname, "../contents/ui/MarketSource.qml"), "utf8"
);
const sourceFunctions = marketSourceCode.slice(
    marketSourceCode.indexOf("    function publish"),
    marketSourceCode.indexOf("    Timer {")
);

function createSourceHarness(brokerConfig, watchlist) {
    const requests = [];

    function MockRequest() {
        requests.push(this);
        this.headers = {};
    }

    MockRequest.DONE = 4;
    MockRequest.prototype.open = function(method, url) {
        this.method = method;
        this.url = url;
    };
    MockRequest.prototype.setRequestHeader = function(headerName, headerValue) {
        this.headers[headerName] = headerValue;
    };
    MockRequest.prototype.send = function() {};
    MockRequest.prototype.abort = function() {
        this.aborted = true;
    };
    MockRequest.prototype.reply = function(statusCode, responseBody) {
        this.status = statusCode;
        this.responseText = responseBody;
        this.readyState = MockRequest.DONE;
        this.onreadystatechange();
    };

    const market = {};
    vm.createContext(market);
    vm.runInContext(
        fs.readFileSync(path.join(__dirname, "../contents/code/Market.js"), "utf8"),
        market
    );

    const context = {
        Market: market,
        brokerConfig: brokerConfig || {
            brokerProvider: "yahoo",
            brokerEndpoint: "https://query1.finance.yahoo.com/v8/finance/chart/",
            authType: "none",
            token: ""
        },
        watchlist: watchlist || [
            { symbol: "SMI", name: "Swiss Market Index", enabled: true },
            { symbol: "EURCHF", name: "EUR / CHF", enabled: true }
        ],
        quotes: [],
        summary: {},
        requests: [],
        generation: 0,
        busy: false,
        status: "unknown",
        error: "",
        updated: "",
        deadline: 0,
        XMLHttpRequest: MockRequest,
        Qt: {
            formatDateTime: () => "12:00:00",
            btoa: text => Buffer.from(text, "utf8").toString("base64")
        },
        changed: () => {},
        wallet: {
            access: (key, password, writing, onComplete) => onComplete("", "mock-wallet-token")
        }
    };

    vm.createContext(context);
    vm.runInContext(sourceFunctions, context);
    return {context, requests};
}

function testPublicQuotesRequest() {
    const {context, requests} = createSourceHarness({
        brokerProvider: "yahoo",
        brokerEndpoint: "https://query1.finance.yahoo.com/v8/finance/chart/",
        authType: "none"
    }, [
        { symbol: "SMI", name: "Swiss Market Index", enabled: true },
        { symbol: "EURCHF", name: "EUR / CHF", enabled: true }
    ]);

    context.refresh();
    assert.equal(requests.length, 2);
    assert.equal(requests[0].url, "https://query1.finance.yahoo.com/v8/finance/chart/%5ESSMI?interval=1d&range=1d");
    assert.equal(requests[1].url, "https://query1.finance.yahoo.com/v8/finance/chart/EURCHF%3DX?interval=1d&range=1d");
    assert.equal(requests[0].headers.Authorization, undefined);

    // Busy check: don't start duplicate requests while in-flight
    context.refresh();
    assert.equal(requests.length, 2);

    // Reply with valid quote JSON for both
    requests[0].reply(200, JSON.stringify({
        chart: {
            result: [{
                meta: {
                    symbol: "^SSMI",
                    regularMarketPrice: 13637.0,
                    chartPreviousClose: 13808.4,
                    currency: "CHF"
                }
            }],
            error: null
        }
    }));
    requests[1].reply(200, JSON.stringify({
        chart: {
            result: [{
                meta: {
                    symbol: "EURCHF=X",
                    regularMarketPrice: 0.9325,
                    chartPreviousClose: 0.9319,
                    currency: "CHF"
                }
            }],
            error: null
        }
    }));

    assert.equal(context.quotes.length, 2);
    assert.equal(context.quotes[0].symbol, "SMI");
    assert.equal(context.quotes[0].price, 13637.0);
    assert.equal(context.quotes[1].symbol, "EURCHF");
    assert.equal(context.quotes[1].price, 0.9325);
    assert.equal(context.error, "");
    assert.equal(context.busy, false);
}

function testAuthenticatedRequest() {
    const {context, requests} = createSourceHarness({
        brokerProvider: "custom",
        brokerEndpoint: "https://broker.swiss.test/api/quotes",
        authType: "apikey"
    });

    context.refresh();
    assert.equal(requests.length, 1);
    assert.equal(requests[0].headers.Authorization, "Bearer mock-wallet-token");
    assert.equal(requests[0].headers["X-API-KEY"], "mock-wallet-token");

    requests[0].reply(200, JSON.stringify([
        { symbol: "SMI", price: 12200, change: 50 }
    ]));
    assert.equal(context.quotes[0].price, 12200);
}

function testBrokerErrorsAndTimeout() {
    const {context, requests} = createSourceHarness({
        brokerProvider: "custom",
        brokerEndpoint: "https://broker.swiss.test/api/quotes",
        authType: "none"
    });

    // 401 Unauthorized
    context.refresh();
    requests[0].reply(401, "Unauthorized");
    assert.equal(context.status, "unknown");
    assert.ok(context.error.includes("401"));

    // Invalid JSON
    context.refresh();
    requests[1].reply(200, "<html>Bad Gateway</html>");
    assert.equal(context.status, "unknown");
    assert.ok(context.error.includes("Invalid"));

    // Timeout & stale response rejection
    context.refresh();
    context.fail("Swiss broker connection timed out.");
    requests[2].reply(200, JSON.stringify([{ symbol: "SMI", price: 12000 }]));
    assert.equal(context.error, "Swiss broker connection timed out.");
    assert.ok(requests[2].aborted);
}

function testWalletFailure() {
    const {context, requests} = createSourceHarness({
        brokerProvider: "custom",
        brokerEndpoint: "https://broker.swiss.test",
        authType: "apikey"
    });
    context.wallet.access = (key, password, writing, onComplete) => {
        onComplete("KWallet locked", "");
    };

    context.refresh();
    assert.equal(requests.length, 0);
    assert.equal(context.error, "KWallet locked");
}

testPublicQuotesRequest();
testAuthenticatedRequest();
testBrokerErrorsAndTimeout();
testWalletFailure();

console.log("Swiss broker HTTP requests, authentication, error handling and timeout checks passed");
