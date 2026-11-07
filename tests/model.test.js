// Run with: node tests/model.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "\nreturn { airpodsVariant, kindIcon, kindGlyph, deviceTitle, jblTitle, jblSpeakers, otherDevices, kindLabel, batteryGlyph, powerGlyph, GLYPHS, KIND_GLYPHS, parseProbe, withLastKnown, airpodsWithLastKnown, percent, duration, watts, isLow, statusText, subtitle, laptopStatus, laptopFacts, laptopEnergy, shortName, heroPhrases, heroBattery, laptopPhrase, airpodsParts, barPicks, barPickedText, airpodsShown, airpodsStatus, contrast, inBar, toggleBarDevice, idList, barItems, parseHistory, serializeHistory, pushLevelSample, historySince, drainPerHour, drainRate, lowBatteryAlerts, alertables, tooltip, chargeStep, CHARGE_BAND_ALPHA }")()

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
// The panel's Nerd Font glyphs: the ramps Omarchy's power panel uses.
assert.strictEqual(Model.batteryGlyph(95, false), "\u{F0079}")
assert.strictEqual(Model.batteryGlyph(100, false), "\u{F0079}")
assert.strictEqual(Model.batteryGlyph(40, false), "\u{F007E}")
assert.strictEqual(Model.batteryGlyph(5, false), "\u{F007A}")
assert.strictEqual(Model.batteryGlyph(5, true), "\u{F089C}")
assert.strictEqual(Model.batteryGlyph(null, false), Model.GLYPHS.unknownBattery)
assert.strictEqual(Model.kindGlyph("speakers"), "\u{F04C3}")
assert.strictEqual(Model.kindGlyph("toaster"), Model.GLYPHS.battery)
// A glyph for every kind the bar has an icon for, and one character each.
for (const k of ["mouse", "keyboard", "headset", "headphones", "speakers", "gaming-input", "touchpad", "tablet", "pen", "phone", "media-player", "remote-control", "ups", "bluetooth-generic", "laptop", "airpods"]) {
  assert.ok(Model.KIND_GLYPHS[k], k)
  assert.strictEqual([...Model.KIND_GLYPHS[k]].length, 1, k)
}
for (const name of Object.keys(Model.GLYPHS)) assert.strictEqual([...Model.GLYPHS[name]].length, 1, name)
// The power mark: a bolt while charge flows, a plug on a charger with none.
assert.strictEqual(Model.powerGlyph({ charging: true, acOnline: true }), Model.GLYPHS.bolt)
assert.strictEqual(Model.powerGlyph({ charging: false, acOnline: true }), Model.GLYPHS.plug)
assert.strictEqual(Model.powerGlyph({ charging: false, powered: true }), Model.GLYPHS.plug)
assert.strictEqual(Model.powerGlyph({ charging: false }), "")
assert.strictEqual(Model.powerGlyph(null), "")
assert.strictEqual(Model.powerGlyph({ charging: true, stale: true }), "")

