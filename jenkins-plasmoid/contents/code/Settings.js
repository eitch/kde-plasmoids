// Keep credentials out of the independent, per-widget recovery file.
function snapshot(servers, pollInterval) {
    const entries = JSON.parse(servers);
    if (!Array.isArray(entries)) {
        throw new Error("Invalid server settings");
    }

    const savedEntries = entries.map(function(entry) {
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
            throw new Error("Invalid server entry");
        }

        const savedEntry = {};
        const allowedFields = ["name", "type", "url", "username"];
        allowedFields.forEach(function(fieldName) {
            if (entry[fieldName] !== undefined && typeof entry[fieldName] !== "string") {
                throw new Error("Invalid server field");
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
        servers: JSON.stringify(savedEntries),
        pollInterval: pollInterval
    });
}

function decode(serializedSnapshot) {
    try {
        const savedSettings = JSON.parse(serializedSnapshot);
        if (savedSettings.version !== 1) {
            return null;
        }

        return JSON.parse(snapshot(savedSettings.servers, savedSettings.pollInterval));
    } catch (error) {
        return null;
    }
}
