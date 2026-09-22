const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const kuma = {};
vm.createContext(kuma);
vm.runInContext(
    fs.readFileSync(path.join(__dirname, "../contents/code/Kuma.js"), "utf8"),
    kuma
);

// Normalize objects from the VM before comparing their prototypes.
function toPlainObject(value) {
    return JSON.parse(JSON.stringify(value));
}

function rowStates(rows) {
    return toPlainObject(rows).map(monitorRow => monitorRow.state);
}

function testEndpoints() {
    assert.equal(kuma.endpoint({
        type: "public",
        url: "https://kuma.test/status/services/"
    }).slug, "services");
    assert.equal(kuma.endpoint({
        type: "public",
        url: "https://status.test",
        slug: "my page"
    }).slug, "my%20page");
    assert.equal(kuma.endpoint({
        type: "admin",
        url: "https://kuma.test/prefix/dashboard/7",
        username: "me"
    }).base, "https://kuma.test/prefix");

    const invalidUrls = [
        "file:///tmp/a",
        "https://user:pass@host/status/x",
        "https://host/status/x?secret=y",
        "https://host/#dashboard",
        "https://host\\@evil"
    ];
    for (const url of invalidUrls) {
        assert.throws(() => kuma.endpoint({type: "public", url}));
    }
    assert.throws(() => kuma.endpoint({type: "public", url: "https://status.test"}));
    assert.throws(() => kuma.endpoint({type: "password", url: "https://kuma.test"}));
    assert.equal(kuma.endpoint({
        type: "admin",
        url: "https://kuma.test/metrics"
    }).base, "https://kuma.test");
    assert.equal(kuma.endpoint({
        type: "admin",
        url: "https://kuma.test/dashboard",
        slug: "my page"
    }).slug, "my%20page");
    assert.notEqual(
        kuma.walletKey({type: "admin", url: "https://a.test", username: "me"}),
        kuma.walletKey({type: "admin", url: "https://b.test", username: "me"})
    );
}

function testAggregation() {
    const scenarios = [
        {states: [], expected: "unknown"},
        {states: ["up", "unknown"], expected: "unknown"},
        {states: ["unknown", "down"], expected: "down"},
        {states: ["up", "pending"], expected: "pending"},
        {states: ["up", "maintenance"], expected: "maintenance"},
        {states: ["paused", "paused"], expected: "paused"},
        {states: ["up", "paused"], expected: "up"},
        {states: ["no-data"], expected: "unknown"},
        {states: ["no-data", "down"], expected: "down"},
        {states: ["no-data", "unknown"], expected: "unknown"},
        {states: ["no-data", "maintenance"], expected: "maintenance"},
        {states: ["no-data", "pending"], expected: "pending"}
    ];
    for (const scenario of scenarios) {
        assert.equal(kuma.aggregate(scenario.states), scenario.expected);
    }
}

function testPublicRows() {
    const pageConfiguration = {
        publicGroupList: [{
            monitorList: [{id: 1, name: "Web"}, {id: 2, name: "Mail"}]
        }]
    };
    const missingHistoryRows = kuma.publicRows(pageConfiguration, {
        heartbeatList: {1: [{status: 0}, {status: 1}]}
    });
    assert.deepEqual(rowStates(missingHistoryRows), ["up", "unknown"]);
    assert.throws(() => kuma.publicRows({}, {}));

    const emptyHistoryRows = kuma.publicRows(pageConfiguration, {
        heartbeatList: {1: [{status: 1}], 2: []}
    });
    assert.deepEqual(rowStates(emptyHistoryRows), ["up", "no-data"]);
    assert.equal(kuma.aggregate(rowStates(emptyHistoryRows)), "up");

    assert.equal(kuma.publicRows(pageConfiguration, {
        heartbeatList: {1: [], 2: [{status: 99}]}
    })[1].state, "unknown");
    assert.equal(kuma.publicRows(pageConfiguration, {
        heartbeatList: {1: [], 2: {}}
    })[1].state, "unknown");
    assert.equal(kuma.publicRows({
        publicGroupList: [{monitorList: [{id: 1, active: false}]}]
    }, {heartbeatList: {1: []}})[0].state, "paused");
}