// Every icon the model names exists in Icons.js.
const iconSource = fs.readFileSync(path.join(__dirname, "..", "Icons.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Icons = new Function(iconSource + "\nreturn paths")()
const markSource = fs.readFileSync(path.join(__dirname, "..", "Marks.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Marks = new Function(markSource + "\nreturn { fills }")()
const modelSource = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const qml = ["BarWidget.qml", "Panel.qml", "SectionHeader.qml", "StatTile.qml", "ToggleTile.qml", "SwitchRow.qml", "Notice.qml"].map(f => fs.readFileSync(path.join(__dirname, "..", f), "utf8")).join("\n")
for (const m of (modelSource + qml).matchAll(/(?:icon|name): "([a-z0-9-]+)"/g)) assert.ok(Icons[m[1]] || Marks.fills[m[1]] || m[1] === "airpods", "missing icon " + m[1])
for (const k of ["mouse", "keyboard", "headset", "laptop", "phone", "gaming-input", "ups"]) assert.ok(Icons[Model.kindIcon(k)], k)

// Contrast tells a usable red from a theme's muted one.
{
  const hex = h => ({ r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255 })
  assert.ok(Math.abs(Model.contrast(hex("#ffffff"), hex("#000000")) - 21) < 0.01)
  assert.ok(Model.contrast(hex("#565d60"), hex("#101315")) < 3.5, "Solitude's red")
  assert.ok(Model.contrast(hex("#ed8796"), hex("#24273a")) > 3.5, "a real red")
}

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
assert.strictEqual(Model.laptopEnergy(onBattery), "36.6/57.2 Wh")
assert.strictEqual(Model.laptopEnergy({ energyWh: 10 }), "")
assert.deepStrictEqual(Model.laptopFacts(onBattery, 6.25), [
  { label: "Power", value: "12 W" }, { label: "Health", value: "75%" }, { label: "Limit", value: "90%" },
  { label: "Cycles", value: "120" }, { label: "Energy", value: "36.6/57.2 Wh" }, { label: "Drain", value: "6.3%/h" }])
assert.deepStrictEqual(Model.laptopFacts(Object.assign({}, onBattery, { chargeLimit: null, cycles: null, health: null }), null).map(f => f.label), ["Power", "Energy"])
assert.deepStrictEqual(Model.laptopFacts(null, 5), [])

// The panel's caption: facts taking turns with flavour, what is low holding still.
{
  const lines = Model.heroPhrases({ laptop: onBattery, devices: [wireless] }, 20)
  assert.strictEqual(lines[0], "2 batteries above 20%")
  assert.strictEqual(lines[2], "Laptop has 3h 05m left")
  assert.strictEqual(lines[4], "Laptop lowest at 64%")
  assert.strictEqual(lines.length, 6)
  assert.ok(lines[1] && lines[3] && lines[5])
}
assert.deepStrictEqual(Model.heroPhrases({ laptop: onBattery, devices: [] }, 20).slice(0, 1), ["1 battery above 20%"])
assert.deepStrictEqual(Model.heroPhrases({ laptop: onBattery, devices: [Object.assign({}, wireless, { level: 12 })] }, 20), ["Mouse low at 12%"])
// Several low hold one line too, naming the emptiest.
assert.deepStrictEqual(Model.heroPhrases({ laptop: Object.assign({}, onBattery, { level: 9 }), devices: [Object.assign({}, wireless, { level: 12 })] }, 20), ["2 low, laptop at 9%"])
// A stale reading is not a fact. A charging battery under the threshold is not
// low, and the caption says what it is instead of "above 20%".
assert.deepStrictEqual(Model.heroPhrases({ laptop: Object.assign({}, charging, { level: 9 }), devices: [Object.assign({}, wireless, { level: 12, stale: true })] }, 20).slice(0, 1), ["Laptop charging at 9%"])
assert.deepStrictEqual(Model.heroPhrases({ laptop: Object.assign({}, charging, { level: 50 }), devices: [Object.assign({}, wireless, { level: 12, stale: true })] }, 20).slice(0, 1), ["1 battery above 20%"])
// AirPods take a short name whatever they are called, so the caption stays on one line.
assert.strictEqual(Model.heroPhrases({ airpods: { name: "Someone's Very Long AirPods Pro", known: true, level: 50 }, devices: [] }, 20)[0], "1 battery above 20%")
assert.ok(Model.heroPhrases({ airpods: { name: "Someone's Very Long AirPods Pro", known: true, level: 50 }, devices: [wireless] }, 20).includes("AirPods lowest at 50%"))
assert.deepStrictEqual(Model.heroPhrases({ devices: [] }, 20), ["No batteries found"])
assert.deepStrictEqual(Model.heroPhrases(null, 20), ["No batteries found"])
// Rows without a fresh reading are not "no batteries".
assert.deepStrictEqual(Model.heroPhrases({ devices: [asleep] }, 20), ["No fresh readings"])
assert.deepStrictEqual(Model.heroPhrases({ devices: [Object.assign({}, wireless, { stale: true })] }, 20), ["No fresh readings"])
// The AirPods case counts: one battery, at whichever is emptier.
{
  const buds = { name: "AirPods Pro", known: true, level: 70, charging: false, "case": { level: 10, charging: false } }
  assert.deepStrictEqual(Model.heroPhrases({ airpods: buds, devices: [] }, 15), ["AirPods case low at 10%"])
  assert.deepStrictEqual(Model.heroBattery({ airpods: buds, devices: [] }, 15), { level: 10, charging: false, low: true })
  const charged = Object.assign({}, buds, { "case": { level: 10, charging: true } })
  assert.strictEqual(Model.heroPhrases({ airpods: charged, devices: [] }, 15)[0], "AirPods case charging at 10%")
  assert.strictEqual(Model.heroPhrases({ airpods: Object.assign({}, buds, { "case": { level: 90 } }), devices: [] }, 15)[0], "1 battery above 15%")
  assert.ok(Model.heroPhrases({ airpods: Object.assign({}, buds, { "case": { level: 40 } }), devices: [wireless] }, 15).includes("AirPods case lowest at 40%"))
  // The case alone reporting is still a reading.
  assert.deepStrictEqual(Model.heroPhrases({ airpods: Object.assign({}, buds, { level: null }), devices: [] }, 15), ["AirPods case low at 10%"])
}
// Kinds that say nothing fall back to the device's own name.
assert.strictEqual(Model.shortName(wireless), "Mouse")
assert.strictEqual(Model.shortName({ kind: "bluetooth-generic", name: "Tile Mate" }), "Tile Mate")
assert.strictEqual(Model.shortName({ kind: "unknown", name: "Thing" }), "Thing")
assert.strictEqual(Model.shortName({ name: "Thing" }), "Thing")
assert.strictEqual(Model.barPicks({ devices: [{ id: "t", kind: "bluetooth-generic", name: "Tile Mate", status: "discharging" }] })[0].label, "Tile Mate")
assert.strictEqual(Model.laptopPhrase(charging), "Laptop at 90% in 50m")
assert.strictEqual(Model.laptopPhrase(Object.assign({}, charging, { chargeLimit: null })), "Laptop full in 50m")
assert.strictEqual(Model.laptopPhrase(held), "Laptop held at 90%")
assert.strictEqual(Model.laptopPhrase({ status: "full" }), "Laptop fully charged")
assert.strictEqual(Model.laptopPhrase(null), "")
// The header's battery: what is low, else the laptop, else the emptiest.
assert.deepStrictEqual(Model.heroBattery({ laptop: charging, devices: [wireless] }, 20), { level: 64, charging: true, low: false })
assert.deepStrictEqual(Model.heroBattery({ laptop: onBattery, devices: [Object.assign({}, wireless, { level: 12 })] }, 20), { level: 12, charging: false, low: true })
assert.deepStrictEqual(Model.heroBattery({ devices: [Object.assign({}, wireless, { level: 50 }), Object.assign({}, wireless, { level: 30 })] }, 20), { level: 30, charging: false, low: false })
assert.deepStrictEqual(Model.heroBattery({ devices: [] }, 20), { level: null, charging: false, low: false })

// AirPods
const podsFresh = { name: "AirPods Pro", model: "AirPods Pro 2 (USB-C)", connected: true, isHeadset: false, left: { level: 80, charging: false, inEar: true }, right: { level: 70, charging: false, inEar: true }, case: { level: 50, charging: true }, headset: null, level: 70, charging: false, known: true }
const podsGone = { name: "AirPods Pro", model: "", connected: false, isHeadset: false, left: null, right: null, case: null, headset: null, level: null, charging: false, known: false }
assert.strictEqual(Model.airpodsStatus(podsFresh), "Connected · in both ears")
const podsKept = Model.airpodsWithLastKnown(podsGone, podsFresh)
assert.strictEqual(podsKept.stale, true)
assert.strictEqual(podsKept.left.level, 80)
assert.strictEqual(Model.airpodsStatus(podsKept), "Not connected · last levels")
assert.strictEqual(Model.airpodsStatus(Object.assign({}, podsKept, { connected: true })), "Connected · last levels")
assert.strictEqual(Model.airpodsWithLastKnown(podsGone, null).known, false)
assert.deepStrictEqual(Model.airpodsParts(podsFresh).map(p => p.key), ["left", "right", "case"])
assert.deepStrictEqual(Model.airpodsParts({ isHeadset: true, headset: { level: 50 } }).map(p => p.key), ["headset"])
// Like any other device, AirPods leave the panel when they disconnect, last levels or not.
assert.strictEqual(Model.airpodsShown(podsFresh), true)
assert.strictEqual(Model.airpodsShown(podsGone), false)
assert.strictEqual(Model.airpodsShown(podsKept), false)
assert.strictEqual(Model.airpodsShown(null), false)

// The bar picker: laptop, AirPods, then each peripheral.
{
  const picks = Model.barPicks({ laptop: onBattery, airpods: podsFresh, devices: [wireless] })
  assert.deepStrictEqual(picks.map(p => p.key || p.device.id), ["barLaptop", "barLaptopRate", "barLaptopTime", "barAirpods", "barAirpodsCase", "glorious:2022"])
  assert.strictEqual(picks[5].icon, Model.kindGlyph("mouse"))
  assert.strictEqual(picks[5].label, "Mouse")
  assert.strictEqual(picks[5].hint, "Glorious Model O Wireless · On battery · 2.4 GHz")
  assert.strictEqual(Model.barPicks({ devices: [wireless, Object.assign({}, wireless, { id: "b", name: "G502" })] })[1].label, "G502")
  assert.ok(!Model.barPicks({ airpods: { isHeadset: true, connected: true, name: "AirPods Max" }, devices: [] }).some(p => p.key === "barAirpodsCase"))
  assert.ok(Model.barPicks({ airpods: { isHeadset: true, connected: true, name: "AirPods Max" }, devices: [] }).some(p => p.key === "barAirpods"))
  assert.ok(!Model.barPicks({ airpods: podsKept, devices: [] }).some(p => p.key.startsWith("barAirpods")))
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
// The wave shows while on a charger, charging or not; a low mouse goes urgent.
const barLaptop = lap => Model.barItems(Object.assign({}, state, { laptop: lap }), opts).find(i => i.key === "laptop")
assert.strictEqual(barLaptop(charging).powered, true)
assert.strictEqual(barLaptop(Object.assign({}, onBattery, { status: "held", acOnline: true })).powered, true)
assert.strictEqual(barLaptop(Object.assign({}, onBattery, { status: "full", level: 100, acOnline: true })).powered, true)
assert.strictEqual(barLaptop(onBattery).powered, false)
const fullOnCable = Object.assign({}, cabled, { level: 100, charging: false, powered: true, status: "full" })
assert.strictEqual(Model.barItems(Object.assign({}, state, { devices: [fullOnCable] }), opts)[0].powered, true)
assert.strictEqual(Model.barItems(state, opts)[0].powered, false)
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
  assert.strictEqual(Model.drainRate(10.4), "10%/h")
  assert.strictEqual(Model.drainRate(4.26), "4.3%/h")
  assert.strictEqual(Model.historySince(run, 4800, 0.5).length, 4)
}

// The charging band sweeps in steps on the clock, then waits out the rest in one go.
{
  assert.deepStrictEqual(Model.chargeStep(0, 80), { flow: 0, wait: 80 })
  assert.deepStrictEqual(Model.chargeStep(100, 80), { flow: 0.04, wait: 60 })
  assert.deepStrictEqual(Model.chargeStep(4100, 80), Model.chargeStep(100, 80))
  assert.deepStrictEqual(Model.chargeStep(2000, 80), { flow: 1, wait: 2000 })
  assert.deepStrictEqual(Model.chargeStep(3999, 80), { flow: 1, wait: 1 })
  // Walking the waits lands on every step once and never stalls.
  let now = 0, moves = 0, last = -1
  while (now < 4000) {
    const step = Model.chargeStep(now, 80)
    assert.ok(step.wait >= 1)
    assert.ok(step.flow > last)
    last = step.flow
    moves++
    now += step.wait
  }
  assert.strictEqual(moves, 26)
}

console.log("model tests passed")
