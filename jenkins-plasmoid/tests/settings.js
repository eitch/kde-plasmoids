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

const servers = JSON.stringify([{
    type: "token",
    url: "https://jenkins.test",
    name: "CI Server",
    username: "admin",
    token: "secret-token",
    password: "secret-password"
}]);

const savedSnapshot = settingsData.snapshot(servers, 120);
assert.ok(!savedSnapshot.includes("secret-token"));
assert.ok(!savedSnapshot.includes("secret-password"));
assert.equal(settingsData.decode(savedSnapshot).pollInterval, 120);
assert.equal(JSON.parse(settingsData.decode(savedSnapshot).servers)[0].name, "CI Server");

const invalidSnapshots = [
    "",
    "{bad",
    '{"version":2}',
    '{"version":1,"servers":"{}","pollInterval":60}'
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
            save: (serverRows, pollInterval) => {
                storedSnapshot = settingsData.snapshot(serverRows, pollInterval);
            }
        },
        plasmoid: {
            configuration: Object.assign({
                servers: "[]",
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
assert.equal(recoveryHarness.context.plasmoid.configuration.pollInterval, 120);
assert.equal(
    JSON.parse(recoveryHarness.context.plasmoid.configuration.servers)[0].name,
    "CI Server"
);
assert.ok(recoveryHarness.writeCount() > 0);

const clearedHarness = createSettingsHarness({
    servers: "[]",
    settingsSaved: true
}, savedSnapshot);
clearedHarness.context.initializeSettings();
assert.equal(clearedHarness.context.plasmoid.configuration.servers, "[]");
assert.equal(settingsData.decode(clearedHarness.storedSnapshot()).servers, "[]");

const migrationHarness = createSettingsHarness({
    servers: JSON.stringify([{
        name: "New Server",
        type: "anonymous",
        url: "https://jenkins-new.test"
    }]),
    pollInterval: 30
}, savedSnapshot);
migrationHarness.context.initializeSettings();
assert.equal(
    JSON.parse(settingsData.decode(migrationHarness.storedSnapshot()).servers)[0].name,
    "New Server"
);
assert.equal(settingsData.decode(migrationHarness.storedSnapshot()).pollInterval, 30);

console.log("Jenkins settings backup, recovery, migration and intentional deletion checks passed");
