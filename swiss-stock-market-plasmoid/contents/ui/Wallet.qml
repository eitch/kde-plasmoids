import QtQuick
import org.kde.plasma.workspace.dbus as PlasmaDBus

QtObject {
    id: wallet

    readonly property string appId: "Swiss Stock Market Plasmoid"
    readonly property string folder: "SwissStockMarket"

    function callDBus(member, signature, argumentsList, onSuccess, onFailure) {
        const request = {
            service: "org.kde.kwalletd6",
            path: "/modules/kwalletd6",
            iface: "org.kde.KWallet",
            member: member,
            signature: "(" + signature + ")",
            arguments: argumentsList
        }

        PlasmaDBus.SessionBus.asyncCall(request, function(reply) {
            let replyValue = reply && reply.value !== undefined ? reply.value : reply
            if (replyValue !== null && typeof replyValue === "object" && replyValue.value !== undefined) {
                replyValue = replyValue.value
            }
            if (onSuccess) {
                onSuccess(replyValue)
            }
        }, function() {
            if (onFailure) {
                onFailure("KWallet could not complete the request.")
            }
        })
    }

    function access(key, password, writing, onComplete) {
        function failBeforeOpen(errorMessage) {
            onComplete(errorMessage, "")
        }

        callDBus("networkWallet", "", [], function(walletName) {
            const openArguments = [walletName || "kdewallet", 0, appId]
            callDBus("open", "sxs", openArguments, function(walletHandle) {
                if (typeof walletHandle !== "number" || walletHandle < 0) {
                    onComplete("KWallet is locked or access was denied.", "")
                    return
                }
                accessOpenWallet(walletHandle, key, password, writing, onComplete)
            }, failBeforeOpen)
        }, failBeforeOpen)
    }

    function accessOpenWallet(walletHandle, key, password, writing, onComplete) {
        function finish(errorMessage, storedPassword) {
            callDBus("close", "ibs", [walletHandle, false, appId], null, null)
            onComplete(errorMessage, storedPassword)
        }

        function failAfterOpen(errorMessage) {
            finish(errorMessage, "")
        }

        function readOrWritePassword() {
            if (writing) {
                const writeArguments = [walletHandle, folder, key, password, appId]
                callDBus("writePassword", "issss", writeArguments, function(resultCode) {
                    finish(resultCode === 0 ? "" : "Could not save the credential.", "")
                }, failAfterOpen)
            } else {
                const readArguments = [walletHandle, folder, key, appId]
                callDBus("readPassword", "isss", readArguments, function(storedPassword) {
                    const errorMessage = storedPassword
                        ? ""
                        : "No credential stored. Save one in the widget settings."
                    finish(errorMessage, storedPassword || "")
                }, failAfterOpen)
            }
        }

        const folderArguments = [walletHandle, folder, appId]
        callDBus("hasFolder", "iss", folderArguments, function(folderExists) {
            if (folderExists) {
                readOrWritePassword()
            } else if (writing) {
                callDBus("createFolder", "iss", folderArguments, function(folderCreated) {
                    if (folderCreated) {
                        readOrWritePassword()
                    } else {
                        failAfterOpen("Could not create the KWallet folder.")
                    }
                }, failAfterOpen)
            } else {
                failAfterOpen("No credential stored. Save one in the widget settings.")
            }
        }, failAfterOpen)
    }
}
