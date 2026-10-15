import QtQuick
import "../code/Jenkins.js" as Jenkins

Item {
    id: source

    required property var entry
    property int pollInterval: 60
    property var builds: []
    property string error: "Connecting…"
    property string status: "unknown"
    property string updated: ""
    property var requests: []
    property int generation: 0
    property bool busy: false
    property double deadline: 0

    property var wallet: null

    signal changed()

    function publish(parsedBuilds) {
        builds = parsedBuilds || []
        error = ""
        status = Jenkins.aggregate(builds.map(function(buildItem) {
            return buildItem.state
        }))
        updated = Qt.formatDateTime(new Date(), "hh:mm:ss")
        busy = false
        changed()
    }

    function fail(errorMessage) {
        ++generation
        busy = false
        error = errorMessage
        builds = []
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
            try {
                const currentGen = typeof source !== "undefined" && source ? source.generation : generation
                if (request.readyState !== XMLHttpRequest.DONE || requestGeneration !== currentGen) {
                    return
                }
                if (request.status < 200 || request.status >= 300) {
                    if (typeof source !== "undefined" && source) {
                        source.fail("Jenkins request failed (HTTP " + request.status + ").")
                    } else {
                        fail("Jenkins request failed (HTTP " + request.status + ").")
                    }
                    return
                }

                const response = JSON.parse(request.responseText)
                onSuccess(response)
            } catch (error) {
                try {
                    if (typeof source !== "undefined" && source) {
                        source.fail(error.message || "Invalid Jenkins API response.")
                    } else {
                        fail(error.message || "Invalid Jenkins API response.")
                    }
                } catch (ignored) {
                }
            }
        }

        try {
            request.open("GET", requestUrl)
            request.setRequestHeader("Accept", "application/json")
            if (credential !== undefined && credential !== "") {
                const user = entry.username || ""
                request.setRequestHeader("Authorization", "Basic " + Jenkins.base64Encode(user + ":" + credential))
            }
            request.send()
        } catch (error) {
            fail("Could not send the Jenkins request.")
        }
    }

    function executeRefresh(requestUrl, requestGeneration, credential) {
        requests = []
        get(requestUrl, requestGeneration, function(apiResponse) {
            try {
                const parsedBuilds = Jenkins.parseJobs(apiResponse, entry.url)
                publish(parsedBuilds)
                requests = []
            } catch (e) {
                fail(e.message || "Failed to parse Jenkins jobs.")
            }
        }, credential)
    }

    function refresh() {
        if (busy) {
            return
        }

        let targetApiUrl
        try {
            targetApiUrl = Jenkins.apiUrl(entry.url)
        } catch (error) {
            fail(error.message)
            return
        }

        const requestGeneration = ++generation
        busy = true
        deadline = Date.now() + 30000

        const activeWallet = typeof source !== "undefined" && source && source.wallet ? source.wallet : (typeof wallet !== "undefined" ? wallet : null)
        if (entry.type === "anonymous") {
            executeRefresh(targetApiUrl, requestGeneration, "")
        } else if (activeWallet) {
            activeWallet.access(Jenkins.walletKey(entry), "", false, function(errorMessage, credential) {
                try {
                    const currentGen = typeof source !== "undefined" && source ? source.generation : generation
                    if (requestGeneration !== currentGen) {
                        return
                    }
                    if (errorMessage) {
                        if (typeof source !== "undefined" && source) {
                            source.fail(errorMessage)
                        } else {
                            fail(errorMessage)
                        }
                        return
                    }
                    if (typeof source !== "undefined" && source) {
                        source.executeRefresh(targetApiUrl, requestGeneration, credential)
                    } else {
                        executeRefresh(targetApiUrl, requestGeneration, credential)
                    }
                } catch (ignored) {
                }
            })
        } else {
            fail("Wallet service unavailable.")
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
