const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const settingsData = {};
vm.createContext(settingsData);
vm.runInContext(
    fs.readFileSync(path.join(__dirname, "../contents/code/Settings.js"), "utf8"),
    settingsData
);

const watchlist = JSON.stringify([{
    symbol: "SQN",
    name: "Swissquote Group",
    market: "SIX",
    currency: "CHF",
    enabled: true,
    token: "secret-token",
    apiKey: "secret-key"
}]);

const savedSnapshot = settingsData.snapshot(
    watchlist,
    120,
    "yahoo",
    "https://query1.finance.yahoo.com/v8/finance/chart/",
    "none",
    "SQN",
    "brave"
);

assert.ok(!savedSnapshot.includes("secret-token"));
assert.ok(!savedSnapshot.includes("secret-key"));

const decoded = settingsData.decode(savedSnapshot);
assert.equal(decoded.pollInterval, 120);
assert.equal(decoded.brokerProvider, "yahoo");
assert.equal(decoded.displaySymbol, "SQN");
assert.equal(decoded.browser, "brave");
assert.equal(JSON.parse(decoded.watchlist)[0].symbol, "SQN");

const invalidSnapshots = [
    "",
    "{broken",
    '{"version":2}',
    '{"version":1,"watchlist":"{}","pollInterval":60}'
];
for (const invalidSnapshot of invalidSnapshots) {
    assert.equal(settingsData.decode(invalidSnapshot), null);
}

assert.throws(() => settingsData.snapshot("[null]", 60, "yahoo", "", "none", "SMI"));
assert.throws(() => settingsData.snapshot("[]", 0, "yahoo", "", "none", "SMI"));
assert.throws(() => settingsData.snapshot("[]", 15.5, "yahoo", "", "none", "SMI"));

const mainSource = fs.readFileSync(path.join(__dirname, "../contents/ui/main.qml"), "utf8");
const lifecycleFunctions = mainSource.slice(
    mainSource.indexOf("    function persistSettings()"),
    mainSource.indexOf("    preferredRepresentation:")
);

function createSettingsHarness(configuration, recoverySnapshot) {
    let storedSnapshot = recoverySnapshot;
    let writeCount = 0;
    const market = {};
    vm.createContext(market);
    vm.runInContext(
        fs.readFileSync(path.join(__dirname, "../contents/code/Market.js"), "utf8"),
        market
    );

    const context = {
        Market: market,
        marketSource: {
            watchlist: [],
            brokerConfig: {},
            pollInterval: 60,
            refresh: () => {}
        },
        settingsReady: false,
        configError: "",
        backup: {
            read: () => settingsData.decode(storedSnapshot),
            save: (items, pollInterval, provider, endpoint, auth, displaySym, browser) => {
                storedSnapshot = settingsData.snapshot(items, pollInterval, provider, endpoint, auth, displaySym, browser);
            }
        },
        plasmoid: {
            configuration: Object.assign({
                watchlist: "[]",
                pollInterval: 60,
                brokerProvider: "yahoo",
                brokerEndpoint: "https://query1.finance.yahoo.com/v8/finance/chart/",
                authType: "none",
                displaySymbol: "SMI",
                browser: "",
                settingsSaved: false,
                writeConfig: () => {
                    ++writeCount;
                }
            }, configuration)
        },
        reload: () => {}
    };

    vm.createContext(context);
    vm.runInContext(lifecycleFunctions, context);
    return {
        context,
        storedSnapshot: () => storedSnapshot,
        writeCount: () => writeCount
    };
}

const recoveryHarness = createSettingsHarness({}, savedSnapshot);
recoveryHarness.context.initializeSettings();
assert.equal(recoveryHarness.context.plasmoid.configuration.pollInterval, 120);
assert.equal(recoveryHarness.context.plasmoid.configuration.browser, "brave");
assert.equal(
    JSON.parse(recoveryHarness.context.plasmoid.configuration.watchlist)[0].symbol,
    "SQN"
);
assert.ok(recoveryHarness.writeCount() > 0);

// Intentional removal must not resurrect previously saved watchlist.
const clearedHarness = createSettingsHarness({
    watchlist: "[]",
    settingsSaved: true
}, savedSnapshot);
clearedHarness.context.initializeSettings();
assert.equal(clearedHarness.context.plasmoid.configuration.watchlist, "[]");
assert.equal(settingsData.decode(clearedHarness.storedSnapshot()).watchlist, "[]");

// Existing Plasma settings take precedence over an older backup.
const migrationHarness = createSettingsHarness({
    watchlist: JSON.stringify([{
        symbol: "NESN",
        name: "Nestlé SA",
        market: "SIX",
        currency: "CHF",
        enabled: true
    }]),
    pollInterval: 90,
    brokerProvider: "six",
    displaySymbol: "NESN",
    browser: "firefox"
}, savedSnapshot);
migrationHarness.context.initializeSettings();
assert.equal(
    JSON.parse(settingsData.decode(migrationHarness.storedSnapshot()).watchlist)[0].symbol,
    "NESN"
);
assert.equal(settingsData.decode(migrationHarness.storedSnapshot()).pollInterval, 90);
assert.equal(settingsData.decode(migrationHarness.storedSnapshot()).brokerProvider, "six");
assert.equal(settingsData.decode(migrationHarness.storedSnapshot()).browser, "firefox");

migrationHarness.context.plasmoid.configuration.pollInterval = 180;
migrationHarness.context.persistSettings();
assert.equal(settingsData.decode(migrationHarness.storedSnapshot()).pollInterval, 180);

// Invalid settings must not overwrite the last valid recovery snapshot.
const snapshotBeforeInvalidEdit = migrationHarness.storedSnapshot();
migrationHarness.context.plasmoid.configuration.watchlist = "{broken";
migrationHarness.context.persistSettings();
assert.equal(migrationHarness.storedSnapshot(), snapshotBeforeInvalidEdit);
assert.ok(migrationHarness.context.configError);

console.log("Swiss stock market settings backup, recovery, migration and validation checks passed");
