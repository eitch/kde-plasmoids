// Copyright (c) atexxi Systems AG
const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const source = fs.readFileSync(path.join(__dirname, "../contents/ui/configGeneral.qml"), "utf8")
let requests = []
let dialogs = 0
let timerRunning = false
let failSend = false
class Request {
	constructor() { this.headers = {}; requests.push(this) }
	open(method, url) { this.method = method; this.url = url }
	setRequestHeader(name, value) { this.headers[name] = value }
	send() { if (failSend) throw new Error("send failed") }
	abort() { this.aborted = true; this.complete(0, "") }
	complete(status, body) {
		this.status = status
		this.responseText = body
		this.readyState = Request.DONE
		this.onreadystatechange()
	}
}
Request.DONE = 4
const context = {
	endpoint: { text: " https://example.test/rest/status " },
	token: { text: " id:secret " },
	connectionRequest: null,
	connectionSucceeded: false,
	connectionMessage: "",
	connectionTimeout: { start() { timerRunning = true }, stop() { timerRunning = false } },
	connectionDialog: { open() { dialogs++ } },
	XMLHttpRequest: Request
}
context.configRoot = context
vm.createContext(context)
vm.runInContext(source.slice(source.indexOf("    function finishConnectionTest("),
	source.indexOf("    onWalletStatusMessageChanged:")), context)

for (const url of ["", "file:///tmp/status", "https://", "not a URL"]) {
	context.endpoint.text = url
	context.testConnection()
	assert.strictEqual(context.connectionSucceeded, false)
}
assert.strictEqual(requests.length, 0)
context.endpoint.text = " https://example.test/rest/status "
context.token.text = " "
context.testConnection()
assert.strictEqual(requests.length, 0)
context.token.text = " id:secret "

for (const [status, body, success] of [
	[200, '{"running":false,"today":{},"month":{}}', true],
	[401, "", false], [403, "", false], [404, "", false], [500, "", false],
	[0, "", false], [200, "<html/>", false], [200, "{}", false],
	[200, "null", false], [204, "", false]
]) {
	context.testConnection()
	const request = context.connectionRequest
	assert(timerRunning)
	context.testConnection()
	assert.strictEqual(context.connectionRequest, request)
	assert.strictEqual(request.method, "GET")
	assert.strictEqual(request.url, "https://example.test/rest/status")
	assert.strictEqual(request.headers.Authorization, "Bearer id:secret")
	assert.strictEqual(request.headers.Accept, "application/json")
	const before = dialogs
	request.complete(status, body)
	assert.strictEqual(dialogs, before + 1)
	assert.strictEqual(context.connectionSucceeded, success)
	assert.strictEqual(context.connectionRequest, null)
	assert(!timerRunning)
	assert(!context.connectionMessage.includes("id:secret"))
}

context.testConnection()
const pending = context.connectionRequest
const beforeTimeout = dialogs
const timeout = source.match(/onTriggered: \{([\s\S]*?)\n        \}/)[1]
vm.runInContext(timeout, context)
assert(pending.aborted)
assert.strictEqual(context.connectionRequest, null)
assert.strictEqual(dialogs, beforeTimeout + 1)
assert(context.connectionMessage.includes("timed out"))
pending.complete(200, '{"running":false,"today":{},"month":{}}')
assert.strictEqual(dialogs, beforeTimeout + 1)

failSend = true
context.testConnection()
assert.strictEqual(context.connectionSucceeded, false)
assert.strictEqual(context.connectionRequest, null)
assert(!timerRunning)
assert(requests[requests.length - 1].aborted)
console.log("Connection test checks passed")