const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const sourceContent = fs.readFileSync(
    path.join(__dirname, "../contents/ui/JenkinsSource.qml"), "utf8"
);
const sourceFunctions = sourceContent.slice(
    sourceContent.indexOf("    function publish"),
    sourceContent.indexOf("    Timer {")
);

function createSourceHarness(entry) {
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

    const jenkins = {};
    vm.createContext(jenkins);
    vm.runInContext(
        fs.readFileSync(path.join(__dirname, "../contents/code/Jenkins.js"), "utf8"),
        jenkins
    );

    const context = {
        Jenkins: jenkins,
        entry: entry,
        builds: [],
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
            access: (key, password, writing, onComplete) => onComplete("", "mock-token-or-pass")
        }
    };

    vm.createContext(context);
    vm.runInContext(sourceFunctions, context);
    return {context, requests};
}

function testAuthenticatedRequests() {
    const {context, requests} = createSourceHarness({
        type: "token",
        url: "https://jenkins.test",
        username: "developer"
    });

    context.refresh();
    assert.equal(requests.length, 1);
    assert.ok(requests[0].url.startsWith("https://jenkins.test/api/json?tree="));
    assert.equal(
        requests[0].headers.Authorization,
        "Basic " + Buffer.from("developer:mock-token-or-pass").toString("base64")
    );

    requests[0].reply(200, JSON.stringify({
        jobs: [
            {
                name: "api-service",
                color: "blue",
                lastBuild: {number: 12, result: "SUCCESS", building: false, duration: 10000}
            }
        ]
    }));

    assert.equal(context.status, "success");
    assert.equal(context.builds.length, 1);
    assert.equal(context.builds[0].name, "api-service");

    context.refresh();
    requests[1].reply(401, "Unauthorized");
    assert.equal(context.status, "unknown");
    assert.equal(context.builds.length, 0);
    assert.ok(context.error.includes("401"));

    context.refresh();
    context.fail("Connection timed out.");
    requests[2].reply(200, JSON.stringify({jobs: [{name: "stale", color: "blue"}]}));
    assert.equal(context.status, "unknown");
    assert.ok(requests[2].aborted);
}

function testAnonymousRequests() {
    const {context, requests} = createSourceHarness({
        type: "anonymous",
        url: "https://jenkins.public.test"
    });

    context.refresh();
    assert.equal(requests[0].headers.Authorization, undefined);
    requests[0].reply(200, JSON.stringify({
        jobs: [
            {name: "build-1", color: "red", lastBuild: {number: 1, result: "FAILURE"}}
        ]
    }));
    assert.equal(context.status, "failure");
    assert.equal(context.builds.length, 1);
}

function testWalletFailure() {
    const {context, requests} = createSourceHarness({
        type: "token",
        url: "https://jenkins.test",
        username: "dev"
    });
    context.wallet.access = (key, password, writing, onComplete) => {
        onComplete("Wallet locked", "");
    };

    context.refresh();
    assert.equal(requests.length, 0);
    assert.equal(context.error, "Wallet locked");
}

testAuthenticatedRequests();
testAnonymousRequests();
testWalletFailure();
console.log("Jenkins HTTP requests, authentication, error handling, timeout and stale response checks passed");
