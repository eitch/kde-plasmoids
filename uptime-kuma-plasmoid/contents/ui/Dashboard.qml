import QtQuick
import "../code/Kuma.js" as Kuma

Item {
    id: source

    required property var entry
    property int pollInterval: 60
    property var rows: []
    property var groups: []
    property string error: "Connecting…"
    property string status: "unknown"
    property string updated: ""
    property var requests: []
    property int generation: 0
    property bool busy: false
    property double deadline: 0

    signal changed()

    Wallet {
        id: wallet
    }

    function publish(monitorRows, monitorGroups) {
        rows = monitorRows
        groups = monitorGroups || [{name: "", rows: monitorRows}]
        error = ""
        status = Kuma.aggregate(rows.map(function(monitorRow) {
            return monitorRow.state
        }))
        updated = Qt.formatDateTime(new Date(), "hh:mm:ss")
        busy = false
        changed()
    }

    function fail(errorMessage) {
        ++generation
        busy = false
        error = errorMessage
        rows = []
        groups = []
        status = "unknown"

        const pendingRequests = requests
        requests = []
        pendingRequests.forEach(function(request) {
            request.abort()
        })
        changed()
    }

    function get(requestUrl, requestGeneration, onSuccess, credential) {
        const request = new XMLHttpRequest()
        requests.push(request)

        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || requestGeneration !== generation) {
                return
            }
            if (request.status < 200 || request.status >= 300) {
                fail("Status request failed (HTTP " + request.status + ").")
                return
            }

            try {
                const response = credential !== undefined
                    ? request.responseText
                    : JSON.parse(request.responseText)
                onSuccess(response)
            } catch (error) {
                fail(error.message || "Invalid status response.")
            }
        }

        try {
            request.open("GET", requestUrl)
            request.setRequestHeader("Accept", credential !== undefined ? "text/plain" : "application/json")
            if (credential !== undefined) {
                const username = entry.type === "password" ? entry.username : ""
                request.setRequestHeader("Authorization", "Basic " + Qt.btoa(username + ":" + credential))
            }
            request.send()
        } catch (error) {
            fail("Could not send the status request.")
        }
    }

    function refreshPublicPage(endpoint, requestGeneration) {
        requests = []
        get(endpoint.base + "/api/status-page/" + endpoint.slug, requestGeneration, function(pageConfiguration) {
            get(endpoint.base + "/api/status-page/heartbeat/" + endpoint.slug, requestGeneration, function(heartbeatData) {
                const monitorGroups = Kuma.publicGroups(pageConfiguration, heartbeatData)
                publish(Kuma.groupRows(monitorGroups), monitorGroups)
                requests = []
            })
        })
    }

    function refreshMetricsGroups(endpoint, requestGeneration, metricRows) {
        get(endpoint.base + "/api/status-page/" + endpoint.slug, requestGeneration, function(pageConfiguration) {
            get(endpoint.base + "/api/status-page/heartbeat/" + endpoint.slug, requestGeneration, function(heartbeatData) {
                const monitorGroups = Kuma.metricsGroups(pageConfiguration, metricRows, heartbeatData)
                publish(Kuma.groupRows(monitorGroups), monitorGroups)
                requests = []
            })
        })
    }

    function refreshPrivateDashboard(endpoint, requestGeneration) {
        wallet.access(Kuma.walletKey(entry), "", false, function(errorMessage, credential) {
            if (requestGeneration !== generation) {
                return
            }
            if (errorMessage) {
                fail(errorMessage)
                return
            }

            requests = []
            get(endpoint.base + "/metrics", requestGeneration, function(metricsText) {
                const metricRows = Kuma.metricsRows(metricsText)
                if (endpoint.slug) {
                    refreshMetricsGroups(endpoint, requestGeneration, metricRows)
                } else {
                    publish(metricRows)
                    requests = []
                }
            }, credential)
        })
    }

    function refresh() {
        if (busy) {
            return
        }

        let endpoint
        try {
            endpoint = Kuma.endpoint(entry)
        } catch (error) {
            fail(error.message)
            return
        }

        const requestGeneration = ++generation
        busy = true
        deadline = Date.now() + 30000

        if (entry.type === "public") {
            refreshPublicPage(endpoint, requestGeneration)
        } else {
            refreshPrivateDashboard(endpoint, requestGeneration)
        }
    }

    Timer {
        interval: Math.max(10, source.pollInterval) * 1000
        running: true
        repeat: true
        onTriggered: source.refresh()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (source.busy && Date.now() > source.deadline) {
                source.fail("Connection timed out.")
            }
        }
    }

    Component.onCompleted: refresh()

    Component.onDestruction: {
        ++generation
        requests.forEach(function(request) {
            request.abort()
        })
    }
}
