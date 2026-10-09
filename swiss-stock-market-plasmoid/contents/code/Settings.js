// Keep credentials out of the independent, per-widget recovery file.

function snapshot(watchlist, pollInterval, brokerProvider, brokerEndpoint, authType, displaySymbol) {
    var items = typeof watchlist === "string" ? JSON.parse(watchlist) : watchlist;
    if (!Array.isArray(items)) {
        throw new Error("Invalid watchlist settings");
    }

    var savedItems = items.map(function(item) {
        if (!item || typeof item !== "object" || Array.isArray(item)) {
            throw new Error("Invalid watchlist item");
        }

        var savedItem = {};
        var allowedFields = ["symbol", "name", "market", "currency", "isin", "category", "enabled"];
        allowedFields.forEach(function(fieldName) {
            if (fieldName === "enabled") {
                savedItem[fieldName] = item[fieldName] !== false;
            } else if (item[fieldName] !== undefined) {
                if (typeof item[fieldName] !== "string") {
                    throw new Error("Invalid watchlist field: " + fieldName);
                }
                savedItem[fieldName] = item[fieldName] || "";
            } else {
                savedItem[fieldName] = "";
            }
        });
        return savedItem;
    });

    if (!Number.isInteger(pollInterval) || pollInterval < 10 || pollInterval > 3600) {
        throw new Error("Invalid refresh interval");
    }

    return JSON.stringify({
        version: 1,
        watchlist: JSON.stringify(savedItems),
        pollInterval: pollInterval,
        brokerProvider: typeof brokerProvider === "string" ? brokerProvider : "yahoo",
        brokerEndpoint: typeof brokerEndpoint === "string" ? brokerEndpoint : "",
        authType: typeof authType === "string" ? authType : "none",
        displaySymbol: typeof displaySymbol === "string" ? displaySymbol : "SMI"
    });
}

function decode(serializedSnapshot) {
    try {
        var savedSettings = JSON.parse(serializedSnapshot);
        if (savedSettings.version !== 1) {
            return null;
        }

        var verified = JSON.parse(snapshot(
            savedSettings.watchlist,
            savedSettings.pollInterval,
            savedSettings.brokerProvider,
            savedSettings.brokerEndpoint,
            savedSettings.authType,
            savedSettings.displaySymbol
        ));

        return verified;
    } catch (error) {
        return null;
    }
}
