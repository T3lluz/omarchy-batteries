// Run with: node tests/model.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "\nreturn { airpodsVariant, kindIcon, deviceTitle, jblTitle, jblSpeakers, otherDevices, jblStatus, kindLabel, batteryIcon, parseProbe, withLastKnown, airpodsWithLastKnown, percent, duration, watts, isLow, statusText, subtitle, laptopStatus, laptopTiles, laptopEnergy, summary, airpodsParts, airpodsTiles, barPicks, barPickedText, airpodsStatus, inBar, toggleBarDevice, idList, barItems, parseHistory, serializeHistory, pushLevelSample, historySince, drainPerHour, drainText, lowBatteryAlerts, alertables, tooltip }")()

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
assert.strictEqual(Model.kindIcon("mouse"), "mouse")
assert.strictEqual(Model.kindIcon("toaster"), "battery")
assert.strictEqual(Model.kindLabel("gaming-input"), "Controller")
assert.strictEqual(Model.kindLabel("mouse"), "Mouse")
assert.strictEqual(Model.kindLabel("speakers"), "Speaker")

// JBL speakers: titled by model, the app's name underneath, out of Devices.
const charge = { id: "jbl:F8", name: "Sound object", model: "JBL Charge 5", kind: "speakers", source: "jbl", level: 60, status: "discharging", connection: "bluetooth" }
const boombox = { id: "jbl:AA", name: "JBL Boombox 3", model: "JBL Boombox 3", kind: "speakers", source: "jbl", level: 90, status: "discharging", connection: "bluetooth" }
assert.strictEqual(Model.deviceTitle(charge), "JBL Charge 5")
assert.strictEqual(Model.jblTitle(charge), "Charge 5")
assert.strictEqual(Model.jblTitle({ name: "Sound object", source: "jbl" }), "Sound object")
assert.strictEqual(Model.deviceTitle({ name: "G502" }), "G502")
assert.strictEqual(Model.subtitle(charge), "Sound object · On battery · Bluetooth")
assert.strictEqual(Model.subtitle(boombox), "On battery · Bluetooth")
assert.strictEqual(Model.kindIcon(charge.kind), "device-speaker")
const glorious = { id: "m", name: "Mouse", kind: "mouse", source: "glorious" }
assert.deepStrictEqual(Model.jblSpeakers([glorious, charge]), [charge])
assert.deepStrictEqual(Model.otherDevices([glorious, charge]), [glorious])
assert.strictEqual(Model.jblStatus([charge, boombox]), "2 connected")
assert.strictEqual(Model.batteryIcon(95, false), "battery-4")
assert.strictEqual(Model.batteryIcon(40, false), "battery-2")
assert.strictEqual(Model.batteryIcon(5, false), "battery")
assert.strictEqual(Model.batteryIcon(5, true), "battery-charging")
assert.strictEqual(Model.batteryIcon(null, false), "battery-off")

