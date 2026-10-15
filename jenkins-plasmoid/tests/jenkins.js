const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const jenkins = {};
vm.createContext(jenkins);
vm.runInContext(
    fs.readFileSync(path.join(__dirname, "../contents/code/Jenkins.js"), "utf8"),
    jenkins
);

function testEndpoints() {
    assert.equal(
        jenkins.endpoint({url: "https://jenkins.example.com/"}).base,
        "https://jenkins.example.com"
    );
    assert.equal(
        jenkins.endpoint({url: "http://ci.local:8080/view/Frontend/"}).base,
        "http://ci.local:8080/view/Frontend"
    );
    assert.equal(
        jenkins.endpoint({url: "https://ci.example.com/job/my-project/api/json"}).base,
        "https://ci.example.com/job/my-project"
    );

    const invalidUrls = [
        "",
        "file:///local/path",
        "https://user:pass@jenkins.test",
        "https://jenkins.test?param=val",
        "https://jenkins.test#fragment",
        "https://jenkins.test\\evil"
    ];
    for (const url of invalidUrls) {
        assert.throws(() => jenkins.endpoint({url}));
    }

    assert.equal(
        jenkins.apiUrl("https://jenkins.example.com"),
        "https://jenkins.example.com/api/json?tree=" + encodeURIComponent("jobs[name,displayName,url,color,lastBuild[number,url,result,timestamp,building,duration,estimatedDuration,displayName,fullDisplayName],healthReport[description,score]],name,displayName,url,color,lastBuild[number,url,result,timestamp,building,duration,estimatedDuration,displayName,fullDisplayName],healthReport[description,score]")
    );

    assert.equal(
        jenkins.walletKey({url: "https://jenkins.example.com", type: "token", username: "admin"}),
        "jenkins:token:https%3A%2F%2Fjenkins.example.com:admin"
    );
    assert.notEqual(
        jenkins.walletKey({url: "https://a.test", type: "token", username: "u1"}),
        jenkins.walletKey({url: "https://b.test", type: "token", username: "u1"})
    );
}

function testColorAndResultParsing() {
    assert.equal(jenkins.parseColor("blue"), "success");
    assert.equal(jenkins.parseColor("red"), "failure");
    assert.equal(jenkins.parseColor("yellow"), "unstable");
    assert.equal(jenkins.parseColor("aborted"), "aborted");
    assert.equal(jenkins.parseColor("disabled"), "aborted");
    assert.equal(jenkins.parseColor("grey"), "aborted");
    assert.equal(jenkins.parseColor("notbuilt"), "aborted");
    assert.equal(jenkins.parseColor("blue_anime"), "building");
    assert.equal(jenkins.parseColor("red_anime"), "building");
    assert.equal(jenkins.parseColor("yellow_anime"), "building");
    assert.equal(jenkins.parseColor("unknown_color"), "unknown");
    assert.equal(jenkins.parseColor(null), "unknown");

    assert.equal(jenkins.parseResult("SUCCESS", false), "success");
    assert.equal(jenkins.parseResult("FAILURE", false), "failure");
    assert.equal(jenkins.parseResult("UNSTABLE", false), "unstable");
    assert.equal(jenkins.parseResult("ABORTED", false), "aborted");
    assert.equal(jenkins.parseResult("NOT_BUILT", false), "aborted");
    assert.equal(jenkins.parseResult("SUCCESS", true), "building");
    assert.equal(jenkins.parseResult("ANYTHING", true), "building");
    assert.equal(jenkins.parseResult(null, false), "unknown");
}

function testBuildState() {
    assert.equal(jenkins.parseBuildState({lastBuild: {result: "SUCCESS", building: false}}), "success");
    assert.equal(jenkins.parseBuildState({lastBuild: {result: "FAILURE", building: false}}), "failure");
    assert.equal(jenkins.parseBuildState({lastBuild: {result: "UNSTABLE", building: false}}), "unstable");
    assert.equal(jenkins.parseBuildState({lastBuild: {building: true}}), "building");
    assert.equal(jenkins.parseBuildState({color: "blue_anime"}), "building");
    assert.equal(jenkins.parseBuildState({color: "red"}), "failure");
    assert.equal(jenkins.parseBuildState({color: "blue"}), "success");
    assert.equal(jenkins.parseBuildState({}), "unknown");
    assert.equal(jenkins.parseBuildState(null), "unknown");
}

