// Keep credentials out of the independent, per-widget recovery file.
function snapshot(dashboards, pollInterval) {
    const entries = JSON.parse(dashboards);
    if (!Array.isArray(entries)) {
        throw new Error("Invalid dashboard settings");
    }

    const savedEntries = entries.map(function(entry) {
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
            throw new Error("Invalid dashboard entry");
        }

        const savedEntry = {};
        const allowedFields = ["name", "type", "url", "slug", "username"];
        allowedFields.forEach(function(fieldName) {
            if (entry[fieldName] !== undefined && typeof entry[fieldName] !== "string") {
                throw new Error("Invalid dashboard field");
            }
            savedEntry[fieldName] = entry[fieldName] || "";
        });
        return savedEntry;
    });

    if (!Number.isInteger(pollInterval) || pollInterval < 10 || pollInterval > 3600) {
        throw new Error("Invalid refresh interval");
    }

    return JSON.stringify({
        version: 1,
        dashboards: JSON.stringify(savedEntries),
        pollInterval: pollInterval
    });
}

function decode(serializedSnapshot) {
    try {
        const savedSettings = JSON.parse(serializedSnapshot);
        if (savedSettings.version !== 1) {
            return null;
        }

        return JSON.parse(snapshot(savedSettings.dashboards, savedSettings.pollInterval));
    } catch (error) {
        return null;
    }
}