function testMetricsParsing() {
    const metricsText = [
        "# HELP monitor_status Status",
        'monitor_status{monitor_id="1",monitor_name="Web",monitor_url="https://x"} 1',
        'monitor_status{monitor_id="2",monitor_name="Mail"} 0',
        ""
    ].join("\n");
    assert.deepEqual(rowStates(kuma.metricsRows(metricsText)), ["up", "down"]);
    assert.equal(kuma.aggregate(rowStates(kuma.metricsRows(metricsText))), "down");
    assert.equal(kuma.metricsRows(
        'monitor_status{monitor_id="1",monitor_name="X"} 3'
    )[0].state, "maintenance");
    assert.equal(kuma.metricsRows(
        'monitor_status{monitor_id="1",monitor_name="X"} NaN'
    )[0].state, "unknown");
    assert.throws(() => kuma.metricsRows("<html>Login</html>"));
    assert.throws(() => kuma.metricsRows("monitor_status{bad} 1"));
    assert.throws(() => kuma.metricsRows(metricsText + metricsText));
    assert.equal(kuma.parseMetricLabels('monitor_name="Line\\nTwo\\\\Path\\\"Quote"').monitor_name,
        'Line\nTwo\\Path"Quote');
}

function testPublicGroupOrder() {
    const groups = kuma.publicGroups({
        publicGroupList: [
            {
                id: 9,
                name: "Services",
                monitorList: [
                    {id: 20, name: "Second ID first"},
                    {id: 2, name: "First ID second"}
                ]
            },
            {
                id: 1,
                name: "Infrastructure",
                monitorList: [{id: 20, name: "Shared monitor"}]
            },
            {id: 3, name: "Empty group", monitorList: []}
        ]
    }, {heartbeatList: {20: [{status: 1}], 2: []}});

    assert.deepEqual(toPlainObject(groups).map(group => group.name), [
        "Services", "Infrastructure", "Empty group"
    ]);
    assert.deepEqual(toPlainObject(groups[0].rows).map(monitorRow => monitorRow.id), ["20", "2"]);
    assert.equal(groups[1].rows[0].name, "Shared monitor");
    assert.equal(groups[2].rows.length, 0);
    assert.equal(kuma.aggregate(rowStates(kuma.groupRows(groups))), "up");
}

function testMetricsGroupSelection() {
    const selectedGroups = kuma.metricsGroups({
        publicGroupList: [{
            id: 4,
            name: "Selected",
            monitorList: [
                {id: 2, name: "Page alias"},
                {id: 1, name: "First"},
                {id: 3, name: "Missing"}
            ]
        }]
    }, [
        {id: "1", name: "Metric name", state: "up"},
        {id: "2", name: "Second", state: "down"},
        {id: "99", name: "Outside page", state: "down"}
    ]);

    const selectedRows = selectedGroups[0].rows;
    assert.deepEqual(toPlainObject(selectedRows).map(monitorRow => monitorRow.id), ["2", "1", "3"]);
    assert.equal(selectedRows[0].name, "Page alias");
    assert.deepEqual(rowStates(selectedRows), ["down", "up", "unknown"]);
    assert.throws(() => kuma.metricsGroups({}, []));
}

function testDisabledMetricsMonitor() {
    const pageConfiguration = {
        publicGroupList: [{
            name: "Social",
            monitorList: [{id: 9, name: "GSI Mastodon"}, {id: 10, name: "GSI Pixelfed"}]
        }]
    };
    const metricRows = [{id: "9", name: "GSI Mastodon", state: "up"}];
    const heartbeatData = {heartbeatList: {9: [{status: 1}], 10: []}};
    const groupedRows = kuma.groupRows(kuma.metricsGroups(pageConfiguration, metricRows, heartbeatData));

    assert.deepEqual(rowStates(groupedRows), ["up", "no-data"]);
    assert.equal(kuma.aggregate(rowStates(groupedRows)), "up");
    assert.equal(kuma.metricsGroups(pageConfiguration, metricRows, {
        heartbeatList: {10: [{status: 1}]}
    })[0].rows[1].state, "unknown");
    assert.equal(kuma.metricsGroups(
        pageConfiguration,
        metricRows.concat([{id: "10", state: "down"}]),
        heartbeatData
    )[0].rows[1].state, "down");

    const allEmptyGroups = kuma.metricsGroups(pageConfiguration, [], {
        heartbeatList: {9: [], 10: []}
    });
    assert.equal(allEmptyGroups[0].rows[0].state, "no-data");
    assert.equal(kuma.aggregate(rowStates(kuma.groupRows(allEmptyGroups))), "unknown");
}

testEndpoints();
testAggregation();
testPublicRows();
testMetricsParsing();
testPublicGroupOrder();
testMetricsGroupSelection();
testDisabledMetricsMonitor();
console.log("Kuma URL, aggregation, metrics, grouping and disabled-monitor checks passed");
