// Run with: node tests/model.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Model = new Function(source + "\nreturn { kindGlyph, deviceTitle, jblSpeakers, otherDevices, kindLabel, GLYPHS, KIND_GLYPHS, parseProbe, withLastKnown, airpodsWithLastKnown, percent, duration, watts, isLow, statusText, subtitle, laptopStatus, laptopFacts, laptopEnergy, shortName, heroPhrases, heroBattery, laptopPhrase, airpodsParts, barPicks, barPickedText, airpodsShown, airpodsStatus, contrast, inBar, toggleBarDevice, idList, barItems, parseHistory, serializeHistory, pushLevelSample, historySince, drainPerHour, drainRate, lowBatteryAlerts, alertables, tooltip, chargeStep, airpodsPowered, CHARGE_BAND_ALPHA, podPartState, ago, kindTone, parsePalette, bigDigits, batteryCells, BATTERY, scramble, roomPicks, deviceFacts, airpodsFacts, markIcon, kindPixel, pixelFor, PIXEL_FONT, pixelText, roomToneHex, bigDigits: bigDigits, hoverRows, alertNote, alertStep, airpodsPutAway, keepTogether, revealLine, escapeHtml, airpodsArrival, ARRIVAL_QUIET_S, airpodsCardReady, airpodsCardParts, airpodsCardLine, airpodsPreview }")()

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
assert.strictEqual(Model.kindPixel("mouse"), "mouse")
assert.strictEqual(Model.kindPixel("toaster"), "battery-medium")
assert.strictEqual(Model.kindLabel("gaming-input"), "Controller")
assert.strictEqual(Model.kindLabel("mouse"), "Mouse")
assert.strictEqual(Model.kindLabel("speakers"), "Speaker")

// JBL speakers: titled by model, the app's name underneath, out of Devices.
const charge = { id: "jbl:F8", name: "Sound object", model: "JBL Charge 5", kind: "speakers", source: "jbl", level: 60, status: "discharging", connection: "bluetooth" }
const boombox = { id: "jbl:AA", name: "JBL Boombox 3", model: "JBL Boombox 3", kind: "speakers", source: "jbl", level: 90, status: "discharging", connection: "bluetooth" }
assert.strictEqual(Model.deviceTitle(charge), "JBL Charge 5")
assert.strictEqual(Model.deviceTitle({ name: "G502" }), "G502")
assert.strictEqual(Model.subtitle(charge), "Sound object · On battery · Bluetooth")
assert.strictEqual(Model.subtitle(boombox), "On battery · Bluetooth")
assert.strictEqual(Model.kindPixel(charge.kind), "volume-2")
const glorious = { id: "m", name: "Mouse", kind: "mouse", source: "glorious" }
assert.deepStrictEqual(Model.jblSpeakers([glorious, charge]), [charge])
assert.deepStrictEqual(Model.otherDevices([glorious, charge]), [glorious])
assert.strictEqual(Model.kindGlyph("speakers"), "\u{F04C3}")
assert.strictEqual(Model.kindGlyph("toaster"), Model.GLYPHS.battery)
// A glyph for every kind the bar has an icon for, and one character each.
for (const k of ["mouse", "keyboard", "headset", "headphones", "speakers", "gaming-input", "touchpad", "tablet", "pen", "phone", "media-player", "remote-control", "ups", "bluetooth-generic", "laptop", "airpods"]) {
  assert.ok(Model.KIND_GLYPHS[k], k)
  assert.strictEqual([...Model.KIND_GLYPHS[k]].length, 1, k)
}
for (const name of Object.keys(Model.GLYPHS)) assert.strictEqual([...Model.GLYPHS[name]].length, 1, name)

// Every icon the model and the QML name exists in Pixels.js.
const pixelSource = fs.readFileSync(path.join(__dirname, "..", "Pixels.js"), "utf8").replace(/^\.pragma library\s*/, "")
const Pixels = new Function(pixelSource + "\nreturn icons")()
const modelSource = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const qml = ["BarWidget.qml", "Panel.qml", "BarIcon.qml"].map(f => fs.readFileSync(path.join(__dirname, "..", f), "utf8")).join("\n")
for (const m of (modelSource + qml).matchAll(/(?:icon|name): "([a-z0-9-]+)"/g)) assert.ok(Pixels[m[1]], "missing pixel icon " + m[1])
for (const k of Object.keys(Model.KIND_GLYPHS).concat(["toaster"])) assert.ok(Pixels[Model.kindPixel(k)], k)

