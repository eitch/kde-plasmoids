// Copyright (c) atexxi Systems AG
const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")

for (const file of ["main.qml", "configGeneral.qml"]) {
	const source = fs.readFileSync(path.join(__dirname, "../contents/ui", file), "utf8")
	const start = source.indexOf("    function callDBus(")
	const end = source.indexOf("    function ", start + 5)
	let result
	let failure
	let reply = { value: { value: 0 } }
	const context = {
		PlasmaDBus: { SessionBus: { asyncCall: function(message, resolve, reject) {
			assert.strictEqual(message.signature, "(sxs)", file + ": argument list signature")
			assert.deepStrictEqual(Array.from(message.arguments), ["kdewallet", 0, "Chronivaro"])
			if (reply.error) reject(reply)
			else resolve(reply)
		} } }
	}
	vm.createContext(context)
	vm.runInContext(source.slice(start, end), context)
	function call() {
		context.callDBus("open", "sxs", ["kdewallet", 0, "Chronivaro"],
			value => { result = value }, error => { failure = error })
	}
	for (const value of [0, 42, false, true, "kdewallet", "token", ""]) {
		reply = { value: { value: value } }
		call()
		assert.strictEqual(result, value, file + ": unwrap typed reply")
		reply = { value: value }
		call()
		assert.strictEqual(result, value, file + ": primitive reply")
	}
	reply = { error: { message: "Wallet unavailable", name: "org.example.Error" } }
	call()
	assert.strictEqual(failure, "Wallet unavailable", file + ": nested D-Bus error")
	assert(!source.includes("!handle || handle <= 0"), file + ": zero is a valid wallet handle")
}

const config = fs.readFileSync(path.join(__dirname, "../contents/ui/configGeneral.qml"), "utf8")
assert(config.includes("KCM.SimpleKCM {"), "Plasma 6 configuration page root")
for (const key of ["endpoint", "token", "pollInterval", "workingLocation"]) {
	assert(new RegExp("property \\w+ cfg_" + key + "Default").test(config), key + " default property")
}
assert(config.includes("echoMode: TextInput.Password"), "QtQuick password enum")
console.log("Plasmoid regression checks passed")