// Every icon the model names exists in Icons.js.
const iconSource = fs.readFileSync(path.join(__dirname, "..", "Icons.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Icons = new Function(iconSource + "\nreturn paths")()
const markSource = fs.readFileSync(path.join(__dirname, "..", "Marks.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Marks = new Function(markSource + "\nreturn { fills }")()
const modelSource = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const qml = ["BarWidget.qml", "Panel.qml", "SectionHeader.qml", "StatTile.qml", "ToggleTile.qml", "SwitchRow.qml", "Notice.qml"].map(f => fs.readFileSync(path.join(__dirname, "..", f), "utf8")).join("\n")
for (const m of (modelSource + qml).matchAll(/(?:icon|name): "([a-z0-9-]+)"/g)) assert.ok(Icons[m[1]] || Marks.fills[m[1]] || m[1] === "airpods", "missing icon " + m[1])
for (const m of modelSource.matchAll(/return "((?:battery|device)[a-z0-9-]*)"/g)) assert.ok(Icons[m[1]], "missing icon " + m[1])
for (const k of ["mouse", "keyboard", "headset", "laptop", "phone", "gaming-input", "ups"]) assert.ok(Icons[Model.kindIcon(k)], k)

// The JBL mark lives in Marks.js.
assert.ok(Marks.fills.jbl)

// Laptop
const onBattery = { level: 64, status: "discharging", charging: false, acOnline: false, rateW: 12.34, timeToEmpty: 3 * 3600 + 5 * 60, timeToFull: null, energyWh: 36.6, energyFullWh: 57.2, energyDesignWh: 76, health: 75, cycles: 120, chargeLimit: 90, chargeStart: null, batteries: ["BAT0"] }
const charging = Object.assign({}, onBattery, { status: "charging", charging: true, acOnline: true, rateW: 45, timeToEmpty: null, timeToFull: 50 * 60 })
const held = Object.assign({}, onBattery, { level: 90, status: "held", acOnline: true, rateW: 0, timeToEmpty: null })
assert.strictEqual(Model.laptopStatus(onBattery), "On battery · 3h 05m left")
assert.strictEqual(Model.laptopStatus(charging), "Charging · 50m to 90%")
assert.strictEqual(Model.laptopStatus(held), "Plugged in · held at 90% limit")
assert.strictEqual(Model.duration(59 * 60 + 50), "1h 00m")
assert.strictEqual(Model.watts(12.34), "12 W")
assert.strictEqual(Model.watts(4.56), "4.6 W")
assert.deepStrictEqual(Model.laptopTiles(onBattery).map(t => t.caption), ["POWER", "HEALTH", "LIMIT"])
assert.deepStrictEqual(Model.laptopTiles(onBattery)[0], { icon: "bolt", caption: "POWER", value: "12 W", note: "On battery" })
assert.strictEqual(Model.laptopTiles(onBattery)[2].note, "120 cycles")
assert.strictEqual(Model.laptopTiles(held)[0].note, "Plugged in")
// Without a limit or cycles, the stored energy fills the third tile.
assert.deepStrictEqual(Model.laptopTiles(Object.assign({}, onBattery, { chargeLimit: null, cycles: null })).map(t => t.caption), ["POWER", "HEALTH", "STORED"])
assert.strictEqual(Model.laptopEnergy(onBattery), "36.6 of 57.2 Wh")
assert.strictEqual(Model.laptopEnergy({ energyWh: 10 }), "")

// The panel header's line.
assert.strictEqual(Model.summary({ laptop: onBattery, devices: [] }, 20), "1 battery · above 20%")
assert.strictEqual(Model.summary({ laptop: onBattery, devices: [wireless] }, 20), "2 batteries · all above 20%")
assert.strictEqual(Model.summary({ laptop: onBattery, devices: [Object.assign({}, wireless, { level: 12 })] }, 20), "Mouse is low · 12%")
assert.strictEqual(Model.summary({ laptop: Object.assign({}, onBattery, { level: 9 }), devices: [Object.assign({}, wireless, { level: 12 })] }, 20), "2 batteries are low")
// Charging is never low, and a device last seen a while ago does not count.
assert.strictEqual(Model.summary({ laptop: Object.assign({}, charging, { level: 9 }), devices: [Object.assign({}, wireless, { stale: true })] }, 20), "1 battery · above 20%")
assert.strictEqual(Model.summary({ devices: [] }, 20), "No batteries found")

// AirPods
const podsFresh = { name: "AirPods Pro", model: "AirPods Pro 2 (USB-C)", connected: true, isHeadset: false, left: { level: 80, charging: false, inEar: true }, right: { level: 70, charging: false, inEar: true }, case: { level: 50, charging: true }, headset: null, level: 70, charging: false, known: true }
const podsGone = { name: "AirPods Pro", model: "", connected: false, isHeadset: false, left: null, right: null, case: null, headset: null, level: null, charging: false, known: false }
assert.strictEqual(Model.airpodsStatus(podsFresh), "Connected · in both ears")
const podsKept = Model.airpodsWithLastKnown(podsGone, podsFresh)
assert.strictEqual(podsKept.stale, true)
assert.strictEqual(podsKept.left.level, 80)
assert.strictEqual(Model.airpodsStatus(podsKept), "Not connected · last levels")
assert.strictEqual(Model.airpodsWithLastKnown(podsGone, null).known, false)
assert.deepStrictEqual(Model.airpodsParts(podsFresh).map(p => p.key), ["left", "right", "case"])
assert.deepStrictEqual(Model.airpodsParts({ isHeadset: true, headset: { level: 50 } }).map(p => p.key), ["headset"])
assert.deepStrictEqual(Model.airpodsTiles(podsFresh).map(t => [t.caption, t.icon, t.value]), [["LEFT", "device-airpods", "80%"], ["RIGHT", "device-airpods", "70%"], ["CASE", "bolt", "50%"]])
assert.strictEqual(Model.airpodsTiles(podsGone).length, 3)

// The bar picker: laptop, AirPods, then each peripheral.
{
  const picks = Model.barPicks({ laptop: onBattery, airpods: podsFresh, devices: [wireless] })
  assert.deepStrictEqual(picks.map(p => p.key || p.device.id), ["barLaptop", "barLaptopRate", "barLaptopTime", "barAirpods", "barAirpodsCase", "glorious:2022"])
  assert.strictEqual(picks[5].icon, "mouse")
  assert.ok(!Model.barPicks({ airpods: { isHeadset: true, name: "AirPods Max" }, devices: [] }).some(p => p.key === "barAirpodsCase"))
  assert.strictEqual(Model.barPickedText(0), "ICON ONLY")
  assert.strictEqual(Model.barPickedText(2), "2 SHOWN")
}

assert.strictEqual(Model.airpodsVariant(podsFresh), "buds")
assert.strictEqual(Model.airpodsVariant(Object.assign({}, podsFresh, { isPro: true })), "pro")
assert.strictEqual(Model.airpodsVariant({ isHeadset: true }), "max")

// The bar picker
const mouse = wireless
const kb = { id: "upower:kb", name: "MX Keys", kind: "keyboard", level: 60, charging: false, status: "discharging", connection: "bluetooth" }
const opts = { laptop: true, laptopRate: false, laptopTime: false, airpods: true, airpodsCase: false, devices: null, percent: true, lowThreshold: 20 }
const state = { laptop: onBattery, airpods: podsFresh, devices: [mouse, kb] }
assert.deepStrictEqual(Model.barItems(state, opts).map(i => i.key), ["glorious:2022", "airpods", "laptop"])
assert.deepStrictEqual(Model.barItems(state, Object.assign({}, opts, { laptopRate: true, laptopTime: true, airpodsCase: true, devices: [kb.id] })).map(i => i.key),
  ["upower:kb", "airpods", "airpods-case", "laptop", "laptop-rate", "laptop-time"])
assert.deepStrictEqual(Model.barItems(state, Object.assign({}, opts, { laptop: false, airpods: false, devices: [] })), [])
// No numbers with percentages off, but rate and time keep theirs.
const quiet = Model.barItems(state, Object.assign({}, opts, { percent: false, laptopRate: true }))
assert.ok(quiet.filter(i => i.key !== "laptop-rate").every(i => i.text === ""))
assert.strictEqual(quiet.find(i => i.key === "laptop-rate").text, "12 W")
// Stale AirPods stay out of the bar.
assert.ok(!Model.barItems(Object.assign({}, state, { airpods: podsKept }), opts).some(i => i.key === "airpods"))
assert.strictEqual(Model.barItems(state, opts).find(i => i.key === "laptop").icon, "device-laptop")
assert.strictEqual(Model.barItems(state, opts).find(i => i.key === "airpods").icon, "airpods")
// Charging laptop carries the bolt; a low mouse goes urgent.
assert.strictEqual(Model.barItems(Object.assign({}, state, { laptop: charging }), opts).find(i => i.key === "laptop").charging, true)
assert.strictEqual(Model.barItems(Object.assign({}, state, { devices: [Object.assign({}, mouse, { level: 9 })] }), opts)[0].tone, "low")
// Toggling from auto starts from the mice auto showed.
assert.deepStrictEqual(Model.toggleBarDevice(null, kb.id, [mouse, kb]), [mouse.id, kb.id])
assert.deepStrictEqual(Model.toggleBarDevice(null, mouse.id, [mouse, kb]), [])
assert.deepStrictEqual(Model.toggleBarDevice([kb.id], kb.id, [mouse, kb]), [])
assert.strictEqual(Model.inBar(mouse, null), true)

// A saved pick survives however the shell hands it over: a real array, an
// array-like Qt sequence (which fails Array.isArray), or nothing yet.
assert.deepStrictEqual(Model.idList([kb.id]), [kb.id])
assert.deepStrictEqual(Model.idList({ length: 1, 0: kb.id }), [kb.id])
assert.deepStrictEqual(Model.idList({ length: 0 }), [])
assert.strictEqual(Model.idList(null), null)
assert.strictEqual(Model.idList(undefined), null)
assert.strictEqual(Model.idList("mouse"), null)
assert.strictEqual(Model.inBar(mouse, Model.idList({ length: 0 })), false)
assert.strictEqual(Model.inBar(kb, null), false)

// AirPods join the low-battery watch only while fresh.
assert.strictEqual(Model.alertables(state).length, 3)
assert.strictEqual(Model.alertables(Object.assign({}, state, { airpods: podsKept })).length, 2)

assert.ok(Model.tooltip(state).includes("Laptop  64%"))
assert.ok(Model.tooltip(state).includes("Left 80%"))
assert.strictEqual(Model.tooltip({ devices: [] }), "No batteries found")

// History: a sample every two minutes or on a change, a day kept.
{
  let h = []
  h = Model.pushLevelSample(h, 1000, 80, false)
  h = Model.pushLevelSample(h, 1060, 80, false)
  assert.strictEqual(h.length, 1)
  h = Model.pushLevelSample(h, 1070, 79, false)
  assert.strictEqual(h.length, 2)
  h = Model.pushLevelSample(h, 1080, 79, true)
  assert.strictEqual(h.length, 3)
  h = Model.pushLevelSample(h, 1080 + 25 * 3600, 60, false)
  assert.deepStrictEqual(h, [[1080 + 25 * 3600, 60, 0]])
  assert.deepStrictEqual(Model.pushLevelSample([], 5, null, false), [])
  assert.deepStrictEqual(Model.parseHistory('{"version":2,"samples":[[1,50,0],[2,"x",1],[3,120,0],[4,40,1]]}'), [[1, 50, 0], [4, 40, 1]])
  assert.deepStrictEqual(Model.parseHistory(Model.serializeHistory([[1, 50, 0], [700, 40, 1]])), [[1, 50, 0], [700, 40, 1]])
  // Version 1 kept charging: resting next to charging was the pack held at its limit.
  assert.deepStrictEqual(Model.parseHistory('{"version":1,"samples":[[0,80,0],[1000,90,1],[1060,89,0],[3000,88,0]]}'), [[0, 80, 0], [1000, 90, 1], [1060, 89, 1], [3000, 88, 0]])
  assert.deepStrictEqual(Model.parseHistory("nope"), [])
  // 10 points an hour over an hour on battery; the plugged-in stretch is left out.
  const run = []
  for (let i = 0; i <= 6; i++) run.push([i * 600, 90 - i * (10 / 6), 0])
  run.push([4200, 80, 1], [4800, 85, 1])
  assert.strictEqual(Math.round(Model.drainPerHour(run, 4800, 12)), 10)
  assert.strictEqual(Model.drainPerHour(run.slice(0, 2), 600, 12), null)
  assert.strictEqual(Model.drainText(10.4), "10%/h on battery")
  assert.strictEqual(Model.drainText(4.26), "4.3%/h on battery")
  assert.strictEqual(Model.historySince(run, 4800, 0.5).length, 4)
}

console.log("model tests passed")