// Contrast tells a usable red from a theme's muted one.
{
  const hex = h => ({ r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255 })
  assert.ok(Math.abs(Model.contrast(hex("#ffffff"), hex("#000000")) - 21) < 0.01)
  assert.ok(Model.contrast(hex("#565d60"), hex("#101315")) < 3.5, "Solitude's red")
  assert.ok(Model.contrast(hex("#ed8796"), hex("#24273a")) > 3.5, "a real red")
}


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
// Put away in the case they stay, at their last levels.
{
  const t0 = 1795000000
  const out = Object.assign({}, podsFresh, { left: { level: 80, charging: false, inEar: false }, right: { level: 70, charging: false, inEar: false } })
  const shutLid = Model.airpodsWithLastKnown(Object.assign({}, podsGone, { name: "AirPods" }), Model.airpodsWithLastKnown(out, null, t0), t0 + 60)
  assert.strictEqual(Model.airpodsShown(shutLid), true)
  assert.strictEqual(Model.airpodsStatus(shutLid), "In the case · last levels")
  assert.strictEqual(Model.podPartState("left", shutLid.left, t0 + 60), "in case · 1m ago")
  assert.strictEqual(Model.podPartState("case", shutLid["case"], t0 + 600), "closed · 10m ago")
}

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
assert.strictEqual(Model.barItems(state, opts).find(i => i.key === "laptop").icon, "laptop")
assert.strictEqual(Model.barItems(state, opts).find(i => i.key === "airpods").icon, "airpods")
// The wave shows while on a charger, charging or not; a low mouse goes urgent.
const barLaptop = lap => Model.barItems(Object.assign({}, state, { laptop: lap }), opts).find(i => i.key === "laptop")
assert.strictEqual(barLaptop(charging).powered, true)
assert.strictEqual(barLaptop(Object.assign({}, onBattery, { status: "held", acOnline: true })).powered, true)
assert.strictEqual(barLaptop(Object.assign({}, onBattery, { status: "full", level: 100, acOnline: true })).powered, true)
assert.strictEqual(barLaptop(onBattery).powered, false)
// Held at a limit on the charger: powered, but no charge flows, so the band holds still.
assert.strictEqual(barLaptop(Object.assign({}, onBattery, { status: "held", acOnline: true })).charging, false)
assert.strictEqual(barLaptop(charging).charging, true)
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
  assert.deepStrictEqual(Model.chargeStep(0), { flow: 0, wait: 134 })
  assert.deepStrictEqual(Model.chargeStep(140), { flow: 1 / 15, wait: 127 })
  assert.deepStrictEqual(Model.chargeStep(4140), Model.chargeStep(140))
  assert.deepStrictEqual(Model.chargeStep(2000), { flow: 1, wait: 2000 })
  assert.deepStrictEqual(Model.chargeStep(3999), { flow: 1, wait: 1 })
  // Walking the waits lands on every step once, each a whole cell of the
  // band's travel, and never stalls.
  let now = 0, moves = 0, last = -1
  while (now < 4000) {
    const step = Model.chargeStep(now)
    assert.ok(step.wait >= 1)
    assert.ok(step.flow > last)
    assert.ok(Number.isInteger(Math.round(step.flow * 15 * 1e9) / 1e9), "a whole cell: " + step.flow)
    last = step.flow
    moves++
    now += step.wait
  }
  assert.strictEqual(moves, 16)
}


// The AirPods icon waves while any part charges, not only the bud it shows.
{
  const pods = over => Model.barItems(Object.assign({}, state, { airpods: Object.assign({}, podsFresh, over) }), opts).find(i => i.key === "airpods").powered
  const idle = { charging: false, inEar: true }
  assert.strictEqual(pods({ left: Object.assign({ level: 9 }, idle), right: { level: 13, charging: true, inEar: false }, case: { level: 30, charging: false }, level: 9 }), true)
  assert.strictEqual(pods({ left: Object.assign({ level: 9 }, idle), right: Object.assign({ level: 13 }, idle), case: { level: 30, charging: true } }), true)
  assert.strictEqual(pods({ left: Object.assign({ level: 9 }, idle), right: Object.assign({ level: 13 }, idle), case: { level: 30, charging: false } }), false)
  assert.strictEqual(Model.airpodsPowered({ isHeadset: true, headset: { level: 50, charging: true }, charging: true }), true)
  assert.strictEqual(Model.airpodsPowered(null), false)
}

