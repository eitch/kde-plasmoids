const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const walletSource = fs.readFileSync(path.join(__dirname, "../contents/ui/Wallet.qml"), "utf8");
const walletFunctions = walletSource.slice(
    walletSource.indexOf("    function call"),
    walletSource.lastIndexOf("\n}")
);

function createWalletHarness(overrides) {
    const calls = [];
    const replies = Object.assign({
        networkWallet: "kdewallet",
        open: 0,
        hasFolder: true,
        createFolder: true,
        readPassword: "stored-secret",
        writePassword: 0,
        close: 0
    }, overrides);
    const context = {
        appId: "Uptime Kuma Plasmoid",
        folder: "UptimeKuma",
        PlasmaDBus: {
            SessionBus: {
                asyncCall: (request, onSuccess, onFailure) => {
                    calls.push(JSON.parse(JSON.stringify(request)));
                    const reply = replies[request.member];
                    if (reply instanceof Error) {
                        onFailure(reply);
                    } else {
                        onSuccess({value: {value: reply}});
                    }
                }
            }
        }
    };
    vm.createContext(context);
    vm.runInContext(walletFunctions, context);
    return {context, calls};
}

function accessWallet(overrides, writing) {
    const harness = createWalletHarness(overrides);
    const completions = [];
    harness.context.access("account-key", "new-secret", writing, (errorMessage, password) => {
        completions.push({errorMessage, password});
    });
    assert.equal(completions.length, 1);
    return {calls: harness.calls, result: completions[0]};
}

const readScenario = accessWallet({}, false);
assert.equal(readScenario.result.password, "stored-secret");
assert.equal(readScenario.result.errorMessage, "");
const readRequest = readScenario.calls.find(request => request.member === "readPassword");
assert.equal(readRequest.signature, "(isss)");
assert.deepEqual(readRequest.arguments, [0, "UptimeKuma", "account-key", "Uptime Kuma Plasmoid"]);
assert.equal(readScenario.calls[readScenario.calls.length - 1].member, "close");

const writeScenario = accessWallet({hasFolder: false}, true);
assert.equal(writeScenario.result.errorMessage, "");
assert.ok(writeScenario.calls.some(request => request.member === "createFolder"));
const writeRequest = writeScenario.calls.find(request => request.member === "writePassword");
assert.equal(writeRequest.signature, "(issss)");
assert.equal(writeRequest.arguments[3], "new-secret");

for (const overrides of [
    {hasFolder: false},
    {readPassword: ""},
    {readPassword: new Error("D-Bus failure")},
    {hasFolder: new Error("D-Bus failure")}
]) {
    const failureScenario = accessWallet(overrides, false);
    assert.ok(failureScenario.result.errorMessage);
    assert.equal(failureScenario.calls.filter(request => request.member === "close").length, 1);
}

for (const overrides of [
    {writePassword: 1},
    {hasFolder: false, createFolder: false},
    {hasFolder: false, createFolder: new Error("D-Bus failure")}
]) {
    const failureScenario = accessWallet(overrides, true);
    assert.ok(failureScenario.result.errorMessage);
    assert.equal(failureScenario.calls.filter(request => request.member === "close").length, 1);
}

for (const overrides of [{open: -1}, {open: new Error("Denied")}, {networkWallet: new Error("Unavailable")}]) {
    const deniedScenario = accessWallet(overrides, false);
    assert.ok(deniedScenario.result.errorMessage);
    assert.ok(!deniedScenario.calls.some(request => request.member === "close"));
}

console.log("KWallet signatures, zero handles, read/write and failure cleanup checks passed");
