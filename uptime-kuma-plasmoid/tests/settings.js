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

const dashboards = JSON.stringify([{
    type: "admin",
    url: "https://kuma.test",
    name: "Private",
    password: "secret",
    apiKey: "secret"
}]);
const savedSnapshot = settingsData.snapshot(dashboards, 123);
assert.ok(!savedSnapshot.includes("secret"));
assert.equal(settingsData.decode(savedSnapshot).pollInterval, 123);
assert.equal(JSON.parse(settingsData.decode(savedSnapshot).dashboards)[0].name, "Private");

const invalidSnapshots = [
    "",
    "{bad",
    '{"version":2}',
    '{"version":1,"dashboards":"{}","pollInterval":60}'
];
for (const invalidSnapshot of invalidSnapshots) {
    assert.equal(settingsData.decode(invalidSnapshot), null);
}
assert.throws(() => settingsData.snapshot("[null]", 60));
assert.throws(() => settingsData.snapshot("[]", 0));
assert.throws(() => settingsData.snapshot("[]", 10.5));

const mainSource = fs.readFileSync(path.join(__dirname, "../contents/ui/main.qml"), "utf8");
const lifecycleFunctions = mainSource.slice(
    mainSource.indexOf("    function persistSettings()"),
    mainSource.indexOf("    preferredRepresentation:")
);

function createSettingsHarness(configuration, recoverySnapshot) {
    let storedSnapshot = recoverySnapshot;
    let writeCount = 0;
    const context = {
        settingsReady: false,
        configError: "",
        backup: {
            read: () => settingsData.decode(storedSnapshot),
            save: (dashboardRows, pollInterval) => {
                storedSnapshot = settingsData.snapshot(dashboardRows, pollInterval);
            }
        },
        plasmoid: {
            configuration: Object.assign({
                dashboards: "[]",
                pollInterval: 60,
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
assert.equal(recoveryHarness.context.plasmoid.configuration.pollInterval, 123);
assert.equal(
    JSON.parse(recoveryHarness.context.plasmoid.configuration.dashboards)[0].name,
    "Private"
);
assert.ok(recoveryHarness.writeCount() > 0);

// Intentional removal must not resurrect previously saved dashboards.
const clearedHarness = createSettingsHarness({
    dashboards: "[]",
    settingsSaved: true
}, savedSnapshot);
clearedHarness.context.initializeSettings();
assert.equal(clearedHarness.context.plasmoid.configuration.dashboards, "[]");
assert.equal(settingsData.decode(clearedHarness.storedSnapshot()).dashboards, "[]");

// Existing Plasma settings take precedence over an older backup.
const migrationHarness = createSettingsHarness({
    dashboards: JSON.stringify([{
        name: "Current",
        type: "public",
        url: "https://status.test/status/main"
    }]),
    pollInterval: 90
}, savedSnapshot);
migrationHarness.context.initializeSettings();
assert.equal(
    JSON.parse(settingsData.decode(migrationHarness.storedSnapshot()).dashboards)[0].name,
    "Current"
);
assert.equal(settingsData.decode(migrationHarness.storedSnapshot()).pollInterval, 90);

migrationHarness.context.plasmoid.configuration.pollInterval = 180;
migrationHarness.context.persistSettings();
assert.equal(settingsData.decode(migrationHarness.storedSnapshot()).pollInterval, 180);

// Invalid settings must not overwrite the last valid recovery snapshot.
const snapshotBeforeInvalidEdit = migrationHarness.storedSnapshot();
migrationHarness.context.plasmoid.configuration.dashboards = "{broken";
migrationHarness.context.persistSettings();
assert.equal(migrationHarness.storedSnapshot(), snapshotBeforeInvalidEdit);
assert.ok(migrationHarness.context.configError);

console.log("Settings backup, recovery, migration and intentional deletion checks passed");