// One bud in an ear, the other in the closed case: librepods drops the case
// and that bud, and the panel keeps their last levels, each marked stale.
{
  const t0 = 1000000
  const seen = Model.airpodsWithLastKnown(podsFresh, null, t0)
  assert.strictEqual(seen.left.seenAt, t0)
  const oneOut = Object.assign({}, podsFresh, { right: null, case: null, level: 80 })
  const later = Model.airpodsWithLastKnown(oneOut, seen, t0 + 600)
  assert.strictEqual(later.stale, false)
  assert.strictEqual(later.left.stale, false)
  assert.strictEqual(later.left.seenAt, t0 + 600)
  assert.strictEqual(later.right.level, 70)
  assert.strictEqual(later.right.stale, true)
  assert.strictEqual(later.right.inEar, false)
  assert.strictEqual(later.right.seenAt, t0)
  assert.strictEqual(later["case"].level, 50)
  assert.strictEqual(later["case"].charging, false)
  assert.strictEqual(later.level, 80)
  assert.strictEqual(Model.airpodsStatus(later), "Connected · in one ear · right bud in the case")
  assert.strictEqual(Model.podPartState("right", later.right, t0 + 900), "in case · 15m ago")
  assert.strictEqual(Model.podPartState("case", later["case"], t0 + 7300), "closed · 2h ago")
  assert.strictEqual(Model.podPartState("left", later.left, t0 + 600), "in ear")
  assert.strictEqual(Model.podPartState("case", null, t0), "not seen")
  // A remembered part keeps the time it was last seen, poll after poll.
  assert.strictEqual(Model.airpodsWithLastKnown(oneOut, later, t0 + 1200).right.seenAt, t0)
  // Remembered parts stay out of the bar and the caption: only what answers counts.
  const caseOn = Object.assign({}, opts, { airpodsCase: true })
  assert.ok(!Model.barItems(Object.assign({}, state, { airpods: later }), caseOn).some(i => i.key === "airpods-case"))
  assert.strictEqual(Model.barItems(Object.assign({}, state, { airpods: later }), caseOn).find(i => i.key === "airpods").text, "80%")
  const lowCase = Object.assign({}, later, { "case": Object.assign({}, later["case"], { level: 5 }) })
  assert.ok(!Model.heroPhrases({ airpods: lowCase, devices: [] }, 15)[0].includes("case"))
  assert.ok(Model.tooltip({ airpods: later, devices: [] }).includes("Right 70% (last seen)"))
  // Other AirPods do not inherit these levels.
  assert.strictEqual(Model.airpodsWithLastKnown(Object.assign({}, oneOut, { name: "Other" }), later, t0).right, null)
  // Both buds in the case and the case shut: everything is last seen.
  const allGone = Model.airpodsWithLastKnown(podsGone, later, t0 + 2000)
  assert.strictEqual(allGone.stale, true)
  assert.strictEqual(allGone.level, 80)
}
// Both buds in ears: the case is out of their reach, so what they report for
// it (charging, from when they left it) is last seen, not live.
{
  const t0 = 2000000
  const worn = Model.airpodsWithLastKnown(podsFresh, null, t0)
  assert.strictEqual(worn["case"].stale, true)
  assert.strictEqual(worn["case"].charging, false)
  assert.strictEqual(worn["case"].level, 50)
  assert.strictEqual(Model.podPartState("case", worn["case"], t0 + 300), "closed · 5m ago")
  assert.strictEqual(Model.airpodsPowered(worn), false)
  // One bud out of its ear (in the open case, or about to be): the case is live.
  const out = Object.assign({}, podsFresh, { right: { level: 70, charging: true, inEar: false } })
  const open = Model.airpodsWithLastKnown(out, worn, t0 + 600)
  assert.strictEqual(open["case"].stale, false)
  assert.strictEqual(open["case"].charging, true)
  // Back in both ears: the case keeps the time it was last live.
  const back = Model.airpodsWithLastKnown(podsFresh, open, t0 + 900)
  assert.strictEqual(back["case"].stale, true)
  assert.strictEqual(back["case"].seenAt, t0 + 600)
  const caseOn = Object.assign({}, opts, { airpodsCase: true })
  assert.ok(!Model.barItems(Object.assign({}, state, { airpods: back }), caseOn).some(i => i.key === "airpods-case"))
  // A headset has no case to lose.
  const headset = Model.airpodsWithLastKnown({ name: "Max", isHeadset: true, headset: { level: 60, charging: false }, left: null, right: null, case: null, level: 60 }, null, t0)
  assert.strictEqual(headset.headset.stale, false)
}
assert.strictEqual(Model.ago(30), "just now")
assert.strictEqual(Model.ago(59 * 60), "59m ago")
assert.strictEqual(Model.ago(3 * 86400 + 5), "3d ago")

