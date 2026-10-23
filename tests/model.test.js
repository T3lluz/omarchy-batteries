// Run with: node tests/model.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "\nreturn { kindIcon, kindLabel, parseProbe, withLastKnown, pickPrimary, percent, isLow, statusText, subtitle, lowBatteryAlerts, tooltip }")()

const cabled = { id: "glorious:2022", name: "Glorious Model O Wireless", kind: "mouse", level: 77, charging: true, status: "charging", connection: "usb" }
const wireless = { id: "glorious:2022", name: "Glorious Model O Wireless", kind: "mouse", level: 76, charging: false, status: "discharging", connection: "wireless" }
const asleep = { id: "glorious:2022", name: "Glorious Model O Wireless", kind: "mouse", level: null, charging: false, status: "asleep", connection: "wireless" }
const headset = { id: "upower:/org/bluez/hci0/dev_AA", name: "WH-1000XM5", kind: "headset", level: 40, charging: false, status: "discharging", connection: "bluetooth" }

// parseProbe
const parsed = Model.parseProbe(JSON.stringify({ devices: [cabled, {}], needsAccess: ["/dev/hidraw3"], udevInstalled: true }))
assert.strictEqual(parsed.devices.length, 1)
assert.deepStrictEqual(parsed.needsAccess, ["/dev/hidraw3"])
assert.strictEqual(parsed.udevInstalled, true)
assert.strictEqual(Model.parseProbe("Traceback"), null)
assert.strictEqual(Model.parseProbe('{"x":1}'), null)

// Cable: bolt, accent subtitle
assert.strictEqual(Model.subtitle(cabled), "Charging · USB cable")
// 2.4 GHz
assert.strictEqual(Model.subtitle(wireless), "On battery · 2.4 GHz")

// A napping mouse keeps its last level, marked stale.
const kept = Model.withLastKnown([asleep], [wireless])
assert.strictEqual(kept[0].level, 76)
assert.strictEqual(kept[0].stale, true)
assert.strictEqual(Model.subtitle(kept[0]), "Asleep · 2.4 GHz · last level")
// A fresh level is never stale.
assert.strictEqual(Model.withLastKnown([wireless], [cabled])[0].stale, false)
// With no history there is nothing to keep.
assert.strictEqual(Model.withLastKnown([asleep], [])[0].level, null)
// Inputs are not mutated.
assert.strictEqual(asleep.stale, undefined)

// pickPrimary
assert.strictEqual(Model.pickPrimary([headset, wireless], "").id, "glorious:2022")
assert.strictEqual(Model.pickPrimary([headset, wireless], headset.id).id, headset.id)
assert.strictEqual(Model.pickPrimary([headset, wireless], "gone").id, "glorious:2022")
assert.strictEqual(Model.pickPrimary([headset], "").id, headset.id)
assert.strictEqual(Model.pickPrimary([], ""), null)

// percent / isLow
assert.strictEqual(Model.percent(76.4), "76%")
assert.strictEqual(Model.percent(null), "--")
assert.strictEqual(Model.isLow({ level: 15, charging: false }, 20), true)
assert.strictEqual(Model.isLow({ level: 15, charging: true }, 20), false)
assert.strictEqual(Model.isLow({ level: null, charging: false }, 20), false)

// Low battery alerts fire once per dip.
const low = Object.assign({}, wireless, { level: 12 })
let r = Model.lowBatteryAlerts([low], 20, {})
assert.strictEqual(r.alerts.length, 1)
r = Model.lowBatteryAlerts([low], 20, r.notified)
assert.strictEqual(r.alerts.length, 0)
// Asleep (stale) keeps the flag rather than re-arming it.
r = Model.lowBatteryAlerts([Object.assign({}, low, { stale: true })], 20, r.notified)
assert.strictEqual(r.alerts.length, 0)
assert.strictEqual(r.notified[low.id], true)
r = Model.lowBatteryAlerts([low], 20, r.notified)
assert.strictEqual(r.alerts.length, 0)
// Charging re-arms it.
r = Model.lowBatteryAlerts([Object.assign({}, low, { charging: true })], 20, r.notified)
assert.deepStrictEqual(r.notified, {})
r = Model.lowBatteryAlerts([low], 20, r.notified)
assert.strictEqual(r.alerts.length, 1)

// Icons and labels
assert.strictEqual(Model.kindIcon("mouse"), "󰍽")
assert.strictEqual(Model.kindIcon("toaster"), "󰁹")
assert.strictEqual(Model.kindLabel("gaming-input"), "Controller")
assert.strictEqual(Model.kindLabel("mouse"), "Mouse")

assert.ok(Model.tooltip([cabled], cabled).includes("77% charging"))
assert.strictEqual(Model.tooltip([], null), "No battery-powered peripherals found")

console.log("model tests passed")
