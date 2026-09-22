// Data transformations shared by the QML components and Node.js tests.
function endpoint(entry) {
    const configuredUrl = String(entry.url || "").trim();
    const urlMatch = /^(https?):\/\/([^/?#]+)(\/[^?#]*)?\/?$/i.exec(configuredUrl);

    if (!urlMatch || /[@\s\\]/.test(configuredUrl)) {
        throw new Error("Enter an HTTP(S) URL without credentials, query or fragment.");
    }

    const origin = urlMatch[1].toLowerCase() + "://" + urlMatch[2];
    let basePath = (urlMatch[3] || "").replace(/\/+$/, "");
    let pageSlug = String(entry.slug || "").trim();

    if (entry.type === "public") {
        const statusPageMatch = /^(.*)\/status(?:\/([^/]+))?$/.exec(basePath);

        if (statusPageMatch) {
            basePath = statusPageMatch[1];
            pageSlug = pageSlug || decodeURIComponent(statusPageMatch[2] || "default");
        } else if (basePath === "/status-page") {
            basePath = "";
            pageSlug = pageSlug || "default";
        }

        if (!pageSlug) {
            throw new Error("Supply the status-page slug for a custom-domain URL.");
        }
    } else if (entry.type === "admin" || entry.type === "password") {
        basePath = basePath.replace(/\/dashboard(?:\/.*)?$/, "");
        basePath = basePath.replace(/\/metrics$/, "");

        if (entry.type === "password" && !String(entry.username || "").trim()) {
            throw new Error("Enter the administration username.");
        }
    } else {
        throw new Error("Choose public status page or administration dashboard.");
    }

    return {
        base: origin + basePath,
        slug: encodeURIComponent(pageSlug)
    };
}

function walletKey(entry) {
    const accountName = entry.type === "password" ? entry.username : "api-key";
    const serverUrl = endpoint(entry).base;

    return entry.type + ":" + encodeURIComponent(serverUrl) + ":" + encodeURIComponent(accountName);
}

function state(heartbeat) {
    if (!heartbeat) {
        return "unknown";
    }

    switch (heartbeat.status) {
    case 0:
        return "down";
    case 1:
        return "up";
    case 2:
        return "pending";
    case 3:
        return "maintenance";
    default:
        return "unknown";
    }
}

function aggregate(states) {
    const reportingStates = states.filter(function(monitorState) {
        return monitorState !== "no-data";
    });

    if (reportingStates.length === 0) {
        return "unknown";
    }

    const statusPriority = ["down", "unknown", "pending", "maintenance"];
    for (const priorityState of statusPriority) {
        if (reportingStates.indexOf(priorityState) >= 0) {
            return priorityState;
        }
    }

    const allMonitorsPaused = reportingStates.every(function(monitorState) {
        return monitorState === "paused";
    });
    return allMonitorsPaused ? "paused" : "up";
}

function latest(heartbeats) {
    if (!Array.isArray(heartbeats) || heartbeats.length === 0) {
        return null;
    }

    return heartbeats[heartbeats.length - 1];
}

function publicGroups(pageConfiguration, heartbeatData) {
    if (!pageConfiguration || !Array.isArray(pageConfiguration.publicGroupList)
            || !heartbeatData || !heartbeatData.heartbeatList
            || typeof heartbeatData.heartbeatList !== "object") {
        throw new Error("Invalid status-page response.");
    }

    // Preserve both arrays: using integer IDs as object keys would reorder monitors.
    return pageConfiguration.publicGroupList.map(function(group) {
        if (!group || !Array.isArray(group.monitorList)) {
            throw new Error("Invalid monitor group.");
        }

        const monitorRows = group.monitorList.map(function(monitor) {
            const heartbeats = heartbeatData.heartbeatList[monitor.id];
            const isPaused = monitor.active === false || monitor.active === 0;
            let monitorState = isPaused ? "paused" : state(latest(heartbeats));

            // Empty public history is neutral, not proof that a monitor is disabled.
            if (monitorState === "unknown" && Array.isArray(heartbeats) && heartbeats.length === 0) {
                monitorState = "no-data";
            }

            return {
                id: String(monitor.id),
                name: monitor.name || ("Monitor " + monitor.id),
                state: monitorState
            };
        });

        return {
            id: group.id,
            name: group.name || "Monitors",
            rows: monitorRows
        };
    });
}

function groupRows(groups) {
    return groups.reduce(function(combinedRows, group) {
        return combinedRows.concat(group.rows);
    }, []);
}

function publicRows(pageConfiguration, heartbeatData) {
    return groupRows(publicGroups(pageConfiguration, heartbeatData));
}

function metricsGroups(pageConfiguration, metricRows, heartbeatData) {
    const metricsByMonitorId = Object.create(null);
    metricRows.forEach(function(monitorRow) {
        metricsByMonitorId[monitorRow.id] = monitorRow;
    });

    // The page supplies membership and ordering; metrics supply health.
    const pageGroups = publicGroups(pageConfiguration, heartbeatData || {heartbeatList: {}});
    return pageGroups.map(function(group) {
        const monitorRows = group.rows.map(function(pageRow) {
            const metric = metricsByMonitorId[pageRow.id];
            let monitorState = "unknown";

            if (pageRow.state === "paused") {
                monitorState = "paused";
            } else if (metric) {
                monitorState = metric.state;
            } else if (pageRow.state === "no-data") {
                // Only an explicitly empty history makes a missing metric neutral.
                monitorState = "no-data";
            }

            return {
                id: pageRow.id,
                name: pageRow.name,
                state: monitorState
            };
        });

        return {
            id: group.id,
            name: group.name,
            rows: monitorRows
        };
    });
}

function parseMetricLabels(labelText) {
    const labels = {};
    let remainingLabels = labelText;

    while (remainingLabels.length > 0) {
        const labelMatch = /^\s*([a-zA-Z_][a-zA-Z0-9_]*)="((?:\\.|[^"\\])*)"\s*(,|$)/.exec(remainingLabels);
        if (!labelMatch) {
            throw new Error("Invalid metric labels.");
        }

        labels[labelMatch[1]] = labelMatch[2].replace(/\\(\\|"|n)/g, function(escapeSequence, escapedCharacter) {
            return escapedCharacter === "n" ? "\n" : escapedCharacter;
        });
        remainingLabels = remainingLabels.slice(labelMatch[0].length);
    }

    return labels;
}

function metricsRows(metricsText) {
    const monitorRows = [];
    const seenMonitorIds = {};

    String(metricsText).split(/\r?\n/).forEach(function(metricLine) {
        if (!/^monitor_status(?:\{|\s)/.test(metricLine)) {
            return;
        }

        const sampleMatch = /^monitor_status\{((?:[^"{}]|"(?:\\.|[^"\\])*")*)\}\s+(\S+)(?:\s+\d+)?\s*$/.exec(metricLine);
        if (!sampleMatch) {
            throw new Error("Invalid monitor status metric.");
        }

        const labels = parseMetricLabels(sampleMatch[1]);
        const monitorId = labels.monitor_id || labels.monitor_name;
        if (!monitorId || seenMonitorIds[monitorId]) {
            throw new Error("Missing or duplicate monitor identifier.");
        }

        seenMonitorIds[monitorId] = true;
        monitorRows.push({
            id: monitorId,
            name: labels.monitor_name || ("Monitor " + monitorId),
            state: state({status: Number(sampleMatch[2])})
        });
    });

    if (monitorRows.length === 0) {
        throw new Error("No monitor status metrics returned. Check the endpoint and active monitors.");
    }

    return monitorRows;
}