// Tones come from the theme's palette by kind.
assert.strictEqual(Model.kindTone("laptop"), "blue")
assert.strictEqual(Model.kindTone("mouse"), "cyan")
assert.strictEqual(Model.kindTone("airpods"), "magenta")
assert.strictEqual(Model.kindTone("whatever"), "green")
assert.deepStrictEqual(Model.parsePalette('mode = "dark"\nred = "#565d60"\n  blue="#798186"\nhyprland_active_border = "rgba(798186ee)"'), { red: "#565d60", blue: "#798186" })

// Block digits: three rows, three columns a digit, one space between.
assert.deepStrictEqual(Model.bigDigits("80"), ["█▀█ █▀█", "█▀█ █ █", "▀▀▀ ▀▀▀"])
assert.deepStrictEqual(Model.bigDigits("x"), ["   ", "▀▀▀", "   "])
for (const d of "0123456789") assert.ok(Model.bigDigits(d).every(r => [...r].length === 3), d)

// A battery's cells: a tenth each, filled to the level.
{
  const fills = o => Model.batteryCells(Object.assign({ segments: 10 }, o)).map(c => Math.round(c.fill * 100) / 100)
  assert.deepStrictEqual(fills({ level: 28 }), [1, 1, 0.8, 0, 0, 0, 0, 0, 0, 0])
  assert.deepStrictEqual(fills({ level: 100 }), [1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
  assert.deepStrictEqual(fills({ level: null }), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
  assert.deepStrictEqual(Model.batteryCells({ segments: 5, level: 50 }).map(c => c.fill), [1, 1, 0.5, 0, 0])
  // At rest nothing glows, breathes or gives.
  assert.ok(Model.batteryCells({ segments: 10, level: 60, t: 500 }).every(c => c.glow === 0 && c.next === 0 && c.press === 0))
  // While charging, the cell being filled breathes and a pulse runs through the fill.
  const charging = t => Model.batteryCells({ segments: 10, level: 28, charging: true, t: t })
  assert.ok(charging(550).findIndex(c => c.next > 0) === 2)
  assert.ok([100, 400, 700, 1000].some(t => charging(t).some(c => c.glow > 0)))
  assert.ok(charging(400).slice(3).every(c => c.glow === 0))
  // Full and charging: nothing left to breathe.
  assert.ok(Model.batteryCells({ segments: 10, level: 100, charging: true, t: 550 }).every(c => c.next === 0))
  // The pointer presses the cells under it, most in the middle.
  const dent = Model.batteryCells({ segments: 10, level: 50, dent: 0.45 })
  assert.strictEqual(dent[4].press, 1)
  assert.ok(dent[3].press > 0 && dent[3].press < 1)
  assert.strictEqual(dent[0].press, 0)
  // A ripple lights a ring that travels out and fades.
  const ring = age => Model.batteryCells({ segments: 10, level: 10, ripples: [{ x: 0.05, age: age }] }).map(c => c.glow)
  assert.ok(ring(0)[0] > 0.5)
  assert.ok(ring(300).indexOf(Math.max(...ring(300))) > 3)
  assert.ok(ring(5000).every(g => g === 0))
}

// Decoding text keeps its length, spaces and separators, and ends as the text.
{
  const line = "Charging · 33m to 90%"
  const mid = Model.scramble(line, 0.4, 3)
  assert.strictEqual(mid.length, line.length)
  assert.ok(mid.startsWith(line.slice(0, Math.floor(0.4 * line.length))))
  assert.strictEqual(mid.charAt(9), "·")
  assert.strictEqual(mid.split(" ").length, line.split(" ").length)
  assert.notStrictEqual(mid, line)
  assert.strictEqual(Model.scramble(line, 1, 3), line)
  assert.strictEqual(Model.scramble("", 0.5, 1), "")
}

// An opened room offers its own bar switches.
{
  const picks = Model.barPicks({ laptop: onBattery, airpods: podsFresh, devices: [wireless] })
  assert.deepStrictEqual(Model.roomPicks(picks, "laptop").map(p => p.key), ["barLaptop", "barLaptopRate", "barLaptopTime"])
  assert.deepStrictEqual(Model.roomPicks(picks, "airpods").map(p => p.key), ["barAirpods", "barAirpodsCase"])
  assert.deepStrictEqual(Model.roomPicks(picks, wireless.id).map(p => p.device.id), [wireless.id])
  assert.ok(picks.every(p => p.inRoom.includes("in the bar")))
  assert.deepStrictEqual(Model.roomPicks(picks, "nothing"), [])
}

// A device room's details say what it is and what reads it.
assert.deepStrictEqual(Model.deviceFacts(Object.assign({}, wireless, { source: "glorious" })), [
  { label: "State", value: "On battery" },
  { label: "Link", value: "2.4 GHz" },
  { label: "Kind", value: "Mouse" },
  { label: "Read by", value: "Glorious dongle" }
])
assert.ok(Model.deviceFacts(Object.assign({}, wireless, { source: "upower" })).some(f => f.value === "UPower"))
assert.ok(Model.deviceFacts(Object.assign({}, wireless, { stale: true })).some(f => f.value === "last one seen"))
assert.deepStrictEqual(Model.airpodsFacts(podsFresh)[0], { label: "Model", value: "AirPods Pro 2 (USB-C)" })

// Marks are icons from the bar's own set.
assert.strictEqual(Model.markIcon({ level: 10, charging: false }, 20), "battery-low")
assert.strictEqual(Model.markIcon({ level: 10, charging: true }, 20), "zap")
assert.strictEqual(Model.markIcon({ level: 90, charging: false, acOnline: true }, 20), "plug")
assert.strictEqual(Model.markIcon({ level: 90, charging: true, stale: true }, 20), "")
assert.strictEqual(Model.markIcon(null, 20), "")
// The panel's pixel icons: every kind, mark and kit glyph has one.
{
  const pixelSource = fs.readFileSync(path.join(__dirname, "..", "Pixels.js"), "utf8").replace(/^\.pragma library\s*/, "")
  const Pixels = new Function(pixelSource + "\nreturn icons")()
  for (const name of ["battery-low", "zap", "plug", "chevron-down", "airpods", "airpods-case"]) assert.ok(Pixels[name], "missing pixel icon " + name)
  for (const kind of Object.keys(Model.KIND_GLYPHS)) assert.ok(Pixels[Model.kindPixel(kind)], "no pixel icon for " + kind)
  for (const key of Object.keys(Model.GLYPHS)) assert.ok(Pixels[Model.pixelFor(Model.GLYPHS[key])], "no pixel icon for GLYPHS." + key)
  assert.ok(Pixels[Model.pixelFor("\u{F012C}")], "the updater's done")
  assert.strictEqual(Model.pixelFor("x"), "")
  // The still base and the parts that move (Motion.js) on the grid.
  for (const [name, art] of Object.entries(Pixels)) {
    const g24 = art.g24.concat(...(art.parts || []).map(p => p.g24))
    const g12 = art.g12.concat(...(art.parts || []).map(p => p.g12))
    assert.ok(g24.every(r => r.every(v => Number.isInteger(v)) && r[0] + r[2] <= 24 && r[1] + r[3] <= 24), name)
    assert.ok(g12.length > 0 && g12.every(r => r[0] + r[2] <= 12 && r[1] + r[3] <= 12), name)
  }
  // Panel.qml names its pixel icons outright; each must exist.
  const panel = fs.readFileSync(path.join(__dirname, "..", "Panel.qml"), "utf8")
  for (const m of panel.matchAll(/(?:pixel|icon): "([a-z0-9-]+)"/g)) assert.ok(Pixels[m[1]], "missing pixel icon " + m[1])
}

// The bar's pixel type: the panel's digits a column wider, the %, and the
// letters it writes.
{
  for (const ch of "023456789") {
    const rows = Model.bigDigits(ch)
    const glyph = Model.PIXEL_FONT[ch]
    assert.strictEqual(glyph.length, 5, ch)
    assert.ok(glyph.every(r => r.length === 4), ch)
    // Drop the doubled column and it is the face: each cell a half row, █ and
    // ▀ lighting the top, █ and ▄ the bottom.
    const narrow = glyph.map(r => r[0] + r[1] + r[3])
    for (let c = 0; c < 3; c++) {
      assert.strictEqual(narrow[0][c] === "#", "█▀".includes(rows[0][c]), ch)
      assert.strictEqual(narrow[3][c] === "#", "█▄".includes(rows[1][c]), ch)
    }
    // The inside of every digit is two pixels wide where it has one.
    assert.ok(glyph.every(r => r[1] === r[2]), ch)
  }
  // The sevens and fours reach the baseline like every other digit.
  assert.strictEqual(Model.PIXEL_FONT["4"][4], "...#")
  assert.strictEqual(Model.PIXEL_FONT["7"][4], "...#")
  const line = Model.pixelText("72%")
  assert.strictEqual(line.width, 4 + 1 + 4 + 1 + 5)
  assert.strictEqual(line.height, 5)
  assert.ok(line.rects.every(r => r[0] + r[2] <= line.width && r[1] < 5))
  // What the bar can write, it can draw.
  for (const text of ["12 W", "6.4 W", "3h 05m", "45m", "zZ", "--", "100%"]) {
    for (const ch of text) assert.ok(Model.PIXEL_FONT[ch], "no pixel glyph for " + JSON.stringify(ch))
  }
}

// Room tones: the theme's colour when it is one, the kind's own hue where the
// theme's is a grey, softened toward the text either way.
{
  const fg = "#cacccc"
  const solitude = Model.roomToneHex("blue", { blue: "#798186" }, fg)
  const tokyo = Model.roomToneHex("blue", { blue: "#7aa2f7" }, "#c0caf5")
  assert.notStrictEqual(solitude, "#798186")
  assert.ok(/^#[0-9a-f]{6}$/.test(solitude) && /^#[0-9a-f]{6}$/.test(tokyo))
  // Solitude's grey blue gives way to a real blue: more blue than red.
  assert.ok(parseInt(solitude.slice(5, 7), 16) > parseInt(solitude.slice(1, 3), 16) + 40, solitude)
  // A themed colour keeps its own hue.
  assert.ok(parseInt(tokyo.slice(5, 7), 16) > parseInt(tokyo.slice(1, 3), 16), tokyo)
  assert.ok(/^#[0-9a-f]{6}$/.test(Model.roomToneHex("magenta", {}, fg)))
  assert.ok(/^#[0-9a-f]{6}$/.test(Model.roomToneHex("nothing", null, "bad")))
}

// The bar's hover card: a line per battery, a part of the AirPods each.
{
  const t0 = 2000000
  const seen = Model.airpodsWithLastKnown(podsFresh, null, t0)
  const oneOut = Model.airpodsWithLastKnown(Object.assign({}, podsFresh, { right: null, case: null, level: 80 }), seen, t0 + 600)
  const rows = Model.hoverRows({ laptop: onBattery, airpods: oneOut, devices: [wireless] }, t0 + 900)
  assert.deepStrictEqual(rows.map(r => r.key), ["laptop", "airpods-left", "airpods-right", "airpods-case", wireless.id])
  assert.deepStrictEqual(rows.map(r => r.icon), ["laptop", "airpods", "airpods", "airpods-case", "mouse"])
  const right = rows.find(r => r.key === "airpods-right")
  assert.strictEqual(right.stale, true)
  assert.strictEqual(right.note, "in case 15m")
  assert.strictEqual(rows.find(r => r.key === "airpods-case").note, "closed 15m")
  assert.strictEqual(rows.find(r => r.key === "airpods-left").note, "")
  assert.strictEqual(rows[0].tone, "blue")
  assert.deepStrictEqual(rows.slice(1, 4).map(r => r.name), ["Left", "Right", "Case"])
  // AirPods that are not connected stay out, as in the panel.
  assert.ok(!Model.hoverRows({ airpods: Object.assign({}, oneOut, { connected: false }), devices: [] }).length)
  // A device asleep with no level still gets its line.
  assert.strictEqual(Model.hoverRows({ devices: [asleep] })[0].note, "asleep")
  assert.deepStrictEqual(Model.hoverRows(null), [])
}

// The prompt lays out the whole line from the first character, the rest
// drawn clear, so nothing reflows as it types.
{
  const clear = s => '<font color="#00000000">' + s + "</font>"
  assert.strictEqual(Model.revealLine("Abc de", 0, true), "_" + clear("bc de_"))
  assert.strictEqual(Model.revealLine("Abc de", 3, true), "Abc " + clear("de_"))
  assert.strictEqual(Model.revealLine("Abc de", 6, true), "Abc de_")
  assert.strictEqual(Model.revealLine("Abc de", 6, false), "Abc de" + clear("_"))
  // Every state lays out the same characters.
  for (let n = 0; n <= 6; n++) {
    const plain = Model.revealLine("Abc de", n, n % 2 === 0).replace(/<[^>]+>/g, "")
    assert.strictEqual(plain.length, 7, "state " + n)
  }
  assert.strictEqual(Model.revealLine("<a & b>", 7, true), "&lt;a &amp; b&gt;_")
  assert.strictEqual(Model.revealLine(null, 3, true), "_")
}

// A reading wraps between its pieces, never inside one.
{
  const nb = "\u00A0"
  assert.strictEqual(Model.keepTogether("JBL Charge 5 · On battery · Bluetooth"), "JBL Charge 5" + nb + "· On battery" + nb + "· Bluetooth")
  assert.strictEqual(Model.keepTogether("Charging · 2h 00m to 90%"), "Charging" + nb + "· 2h" + nb + "00m to 90%")
  assert.strictEqual(Model.keepTogether("18 W"), "18" + nb + "W")
  assert.strictEqual(Model.keepTogether("closed · just now"), "closed" + nb + "· just" + nb + "now")
  assert.strictEqual(Model.keepTogether("Glorious Model O Wireless"), "Glorious Model O Wireless")
  assert.strictEqual(Model.keepTogether(null), "")
  // Decoding keeps them too.
  assert.strictEqual(Model.scramble("a" + nb + "b", 0, 1).charAt(1), nb)
}

console.log("model tests passed")

// A low-battery alert as a notification, and what became of it.
{
  const mouse = { id: "hid-1", name: "Glorious Model O", kind: "mouse", level: 12, charging: false, stale: false }
  const note = Model.alertNote(mouse)
  assert.strictEqual(note.key, "hid-1")
  assert.strictEqual(note.title, "Mouse battery low")
  assert.strictEqual(note.body, "Glorious Model O is at 12%. Plug it in.")
  assert.strictEqual(note.chargingTitle, "Mouse charging")
  assert.strictEqual(note.level, 12)
  assert.strictEqual(note.icon, Model.kindPixel("mouse"))
  assert.strictEqual(note.tone, Model.kindTone("mouse"))
  assert.strictEqual(Model.alertNote({ id: "airpods", name: "AirPods Pro", kind: "airpods", level: 9 }).title, "AirPods battery low")
  const at = devices => ({ laptop: null, airpods: null, devices })
  const watch = { key: "hid-1", level: 12, unknownSince: 0 }
  const step = (devices, w, now) => Model.alertStep(w || watch, at(devices), 20, now || 1000)
  const as = (o) => Object.assign({}, mouse, o)
  assert.strictEqual(step([mouse]).action, "wait")
  // Plugged in: charging, or on a cable at a level it does not call charging.
  assert.deepStrictEqual([step([as({ charging: true, level: 13 })]).action, step([as({ charging: true, level: 13 })]).level], ["thank", 13])
  assert.strictEqual(step([as({ powered: true })]).action, "thank")
  // A battery that never says it charges but climbs is plugged in too.
  assert.strictEqual(step([as({ level: 15 })]).action, "thank")
  assert.strictEqual(step([as({ level: 40 })]).action, "thank")
  assert.strictEqual(step([as({ level: 14 })]).action, "wait")
  // A reading that bounces over the line by itself takes the card down.
  assert.strictEqual(Model.alertStep(Object.assign({}, watch, { level: 20 }), at([as({ level: 21 })]), 20, 1000).action, "withdraw")
  // Out of reach or without a level: wait, then take it down after a while.
  const gone = step([as({ stale: true })], watch, 1000)
  assert.strictEqual(gone.action, "wait")
  assert.strictEqual(gone.watch.unknownSince, 1000)
  assert.strictEqual(step([], gone.watch, 1060).action, "wait")
  assert.strictEqual(step([], gone.watch, 1120).action, "withdraw")
  assert.strictEqual(step([as({ level: null })], watch, 1000).action, "wait")
  // Back with a reading, the clock starts over; back on its cable, thanks.
  assert.strictEqual(step([mouse], gone.watch, 1100).watch.unknownSince, 0)
  assert.strictEqual(step([as({ charging: true })], gone.watch, 1110).action, "thank")

  // AirPods charge in their case without saying so.
  const t0 = 1795000000
  const worn = Model.airpodsWithLastKnown({ name: "AirPods Pro", model: "AirPods Pro 2 (USB-C)", connected: true, isHeadset: false,
    left: { level: 10, charging: false, inEar: true }, right: { level: 12, charging: false, inEar: true }, case: null, headset: null,
    level: 10, charging: false, known: true }, null, t0)
  const podsWatch = { key: "airpods", level: 10, unknownSince: 0 }
  const podsStep = (pods, now) => Model.alertStep(podsWatch, { airpods: pods, devices: [] }, 15, now || t0)
  assert.strictEqual(podsStep(worn).action, "wait")
  const inCase = Model.airpodsWithLastKnown(Object.assign({}, worn, {
    left: { level: 10, charging: false, inEar: false }, right: { level: 12, charging: false, inEar: false }, case: { level: 96, charging: false } }), worn, t0 + 30)
  assert.strictEqual(podsStep(inCase).action, "thank")
  // Lid shut: librepods forgets them, name and all, and they are put away.
  const shut = { name: "AirPods", model: "", connected: false, isHeadset: false, left: null, right: null, case: null, headset: null, level: null, charging: false, known: false }
  const away = Model.airpodsWithLastKnown(shut, inCase, t0 + 60)
  assert.strictEqual(away.name, "AirPods Pro")
  assert.strictEqual(away.model, "AirPods Pro 2 (USB-C)")
  assert.strictEqual(away.stale, true)
  assert.strictEqual(away.left.level, 10)
  assert.strictEqual(Model.airpodsPutAway(away), true)
  assert.strictEqual(podsStep(away).action, "thank")
  // Walked off in someone's ears: not put away, so the card waits.
  const walked = Model.airpodsWithLastKnown(shut, worn, t0 + 60)
  assert.strictEqual(walked.known, true)
  assert.strictEqual(Model.airpodsPutAway(walked), false)
  assert.strictEqual(podsStep(walked, t0 + 60).action, "wait")
}
console.log("alert tests passed")

// The AirPods card: AirPods that connect, or a lid that opens, once.
{
  const off = { name: "AirPods Pro", connected: false, lidOpen: false }
  const on = Object.assign({}, off, { connected: true })
  const lid = Object.assign({}, off, { lidOpen: true })
  const now = 1000000
  assert.strictEqual(Model.airpodsArrival(off, on, now, 0), "connected")
  assert.strictEqual(Model.airpodsArrival(off, lid, now, 0), "opened")
  // Connected, then the lid: one card.
  assert.strictEqual(Model.airpodsArrival(lid, Object.assign({}, lid, { connected: true }), now, now - 2), "")
  assert.strictEqual(Model.airpodsArrival(off, on, now, now - Model.ARRIVAL_QUIET_S), "connected")
  // Already connected at start, or when the daemon comes back: quiet.
  assert.strictEqual(Model.airpodsArrival(null, on, now, 0), "")
  assert.strictEqual(Model.airpodsArrival(on, on, now, 0), "")
  assert.strictEqual(Model.airpodsArrival(on, off, now, 0), "")
  assert.strictEqual(Model.airpodsArrival(lid, lid, now, 0), "")

  // Ready once a part answers with a level.
  assert.strictEqual(Model.airpodsCardReady(null), false)
  assert.strictEqual(Model.airpodsCardReady({ left: null, right: null, "case": null }), false)
  assert.strictEqual(Model.airpodsCardReady({ left: { level: 40, stale: true } }), false)
  assert.strictEqual(Model.airpodsCardReady({ left: { level: 40, stale: false } }), true)

  assert.deepStrictEqual(Model.airpodsCardParts({ isHeadset: false }).map(p => p.key), ["left", "right", "case"])
  assert.deepStrictEqual(Model.airpodsCardParts({ isHeadset: true }).map(p => p.key), ["headset"])

  assert.strictEqual(Model.airpodsCardLine({ connected: false, known: false }, "opened"), "Case open · connecting")
  assert.strictEqual(Model.airpodsCardLine(Model.airpodsPreview(now), "connected"), "Connected · in both ears")
  assert.strictEqual(Model.airpodsCardReady(Model.airpodsPreview(now)), true)
}