function testAggregation() {
    assert.equal(jenkins.aggregate([]), "unknown");
    assert.equal(jenkins.aggregate(["success", "success"]), "success");
    assert.equal(jenkins.aggregate(["success", "failure"]), "failure");
    assert.equal(jenkins.aggregate(["success", "unstable"]), "unstable");
    assert.equal(jenkins.aggregate(["unstable", "failure"]), "failure");
    assert.equal(jenkins.aggregate(["success", "building"]), "building");
    assert.equal(jenkins.aggregate(["building", "failure"]), "failure");
    assert.equal(jenkins.aggregate(["success", "aborted"]), "success");
    assert.equal(jenkins.aggregate(["aborted", "aborted"]), "aborted");
    assert.equal(jenkins.aggregate(["success", "unknown"]), "unknown");
}

function testFormatting() {
    assert.equal(jenkins.formatDuration(0), "");
    assert.equal(jenkins.formatDuration(5000), "5s");
    assert.equal(jenkins.formatDuration(65000), "1m 5s");
    assert.equal(jenkins.formatDuration(120000), "2m");
    assert.equal(jenkins.formatDuration(3665000), "1h 1m");
    assert.equal(jenkins.formatDuration(7200000), "2h");

    assert.equal(jenkins.formatRelativeTime(Date.now() - 2000), "just now");
    assert.equal(jenkins.formatRelativeTime(Date.now() - 30000), "30s ago");
    assert.equal(jenkins.formatRelativeTime(Date.now() - 180000), "3m ago");
    assert.equal(jenkins.formatRelativeTime(Date.now() - 7200000), "2h ago");
    assert.equal(jenkins.formatRelativeTime(Date.now() - 86400000 * 3), "3d ago");
    assert.equal(jenkins.formatRelativeTime(null), "");
}

function testParseJobs() {
    const apiPayload = {
        jobs: [
            {
                name: "frontend-app",
                displayName: "Frontend App",
                url: "https://jenkins.test/job/frontend-app/",
                color: "blue",
                lastBuild: {
                    number: 42,
                    url: "https://jenkins.test/job/frontend-app/42/",
                    result: "SUCCESS",
                    timestamp: 1600000000000,
                    building: false,
                    duration: 45000
                },
                healthReport: [
                    {description: "Build stability: No recent builds failed."}
                ]
            },
            {
                name: "backend-api",
                url: "https://jenkins.test/job/backend-api/",
                color: "red_anime",
                lastBuild: {
                    number: 108,
                    url: "https://jenkins.test/job/backend-api/108/",
                    result: null,
                    timestamp: 1600000000000,
                    building: true,
                    duration: 120000
                }
            }
        ]
    };

    const parsed = jenkins.parseJobs(apiPayload, "https://jenkins.test");
    assert.equal(parsed.length, 2);
    assert.equal(parsed[0].name, "Frontend App");
    assert.equal(parsed[0].buildUrl, "https://jenkins.test/job/frontend-app/42/");
    assert.equal(parsed[0].buildNumber, "#42");
    assert.equal(parsed[0].state, "success");
    assert.equal(parsed[0].building, false);
    assert.equal(parsed[0].duration, "45s");
    assert.equal(parsed[0].health, "Build stability: No recent builds failed.");

    assert.equal(parsed[1].name, "backend-api");
    assert.equal(parsed[1].buildUrl, "https://jenkins.test/job/backend-api/108/");
    assert.equal(parsed[1].buildNumber, "#108");
    assert.equal(parsed[1].state, "building");
    assert.equal(parsed[1].building, true);

    const singleJobPayload = {
        name: "single-job",
        url: "https://jenkins.test/job/single-job/",
        color: "yellow",
        lastBuild: {
            number: 7,
            url: "https://jenkins.test/job/single-job/7/",
            result: "UNSTABLE",
            building: false,
            duration: 15000
        }
    };
    const singleParsed = jenkins.parseJobs(singleJobPayload, "https://jenkins.test");
    assert.equal(singleParsed.length, 1);
    assert.equal(singleParsed[0].name, "single-job");
    assert.equal(singleParsed[0].state, "unstable");

    assert.throws(() => jenkins.parseJobs(null));
    assert.throws(() => jenkins.parseJobs("string"));
}

function testBase64() {
    assert.equal(jenkins.base64Encode("hello:world"), "aGVsbG86d29ybGQ=");
    assert.equal(jenkins.base64Encode("admin:password"), "YWRtaW46cGFzc3dvcmQ=");
    assert.equal(jenkins.base64Encode("user:pässwörd"), Buffer.from("user:pässwörd", "utf8").toString("base64"));
    assert.equal(jenkins.base64Encode(""), "");
}

testEndpoints();
testColorAndResultParsing();
testBuildState();
testAggregation();
testFormatting();
testParseJobs();
testBase64();
console.log("Jenkins endpoint, color parsing, build state, aggregation, formatting and job parsing checks passed");
