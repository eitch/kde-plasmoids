// Data transformations and helper functions for Jenkins build status.

function endpoint(entry) {
    const configuredUrl = String(entry.url || "").trim();
    const urlMatch = /^(https?):\/\/([^/?#]+)(\/[^?#]*)?\/?$/i.exec(configuredUrl);

    if (!urlMatch || /[@\s\\]/.test(configuredUrl)) {
        throw new Error("Enter an HTTP(S) URL without credentials, query or fragment.");
    }

    const origin = urlMatch[1].toLowerCase() + "://" + urlMatch[2];
    let basePath = (urlMatch[3] || "").replace(/\/+$/, "");
    basePath = basePath.replace(/\/api(?:\/json)?\/?$/, "");

    return {
        base: origin + basePath
    };
}

function walletKey(entry) {
    const serverUrl = endpoint(entry).base;
    const authType = entry.type || "token";
    const accountName = entry.username || (authType === "token" ? "api-token" : "anonymous");

    return "jenkins:" + authType + ":" + encodeURIComponent(serverUrl) + ":" + encodeURIComponent(accountName);
}

function parseColor(color) {
    if (!color || typeof color !== "string") {
        return "unknown";
    }

    if (color.endsWith("_anime")) {
        return "building";
    }

    switch (color) {
    case "blue":
        return "success";
    case "red":
        return "failure";
    case "yellow":
        return "unstable";
    case "grey":
    case "gray":
    case "disabled":
    case "aborted":
    case "notbuilt":
    case "nobuilt":
        return "aborted";
    default:
        return "unknown";
    }
}

function parseResult(result, isBuilding) {
    if (isBuilding) {
        return "building";
    }

    if (!result || typeof result !== "string") {
        return "unknown";
    }

    switch (result.toUpperCase()) {
    case "SUCCESS":
        return "success";
    case "FAILURE":
        return "failure";
    case "UNSTABLE":
        return "unstable";
    case "ABORTED":
    case "NOT_BUILT":
        return "aborted";
    default:
        return "unknown";
    }
}

function parseBuildState(job) {
    if (!job || typeof job !== "object") {
        return "unknown";
    }

    if (job.lastBuild) {
        if (job.lastBuild.building) {
            return "building";
        }
        if (job.lastBuild.result) {
            const resultState = parseResult(job.lastBuild.result, false);
            if (resultState !== "unknown") {
                return resultState;
            }
        }
    }

    if (job.color) {
        return parseColor(job.color);
    }

    if (job.result) {
        return parseResult(job.result, Boolean(job.building));
    }

    return "unknown";
}

function aggregate(states) {
    if (!Array.isArray(states) || states.length === 0) {
        return "unknown";
    }

    const validStates = states.filter(function(st) {
        return st && st !== "no-data";
    });

    if (validStates.length === 0) {
        return "unknown";
    }

    if (validStates.indexOf("failure") >= 0) {
        return "failure";
    }
    if (validStates.indexOf("unstable") >= 0) {
        return "unstable";
    }
    if (validStates.indexOf("building") >= 0) {
        return "building";
    }
    if (validStates.indexOf("unknown") >= 0) {
        return "unknown";
    }

    const allAborted = validStates.every(function(st) {
        return st === "aborted";
    });
    if (allAborted) {
        return "aborted";
    }

    if (validStates.indexOf("success") >= 0) {
        return "success";
    }

    return "unknown";
}

function formatDuration(durationMs) {
    if (!durationMs || typeof durationMs !== "number" || durationMs <= 0) {
        return "";
    }

    const totalSeconds = Math.round(durationMs / 1000);
    if (totalSeconds < 60) {
        return totalSeconds + "s";
    }

    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    if (minutes < 60) {
        return seconds > 0 ? (minutes + "m " + seconds + "s") : (minutes + "m");
    }

    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? (hours + "h " + remainingMinutes + "m") : (hours + "h");
}

function formatRelativeTime(timestampMs) {
    if (!timestampMs || typeof timestampMs !== "number") {
        return "";
    }

    const diffMs = Date.now() - timestampMs;
    if (diffMs < 0) {
        return "just now";
    }

    const diffSeconds = Math.floor(diffMs / 1000);
    if (diffSeconds < 60) {
        return diffSeconds <= 5 ? "just now" : diffSeconds + "s ago";
    }

    const diffMinutes = Math.floor(diffSeconds / 60);
    if (diffMinutes < 60) {
        return diffMinutes + "m ago";
    }

    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24) {
        return diffHours + "h ago";
    }

    const diffDays = Math.floor(diffHours / 24);
    return diffDays + "d ago";
}

function apiUrl(serverUrl) {
    const ep = endpoint({url: serverUrl});
    const treeFields = [
        "jobs[name,displayName,url,color,lastBuild[number,url,result,timestamp,building,duration,estimatedDuration,displayName,fullDisplayName],healthReport[description,score]]",
        "name,displayName,url,color,lastBuild[number,url,result,timestamp,building,duration,estimatedDuration,displayName,fullDisplayName],healthReport[description,score]"
    ].join(",");

    return ep.base + "/api/json?tree=" + encodeURIComponent(treeFields);
}

function parseJob(rawJob, fallbackBaseUrl) {
    if (!rawJob || typeof rawJob !== "object") {
        return null;
    }

    const name = rawJob.displayName || rawJob.name || "Build";
    const jobUrl = rawJob.url || fallbackBaseUrl;
    const lastBuild = rawJob.lastBuild;

    let buildUrl = jobUrl;
    let buildNumber = "";
    let duration = "";
    let timestamp = null;
    let isBuilding = false;

    if (lastBuild && typeof lastBuild === "object") {
        if (lastBuild.url) {
            buildUrl = lastBuild.url;
        }
        if (lastBuild.number !== undefined) {
            buildNumber = "#" + lastBuild.number;
        }
        if (lastBuild.duration !== undefined) {
            duration = formatDuration(lastBuild.duration);
        }
        if (lastBuild.timestamp !== undefined) {
            timestamp = lastBuild.timestamp;
        }
        isBuilding = Boolean(lastBuild.building);
    } else if (rawJob.number !== undefined) {
        buildNumber = "#" + rawJob.number;
        if (rawJob.duration !== undefined) {
            duration = formatDuration(rawJob.duration);
        }
        if (rawJob.timestamp !== undefined) {
            timestamp = rawJob.timestamp;
        }
        if (rawJob.url) {
            buildUrl = rawJob.url;
        }
        isBuilding = Boolean(rawJob.building);
    }

    const state = parseBuildState(rawJob);
    if (state === "building") {
        isBuilding = true;
    }

    let health = "";
    if (Array.isArray(rawJob.healthReport) && rawJob.healthReport.length > 0 && rawJob.healthReport[0]) {
        health = rawJob.healthReport[0].description || "";
    }

    return {
        name: name,
        jobUrl: jobUrl,
        buildUrl: buildUrl,
        buildNumber: buildNumber,
        state: state,
        building: isBuilding,
        duration: duration,
        timestamp: timestamp,
        health: health
    };
}

function parseJobs(apiResponse, fallbackBaseUrl) {
    if (!apiResponse || typeof apiResponse !== "object") {
        throw new Error("Invalid Jenkins API response.");
    }

    const list = [];
    if (Array.isArray(apiResponse.jobs)) {
        for (let i = 0; i < apiResponse.jobs.length; i++) {
            const parsed = parseJob(apiResponse.jobs[i], fallbackBaseUrl);
            if (parsed) {
                list.push(parsed);
            }
        }
    } else if (apiResponse.name || apiResponse.lastBuild || apiResponse.color) {
        const parsed = parseJob(apiResponse, fallbackBaseUrl);
        if (parsed) {
            list.push(parsed);
        }
    }

    return list;
}
