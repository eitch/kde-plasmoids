const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const dashboardSource = fs.readFileSync(
    path.join(__dirname, "../contents/ui/Dashboard.qml"), "utf8"
);
const dashboardFunctions = dashboardSource.slice(
    dashboardSource.indexOf("    function publish"),
    dashboardSource.indexOf("    Timer {")
);

function createDashboardHarness(entry) {
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

    const kuma = {};
    vm.createContext(kuma);
    vm.runInContext(
        fs.readFileSync(path.join(__dirname, "../contents/code/Kuma.js"), "utf8"),
        kuma
    );

    const context = {
        Kuma: kuma,
        entry: entry,
        rows: [],
        groups: [],
        requests: [],
        generation: 0,
        busy: false,
        status: "unknown",
        error: "",
        updated: "",
        deadline: 0,
        XMLHttpRequest: MockRequest,
        Qt: {
            formatDateTime: () => "now",
            btoa: text => Buffer.from(text, "utf8").toString("base64")
        },
        changed: () => {},
        wallet: {
            access: (key, password, writing, onComplete) => onComplete("", "example-key")
        }
    };

    vm.createContext(context);
    vm.runInContext(dashboardFunctions, context);
    return {context, requests};
}

function testPrivateRequests() {
    const {context, requests} = createDashboardHarness({
        type: "admin",
        url: "https://kuma.test/dashboard"
    });

    context.refresh();
    assert.equal(requests[0].url, "https://kuma.test/metrics");
    assert.equal(
        requests[0].headers.Authorization,
        "Basic " + Buffer.from(":example-key").toString("base64")
    );

    context.refresh();
    assert.equal(requests.length, 1, "Ignore refreshes while a request is pending");
    requests[0].reply(200, 'monitor_status{monitor_id="1",monitor_name="Web"} 1');
    assert.equal(context.status, "up");
    assert.equal(context.groups.length, 1);
    assert.equal(context.groups[0].name, "");

    context.refresh();
    requests[1].reply(401, "Unauthorized");
    assert.equal(context.status, "unknown");
    assert.equal(context.rows.length, 0);
    assert.equal(context.groups.length, 0);

    context.refresh();
    context.fail("Connection timed out.");
    requests[2].reply(200, 'monitor_status{monitor_id="1",monitor_name="Web"} 1');
    assert.equal(context.status, "unknown", "A stale reply must not replace the timeout");
    assert.ok(requests[2].aborted);
}

function testPublicRequests() {
    const {context, requests} = createDashboardHarness({
        type: "public",
        url: "https://status.test/status/services"
    });

    context.refresh();
    assert.equal(requests[0].headers.Authorization, undefined);
    requests[0].reply(200, JSON.stringify({
        publicGroupList: [{
            name: "Services",
            monitorList: [{id: 1, name: "Web"}]
        }]
    }));

    assert.equal(requests[1].url, "https://status.test/api/status-page/heartbeat/services");
    requests[1].reply(200, JSON.stringify({heartbeatList: {1: [{status: 0}]}}));
    assert.equal(context.status, "down");
    assert.equal(context.groups[0].name, "Services");

    context.refresh();
    requests[2].reply(200, "<html>login</html>");
    assert.equal(context.status, "unknown");
}

function testWalletFailure() {
    const {context, requests} = createDashboardHarness({
        type: "admin",
        url: "https://kuma.test"
    });
    context.wallet.access = (key, password, writing, onComplete) => {
        onComplete("Wallet locked", "");
    };

    context.refresh();
    assert.equal(requests.length, 0);
    assert.equal(context.error, "Wallet locked");
}

function testGroupedPrivateRequests() {
    const {context, requests} = createDashboardHarness({
        type: "admin",
        url: "https://kuma.test/dashboard",
        slug: "internal"
    });

    context.refresh();
    requests[0].reply(200, [
        'monitor_status{monitor_id="1",monitor_name="Web"} 1',
        'monitor_status{monitor_id="2",monitor_name="Outside page"} 0'
    ].join("\n"));
    assert.equal(requests[1].url, "https://kuma.test/api/status-page/internal");
    assert.equal(requests[1].headers.Authorization, undefined);
    assert.equal(context.busy, true);
    requests[1].reply(200, JSON.stringify({
        publicGroupList: [{
            name: "Internal",
            monitorList: [{id: 1, name: "Web alias"}]
        }]
    }));

    assert.equal(requests[2].url, "https://kuma.test/api/status-page/heartbeat/internal");
    assert.equal(requests[2].headers.Authorization, undefined);
    requests[2].reply(200, JSON.stringify({heartbeatList: {1: [{status: 1}]}}));
    assert.equal(context.groups[0].name, "Internal");
    assert.equal(context.rows.length, 1);
    assert.equal(context.status, "up");
    assert.equal(context.rows[0].name, "Web alias");

    context.refresh();
    requests[3].reply(200, 'monitor_status{monitor_id="1",monitor_name="Web"} 1');
    requests[4].reply(404, "Missing page");
    assert.equal(context.status, "unknown");
    assert.equal(context.groups.length, 0);
}

testPrivateRequests();
testPublicRequests();
testWalletFailure();
testGroupedPrivateRequests();
console.log("HTTP, credential isolation, grouping, timeout and stale-response checks passed");
