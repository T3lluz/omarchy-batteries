.pragma library

// Pure helpers for the widget, kept free of QML so tests/model.test.js can
// run them under node. Icons are names in Pixels.js (pixel art); the panel kit
// is handed Nerd Font glyphs, which Glyph.qml swaps for their pixel icons.


var CONNECTION_LABELS = { usb: "USB cable", wireless: "2.4 GHz", bluetooth: "Bluetooth" }

// The panel's glyphs, as escapes because a Nerd Font character is invisible in
// most editors. Material Design Icons in the Nerd Font.
var GLYPHS = {
  battery: "\u{F0079}",
  unknownBattery: "\u{F0091}",
  bolt: "\u{F140B}",
  plug: "\u{F06A5}",
  refresh: "\u{F0450}",
  gear: "\u{F0493}",
  back: "\u{F004D}",
  key: "\u{F0306}",
  alert: "\u{F0026}",
  barTop: "\u{F1513}",
  bell: "\u{F009A}",
  lowBattery: "\u{F0083}",
  percent: "\u{F03F0}",
  clock: "\u{F0954}",
  update: "\u{F06B0}",
  earbuds: "\u{F184F}",
  airpodsCase: "\u{F03D3}"
}

var KIND_GLYPHS = {
  "mouse": "\u{F037D}",
  "keyboard": "\u{F030C}",
  "headset": "\u{F02CE}",
  "headphones": "\u{F02CB}",
  "speakers": "\u{F04C3}",
  "gaming-input": "\u{F0297}",
  "touchpad": "\u{F0741}",
  "tablet": "\u{F04F6}",
  "pen": "\u{F03EB}",
  "phone": "\u{F011C}",
  "media-player": "\u{F075A}",
  "remote-control": "\u{F0454}",
  "ups": "\u{F010C}",
  "bluetooth-generic": "\u{F00AF}",
  "laptop": "\u{F0322}",
  "airpods": "\u{F184F}"
}

function kindGlyph(kind) {
  return KIND_GLYPHS[kind] || GLYPHS.battery
}

// Every icon, in the bar and the panel, is pixel art from Pixels.js
// (Pixelarticons, plus AirPods and their case drawn on the same grid). A
// kind's icon by name:
var KIND_PIXELS = {
  "mouse": "mouse",
  "keyboard": "keyboard",
  "headset": "headphone",
  "headphones": "headphone",
  "speakers": "volume-2",
  "gaming-input": "gamepad",
  "touchpad": "hand",
  "tablet": "tablet",
  "pen": "pencil",
  "phone": "smartphone",
  "media-player": "music",
  "remote-control": "tv",
  "ups": "power",
  "bluetooth-generic": "battery-medium",
  "laptop": "laptop",
  "airpods": "airpods"
}

function kindPixel(kind) {
  return KIND_PIXELS[kind] || "battery-medium"
}

// The Nerd Font glyphs the panel kit is handed (Model.GLYPHS, KIND_GLYPHS,
// the updater's), each with its pixel icon. Glyph.qml draws the pixel icon
// for any glyph listed here, so the kit's icons match the rooms'.
var PIXEL_GLYPHS = {}
;(function() {
  var byName = {
    battery: "battery-medium", unknownBattery: "battery", bolt: "zap", plug: "plug",
    refresh: "reload", gear: "settings-cog", back: "arrow-left", key: "key",
    alert: "warning-diamond", barTop: "layout", bell: "bell", lowBattery: "battery-low",
    percent: "percent", clock: "clock", update: "download", earbuds: "airpods",
    airpodsCase: "airpods-case"
  }
  for (var k in byName) PIXEL_GLYPHS[GLYPHS[k]] = byName[k]
  for (var kind in KIND_GLYPHS) PIXEL_GLYPHS[KIND_GLYPHS[kind]] = kindPixel(kind)
  // The updater's: updating and done.
  PIXEL_GLYPHS["\u{F06B0}"] = "download"
  PIXEL_GLYPHS["\u{F012C}"] = "check"
})()

function pixelFor(glyph) {
  return PIXEL_GLYPHS[glyph] || ""
}

// What a device is called in the panel: the model when the reader knows it
// (a JBL speaker renamed in the JBL app), else its name.
function deviceTitle(device) {
  return device ? device.model || device.name || "" : ""
}

// JBL speakers get their own panel section; everything else is a device.
function jblSpeakers(devices) {
  return (devices || []).filter(function(d) { return d.source === "jbl" })
}

function otherDevices(devices) {
  return (devices || []).filter(function(d) { return d.source !== "jbl" })
}

function kindLabel(kind) {
  if (kind === "gaming-input") return "Controller"
  if (kind === "ups") return "UPS"
  if (kind === "speakers") return "Speaker"
  if (!kind) return "Device"
  var s = String(kind).replace(/-/g, " ")
  return s.charAt(0).toUpperCase() + s.slice(1)
}

// A device's name where room is short: its kind, unless the kind says nothing.
function shortName(device) {
  var kind = device.kind
  return kind && kind !== "bluetooth-generic" && kind !== "unknown" ? kindLabel(kind) : deviceTitle(device)
}

function hasLevel(level) {
  return level !== null && level !== undefined
}

// Parses bin/batteries' JSON. Returns null when it is not that.
function parseProbe(text) {
  var data
  try { data = JSON.parse(String(text || "").trim()) } catch (e) { return null }
  if (!data || !Array.isArray(data.devices)) return null
  return {
    laptop: data.laptop && hasLevel(data.laptop.level) ? data.laptop : null,
    airpods: data.airpods && data.airpods.name ? data.airpods : null,
    devices: data.devices.filter(function(d) { return d && d.id }),
    needsAccess: Array.isArray(data.needsAccess) ? data.needsAccess : [],
    udevInstalled: data.udevInstalled === true
  }
}

function copy(o) {
  var out = {}
  for (var k in o) out[k] = o[k]
  return out
}

// A sleeping 2.4 GHz mouse answers without a level. Keep the last one seen
// so the bar does not blank every time it naps; `stale` marks it as such.
function withLastKnown(devices, previous) {
  var byId = {}
  for (var i = 0; i < (previous || []).length; i++) byId[previous[i].id] = previous[i]
  return devices.map(function(d) {
    var out = copy(d)
    out.stale = false
    var prev = byId[d.id]
    if (!hasLevel(out.level) && prev && hasLevel(prev.level)) {
      out.level = prev.level
      out.stale = true
    }
    return out
  })
}

var POD_PARTS = ["left", "right", "case", "headset"]

// A closed case takes its buds off the air: with one bud in an ear and the
// other in the case, librepods reports the worn bud alone and drops the case
// and the other bud. Each part keeps its last level, marked stale, with
// `seenAt` (unix seconds) saying when it last answered. When nothing answers
// at all, the whole set is stale.
function airpodsWithLastKnown(pods, previous, nowSec) {
  if (!pods) return null
  var now = nowSec || Date.now() / 1000
  var out = copy(pods)
  // With the case shut, librepods hears nothing and forgets the name too, so
  // a reading that knows nothing is the AirPods last seen, whatever it calls
  // them. Other AirPods that answer do not inherit these levels.
  var same = !!previous && (previous.name === pods.name || !pods.known)
  if (same && !pods.known) {
    out.name = previous.name
    out.model = previous.model || out.model
  }
  var fresh = 0, kept = 0
  // The buds hear the case only while one of them sits in it. With every bud
  // in an ear, what they report for the case is what it said when they left
  // it, charger and all, so the case is last seen rather than live.
  var caseAway = caseOutOfReach(pods)
  POD_PARTS.forEach(function(k) {
    if (k === "case" && caseAway) {
      var was = same && previous["case"] && hasLevel(previous["case"].level) ? previous["case"] : null
      out[k] = copy(pods[k])
      out[k].stale = true
      out[k].charging = false
      out[k].seenAt = was && was.seenAt ? was.seenAt : Math.round(now)
      kept++
    } else if (pods[k]) {
      out[k] = copy(pods[k])
      out[k].stale = false
      out[k].seenAt = Math.round(now)
      fresh++
    } else if (same && previous[k] && hasLevel(previous[k].level)) {
      out[k] = copy(previous[k])
      // Where it was when it went quiet: in an ear, or out (in the case).
      if (!previous[k].stale) out[k].lastInEar = previous[k].inEar === true
      out[k].stale = true
      out[k].charging = false
      out[k].inEar = false
      if (!out[k].seenAt) out[k].seenAt = Math.round(now)
      kept++
    } else {
      out[k] = null
    }
  })
  out.stale = fresh === 0 && kept > 0
  if (out.stale) {
    out.level = same && hasLevel(previous.level) ? previous.level : emptierBud(out)
    out.charging = false
  }
  out.known = fresh + kept > 0
  return out
}

// Put away: the AirPods went quiet in their case, lid shut. Nothing can be
// read through a shut lid (the buds and the case stop answering and stop
// broadcasting), so this is the last thing they said: every bud out of an
// ear, and the case heard as late as each of them. Worn buds hear the case
// only from when they left it, so AirPods that walked off in someone's ears
// fail the second test.
function airpodsPutAway(pods) {
  if (!pods || !pods.known || !pods.stale || pods.isHeadset) return false
  var pack = pods["case"]
  var buds = [pods.left, pods.right].filter(function(b) { return b && hasLevel(b.level) })
  if (!pack || !hasLevel(pack.level) || !buds.length) return false
  return buds.every(function(b) {
    return b.lastInEar === false && (pack.seenAt || 0) >= (b.seenAt || 0) - 5
  })
}

function caseOutOfReach(pods) {
  if (pods.isHeadset || !pods["case"]) return false
  var buds = [pods.left, pods.right].filter(Boolean)
  return buds.length > 0 && buds.every(function(b) { return b.inEar === true })
}

function emptierBud(pods) {
  var levels = [pods.left, pods.right, pods.headset].filter(function(p) { return p && hasLevel(p.level) }).map(function(p) { return p.level })
  return levels.length ? Math.min.apply(null, levels) : null
}

// "just now", "4m ago", "2h ago", "3d ago".
function ago(seconds) {
  if (!(seconds >= 60)) return "just now"
  if (seconds < 3600) return Math.floor(seconds / 60) + "m ago"
  if (seconds < 86400) return Math.floor(seconds / 3600) + "h ago"
  return Math.floor(seconds / 86400) + "d ago"
}

function percent(level) {
  return hasLevel(level) ? Math.round(level) + "%" : "--"
}

function duration(seconds) {
  if (!seconds || seconds <= 0) return ""
  var h = Math.floor(seconds / 3600)
  var m = Math.round((seconds % 3600) / 60)
  if (m === 60) { h += 1; m = 0 }
  if (h === 0) return m + "m"
  return h + "h " + (m < 10 ? "0" : "") + m + "m"
}

function watts(w) {
  if (!w) return "0 W"
  return (w >= 10 ? Math.round(w) : w.toFixed(1)) + " W"
}

function isLow(device, threshold) {
  return !!device && !device.charging && hasLevel(device.level) && device.level <= threshold
}

function statusText(device) {
  if (!device) return ""
  var s = device.status
  if (s === "charging") return hasLevel(device.level) ? "Charging" : "Charging (level unknown)"
  if (s === "full") return "Fully charged"
  if (s === "discharging") return device.stale ? "Last seen" : "On battery"
  if (s === "asleep") return "Asleep"
  if (s === "waking") return "Waking up"
  if (s === "offline") return "Not connected"
  if (s === "no-access") return "Needs access"
  return "Unknown"
}

function connectionText(device) {
  if (!device) return ""
  return CONNECTION_LABELS[device.connection] || ""
}

function subtitle(device) {
  var parts = [statusText(device)]
  // The title is the model, so the name given in the JBL app goes here.
  if (device && device.model && device.name && device.model !== device.name) parts.unshift(device.name)
  var conn = connectionText(device)
  if (conn) parts.push(conn)
  if (device && device.stale && device.status !== "discharging") parts.push("last level")
  return parts.join(" · ")
}

// Contrast between two colours ({r, g, b}, 0 to 1), by the WCAG formula. Themes
// may have a muted "red" (Solitude's is a dark grey), and low must never read
// quieter than normal.
function contrast(a, b) {
  function lum(c) {
    function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
  }
  var la = lum(a), lb = lum(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

// ------------------------------------------------------------------ laptop

function laptopStatus(lap) {
  if (!lap) return ""
  if (lap.status === "charging") {
    var toFull = duration(lap.timeToFull)
    return "Charging" + (toFull ? " · " + toFull + " to " + (lap.chargeLimit ? lap.chargeLimit + "%" : "full") : "")
  }
  if (lap.status === "discharging") {
    var left = duration(lap.timeToEmpty)
    return "On battery" + (left ? " · " + left + " left" : "")
  }
  if (lap.status === "full") return "Plugged in · fully charged"
  if (lap.status === "held") return "Plugged in · held at " + lap.chargeLimit + "% limit"
  if (lap.status === "plugged") return "Plugged in · not charging"
  return "Unknown"
}

// The laptop's readings, as label and value pairs: power in or out, health,
// the charge limit, cycles, stored energy, and the average drain on battery
// once there is one (null until then).
function laptopFacts(lap, drainPerHour) {
  if (!lap) return []
  var facts = [{ label: "Power", value: watts(lap.rateW) }]
  if (hasLevel(lap.health)) facts.push({ label: "Health", value: lap.health + "%" })
  if (lap.chargeLimit) facts.push({ label: "Limit", value: (lap.chargeStart ? lap.chargeStart + "–" : "") + lap.chargeLimit + "%" })
  if (lap.cycles) facts.push({ label: "Cycles", value: String(lap.cycles) })
  var energy = laptopEnergy(lap)
  if (energy) facts.push({ label: "Energy", value: energy })
  if (drainPerHour !== null && drainPerHour !== undefined)
    facts.push({ label: "Drain", value: drainRate(drainPerHour) })
  return facts
}

// What the pack holds now against what it holds full.
function laptopEnergy(lap) {
  if (!lap || !lap.energyFullWh) return ""
  return lap.energyWh + "/" + lap.energyFullWh + " Wh"
}

// ----------------------------------------------------------------- AirPods

function airpodsParts(pods) {
  if (!pods) return []
  if (pods.isHeadset) return [{ key: "headset", label: pods.model || "AirPods Max", icon: "airpods", pod: pods.headset }]
  return [
    { key: "left", label: "Left", icon: "airpods", pod: pods.left },
    { key: "right", label: "Right", icon: "airpods", pod: pods.right },
    { key: "case", label: "Case", icon: "airpods-case", pod: pods["case"] }
  ]
}

// The panel shows AirPods only while they are connected, the way a mouse
// that is switched off drops out of the device list.
// AirPods leave the panel when they disconnect, like any other device, but
// not when they were put away in their case: there their last levels are
// what there is to know.
function airpodsShown(pods) {
  return !!pods && (pods.connected === true || airpodsPutAway(pods))
}

function airpodsStatus(pods) {
  if (!pods) return ""
  if (pods.stale && !pods.connected && airpodsPutAway(pods)) return "In the case · last levels"
  if (pods.stale) return (pods.connected ? "Connected" : "Not connected") + " · last levels"
  if (pods.connected) {
    if (!pods.known) return "Connected · waiting for levels"
    var buds = [pods.left, pods.right]
    var inEar = buds.filter(function(p) { return p && !p.stale && p.inEar }).length
    var parts = ["Connected" + (inEar === 2 ? " · in both ears" : inEar === 1 ? " · in one ear" : "")]
    var cased = ["left", "right"].filter(function(k) { return pods[k] && pods[k].stale })
    if (cased.length === 2) parts.push("both buds in the case")
    else if (cased.length === 1) parts.push(cased[0] + " bud in the case")
    return parts.join(" · ")
  }
  return pods.known ? "In range, not connected" : "Not connected"
}

// The word under one part's level in the panel: what it is doing, or for a
// part that stopped answering, where it went and when it last answered.
function podPartState(key, pod, nowSec) {
  if (!pod || !hasLevel(pod.level)) return "not seen"
  var when = ago((nowSec || Date.now() / 1000) - (pod.seenAt || 0))
  if (pod.stale) return (key === "case" ? "closed · " : key === "headset" ? "asleep · " : "in case · ") + when
  if (pod.charging) return "charging"
  if (key === "case") return "lid open"
  if (key === "headset") return "on"
  return pod.inEar ? "in ear" : "out"
}

// ----------------------------------------------------- the panel's caption

// The caption under the panel's title changes the way Omarchy's own panels do:
// what needs attention holds still, and otherwise true readings take turns with
// a little flavour, chosen by what the laptop is doing.
var PHRASES = {
  charging: ["Hoarding electrons", "Topping up the tanks", "Soaking up watts"],
  discharging: ["Sipping electrons", "Stretching the juice", "Counting down coulombs"],
  idle: ["Counting electrons", "Weighing coulombs", "Taking pulses"]
}

// Every battery with a fresh reading, under a name short enough for the caption.
function freshBatteries(state) {
  var all = []
  if (!state) return all
  if (state.laptop && hasLevel(state.laptop.level)) all.push({ name: "Laptop", item: state.laptop })
  var pods = state.airpods
  if (pods && pods.known && !pods.stale) {
    // One battery in the count, at whichever is emptier: the buds or their case.
    var pack = pods["case"] && !pods["case"].stale ? pods["case"] : null
    var caseLower = !!pack && hasLevel(pack.level) && (!hasLevel(pods.level) || pack.level < pods.level)
    if (caseLower) all.push({ name: "AirPods case", item: pack })
    else if (hasLevel(pods.level)) all.push({ name: "AirPods", item: pods })
  }
  ;(state.devices || []).forEach(function(d) {
    if (hasLevel(d.level) && !d.stale) all.push({ name: shortName(d), item: d })
  })
  return all
}

function lowestOf(batteries) {
  return batteries.reduce(function(a, b) { return b.item.level < a.item.level ? b : a })
}

function laptopPhrase(lap) {
  if (!lap) return ""
  if (lap.status === "charging") {
    var toFull = duration(lap.timeToFull)
    return toFull ? (lap.chargeLimit ? "Laptop at " + lap.chargeLimit + "%" : "Laptop full") + " in " + toFull : "Laptop charging"
  }
  if (lap.status === "discharging") {
    var left = duration(lap.timeToEmpty)
    return left ? "Laptop has " + left + " left" : "Laptop on battery"
  }
  if (lap.status === "full") return "Laptop fully charged"
  if (lap.status === "held") return "Laptop held at " + lap.chargeLimit + "%"
  if (lap.status === "plugged") return "Laptop plugged in"
  return ""
}

// The lines the caption takes turns on; one line holds still.
function heroPhrases(state, threshold) {
  var all = freshBatteries(state)
  if (!all.length) {
    // Rows can still be on screen, asleep or holding a last level.
    var rows = !!state && (!!state.laptop || !!state.airpods || (state.devices || []).length > 0)
    return [rows ? "No fresh readings" : "No batteries found"]
  }

  var low = all.filter(function(b) { return isLow(b.item, threshold) })
  if (low.length) {
    var worst = lowestOf(low)
    return [(low.length > 1 ? low.length + " low, " + worst.name.toLowerCase() + " at " : worst.name + " low at ") + percent(worst.item.level)]
  }

  // A battery can sit under the threshold and not count as low while it charges,
  // and the first line must not claim otherwise.
  var under = all.filter(function(b) { return b.item.level <= threshold })
  var facts = under.length
    ? under.map(function(b) { return b.name + " charging at " + percent(b.item.level) })
    : [all.length === 1 ? "1 battery above " + threshold + "%" : all.length + " batteries above " + threshold + "%"]
  var lap = laptopPhrase(state.laptop)
  if (lap) facts.push(lap)
  if (all.length > 1) {
    var lowest = lowestOf(all)
    facts.push(lowest.name + " lowest at " + percent(lowest.item.level))
  }

  var status = state.laptop ? state.laptop.status : ""
  var flavour = status === "charging" ? PHRASES.charging : status === "discharging" ? PHRASES.discharging : PHRASES.idle
  var lines = []
  facts.forEach(function(fact, i) {
    lines.push(fact)
    lines.push(flavour[i % flavour.length])
  })
  return lines
}

// What the panel header's battery shows: whatever is low, else the laptop,
// else the emptiest battery there is.
function heroBattery(state, threshold) {
  var all = freshBatteries(state)
  if (!all.length) return { level: null, charging: false, low: false }
  var low = all.filter(function(b) { return isLow(b.item, threshold) })
  var pick = low.length ? lowestOf(low)
    : state.laptop && hasLevel(state.laptop.level) ? { item: state.laptop }
    : lowestOf(all)
  return { level: pick.item.level, charging: !!pick.item.charging, low: low.length > 0 }
}

// ---------------------------------------------------------------- the bar

// A saved barDevices value as a plain array of ids, or null for "not picked
// yet". The shell can hand a list over as a Qt sequence, which is array-like
// but fails Array.isArray; treating that as null threw the pick away.
function idList(value) {
  if (value === null || value === undefined || typeof value === "string") return null
  if (Array.isArray(value)) return value.slice()
  if (typeof value === "object" && typeof value.length === "number") {
    var out = []
    for (var i = 0; i < value.length; i++) out.push(String(value[i]))
    return out
  }
  return null
}

// The bar's peripherals: an explicit id list, or every mouse while the
// user has not picked any (`ids` null).
function inBar(device, ids) {
  if (ids === null || ids === undefined) return device.kind === "mouse"
  return ids.indexOf(device.id) !== -1
}

// Turns `id` on or off, starting from what auto mode showed.
function toggleBarDevice(ids, id, devices) {
  var list = ids === null || ids === undefined
    ? devices.filter(function(d) { return d.kind === "mouse" }).map(function(d) { return d.id })
    : ids.slice()
  var at = list.indexOf(id)
  if (at === -1) list.push(id)
  else list.splice(at, 1)
  return list
}

// One entry per thing shown in the bar, in order: peripherals, AirPods,
// then the laptop. `opts` mirrors the widget's settings.
// The bar picker's tiles, like ROG Deck's: { key, icon, label, hint,
// fallback } for the laptop and AirPods settings, and { device, icon, label,
// hint } for each peripheral, which is saved in barDevices instead.
function barPicks(state) {
  var picks = []
  var lap = state ? state.laptop : null
  if (lap) {
    picks.push({ key: "barLaptop", room: "laptop", inRoom: "Level in the bar", icon: kindGlyph("laptop"), label: "Laptop", hint: "Its level; charge flows up through the icon while plugged in", fallback: true })
    picks.push({ key: "barLaptopRate", room: "laptop", inRoom: "Power in the bar", icon: GLYPHS.bolt, label: "Laptop power", hint: "Watts going in or out", fallback: false })
    picks.push({ key: "barLaptopTime", room: "laptop", inRoom: "Time left in the bar", icon: GLYPHS.clock, label: "Laptop time", hint: "Time left, or time to full while charging", fallback: false })
  }
  var pods = state ? state.airpods : null
  if (airpodsShown(pods)) {
    picks.push({ key: "barAirpods", room: "airpods", inRoom: pods.isHeadset ? "Level in the bar" : "Emptier bud in the bar", icon: GLYPHS.earbuds, label: "AirPods", hint: (pods.name ? pods.name + ": " : "") + (pods.isHeadset ? "their level" : "the emptier bud") + ", while they are connected", fallback: true })
    if (!pods.isHeadset) picks.push({ key: "barAirpodsCase", room: "airpods", inRoom: "Case in the bar", icon: GLYPHS.airpodsCase, label: "AirPods case", hint: "While the case is open and in range", fallback: false })
  }
  var devices = (state && state.devices) || []
  devices.forEach(function(d) {
    // A half-width tile fits "Mouse", not a model. The model takes over when
    // two devices of a kind need telling apart, and the tooltip always names it.
    var alone = devices.filter(function(o) { return o.kind === d.kind }).length === 1
    picks.push({ device: d, room: d.id, inRoom: "Level in the bar", icon: kindGlyph(d.kind), label: alone ? shortName(d) : deviceTitle(d), hint: deviceTitle(d) + " · " + subtitle(d) })
  })
  return picks
}

// The picker header's reading: how many are on, or that the bar shows only
// the icon.
function barPickedText(count) {
  return count > 0 ? count + " SHOWN" : "ICON ONLY"
}

// The AirPods icon stands for buds and case together, so it shows the wave
// while any of them charges, not only the bud whose level it shows: a bud in
// the case charges while the other is in an ear.
function airpodsPowered(pods) {
  if (!pods) return false
  return !!(pods.charging || ["left", "right", "headset", "case"].some(function(k) { return pods[k] && pods[k].charging }))
}

function barItems(state, opts) {
  var items = []
  var t = opts.lowThreshold || 20
  var devices = state.devices || []
  for (var i = 0; i < devices.length; i++) {
    var d = devices[i]
    if (!inBar(d, opts.devices)) continue
    items.push({
      key: d.id,
      icon: kindPixel(d.kind),
      text: opts.percent ? (hasLevel(d.level) ? percent(d.level) : (d.status === "asleep" ? "zZ" : "--")) : "",
      powered: !!(d.powered || d.charging),
      charging: !!d.charging && !d.stale,
      tone: d.status === "no-access" ? "low" : isLow(d, t) && !d.stale ? "low" : (d.stale || !hasLevel(d.level)) ? "dim" : "normal"
    })
  }

  var pods = state.airpods
  // Only while there is a fresh reading: last-seen levels stay in the panel.
  if (pods && pods.known && !pods.stale) {
    if (opts.airpods && hasLevel(pods.level)) {
      items.push({
        key: "airpods",
        icon: "airpods",
        text: opts.percent ? percent(pods.level) : "",
        powered: airpodsPowered(pods),
        charging: airpodsPowered(pods),
        tone: isLow(pods, t) ? "low" : "normal"
      })
    }
    if (opts.airpodsCase && !pods.isHeadset && pods["case"] && !pods["case"].stale) {
      items.push({
        key: "airpods-case",
        icon: "airpods-case",
        text: opts.percent ? percent(pods["case"].level) : "",
        powered: !!pods["case"].charging,
        charging: !!pods["case"].charging,
        tone: "normal"
      })
    }
  }

  var lap = state.laptop
  if (lap) {
    if (opts.laptop) {
      items.push({
        key: "laptop",
        icon: "laptop",
        text: opts.percent ? percent(lap.level) : "",
        // Full or held at a charge limit still shows, so the charger is
        // visibly connected.
        powered: !!(lap.acOnline || lap.charging),
        charging: !!lap.charging,
        tone: isLow(lap, t) ? "low" : "normal"
      })
    }
    if (opts.laptopRate && lap.rateW > 0) {
      items.push({ key: "laptop-rate", icon: lap.charging ? "plug" : "zap", text: watts(lap.rateW), powered: false, charging: false, tone: "normal" })
    }
    if (opts.laptopTime && (lap.timeToEmpty || lap.timeToFull)) {
      items.push({ key: "laptop-time", icon: "clock", text: duration(lap.timeToEmpty || lap.timeToFull), powered: false, charging: false, tone: "normal" })
    }
  }
  return items
}

// ------------------------------------------------------------ notifications

// Ids of devices that just crossed below the threshold while on battery.
// `notified` maps id -> true for devices already warned; it resets once the
// device charges or climbs back above the threshold.
function lowBatteryAlerts(devices, threshold, notified) {
  var next = {}
  var alerts = []
  for (var i = 0; i < devices.length; i++) {
    var d = devices[i]
    if (d.stale) {
      if (notified[d.id]) next[d.id] = true
      continue
    }
    if (isLow(d, threshold)) {
      next[d.id] = true
      if (!notified[d.id]) alerts.push(d)
    }
  }
  return { alerts: alerts, notified: next }
}

// What low-battery alerts watch: every peripheral plus fresh AirPods. The
// laptop is left to Omarchy's own low-battery warning.
function alertables(state) {
  var list = (state.devices || []).slice()
  var pods = state.airpods
  if (pods && pods.known && !pods.stale && hasLevel(pods.level))
    list.push({ id: "airpods", name: pods.name, kind: "airpods", level: pods.level, charging: pods.charging, stale: false })
  return list
}

// A low-battery alert, sent as a real notification so it takes its place in
// the shell's stack, its history and Do Not Disturb. Its picture is a badge
// in the panel's look (`bin/batteries badge`): the room's icon over a small
// battery at the level, in the low colour.
function alertNote(device) {
  var label = device.kind === "airpods" ? "AirPods" : kindLabel(device.kind)
  var name = device.name || label
  return {
    key: String(device.id),
    icon: kindPixel(device.kind),
    tone: kindTone(device.kind),
    title: label + " battery low",
    body: name + " is at " + percent(device.level) + ". Plug it in.",
    level: hasLevel(device.level) ? Math.round(device.level) : 0,
    // What the same notification says once the device is plugged in.
    chargingTitle: label + " charging",
    chargingBody: name + " is charging. Thanks."
  }
}

// Points a battery must climb over its alert's level to count as plugged in.
// Not every battery says it charges: AirPods charging in their case report
// "not charging" while the buds climb, so the level is the proof.
var ALERT_RISE = 3
// How long an alert's battery may be out of reach or without a level before
// its notification is taken down. A mouse going over to its cable drops out
// for a poll or two while it enumerates.
var ALERT_GRACE_S = 120

// The battery an alert is about, as the alert sees it.
function alertTarget(key, state) {
  key = String(key)
  if (key === "airpods") {
    var pods = state && state.airpods
    if (!pods || !pods.known) return null
    var buds = [pods.left, pods.right, pods.headset].filter(function(p) { return p && !p.stale && hasLevel(p.level) })
    var shown = buds.length ? buds.reduce(function(a, b) { return b.level < a.level ? b : a }) : null
    var pack = pods["case"]
    // The emptier bud out of an ear while the case answers: it sits in the
    // case, which charges it whether or not the case is on a cable.
    var inCase = !pods.stale && !pods.isHeadset && !!shown && shown.inEar === false && !!pack && !pack.stale && hasLevel(pack.level)
    return {
      level: pods.level,
      stale: !!pods.stale,
      charging: !pods.stale && !!(pods.charging || (shown && shown.charging)) || inCase || airpodsPutAway(pods)
    }
  }
  var list = (state && state.devices) || []
  for (var i = 0; i < list.length; i++) {
    var d = list[i]
    if (String(d.id) !== key) continue
    return { level: d.level, stale: !!d.stale, charging: !d.stale && !!(d.charging || d.powered) }
  }
  return null
}

// What to do with a low-battery notification after a poll. `watch` is what
// its notice keeps: { key, level (when it went up), unknownSince }. Returns
// { action, level, watch }: "thank" once it is plugged in (charging, on a
// charger, put away in its case, or climbing), "withdraw" once it is back
// over the line by itself or has been out of reach for a while, else "wait".
function alertStep(watch, state, threshold, nowSec) {
  var next = copy(watch)
  var t = alertTarget(watch.key, state)
  if (t && t.charging) return { action: "thank", level: t.level, watch: next }
  var reading = !!t && !t.stale && hasLevel(t.level)
  if (!reading) {
    if (!next.unknownSince) next.unknownSince = nowSec
    return { action: nowSec - next.unknownSince >= ALERT_GRACE_S ? "withdraw" : "wait", level: null, watch: next }
  }
  next.unknownSince = 0
  if (hasLevel(watch.level) && t.level >= watch.level + ALERT_RISE) return { action: "thank", level: t.level, watch: next }
  if (t.level > threshold) return { action: "withdraw", level: t.level, watch: next }
  return { action: "wait", level: t.level, watch: next }
}

function tooltip(state) {
  var lines = []
  var lap = state.laptop
  if (lap) lines.push("Laptop  " + percent(lap.level) + "  " + laptopStatus(lap))
  var pods = state.airpods
  if (pods && pods.known) {
    var parts = airpodsParts(pods).map(function(p) {
      return p.label + " " + (p.pod ? percent(p.pod.level) + (p.pod.stale && !pods.stale ? " (last seen)" : "") : "--")
    })
    lines.push(pods.name + "  " + parts.join("  ") + (pods.stale ? " (last seen)" : ""))
  }
  var devices = state.devices || []
  for (var i = 0; i < devices.length; i++) {
    var d = devices[i]
    lines.push(d.name + "  " + percent(d.level) + (d.charging ? " charging" : "") + (d.stale ? " (last seen)" : ""))
  }
  return lines.length ? lines.join("\n") : "No batteries found"
}

// ---------------------------------------------------------------- history

// The laptop's level over time, behind the panel's average drain: [[unixSeconds, level,
// plugged in 0/1], ...], oldest first. A sample is kept every `gap` seconds,
// or sooner when the level or the power changes, for `keep` seconds.
//
// Plugged in rather than charging: held at a charge limit, the pack flips
// between charging and resting every minute or so and loses a percent each
// time, which read as hard drain on battery.
var HISTORY_GAP = 120
var HISTORY_KEEP = 24 * 3600
var HISTORY_VERSION = 2

function parseHistory(text) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return [] }
  var list = data && Array.isArray(data.samples) ? data.samples : []
  list = list.filter(function(s) {
    return Array.isArray(s) && s.length >= 3 && isFinite(s[0]) && isFinite(s[1]) && s[1] >= 0 && s[1] <= 100
  }).map(function(s) { return [Math.round(s[0]), Math.round(s[1]), s[2] ? 1 : 0] })
  if ((data.version || 1) >= HISTORY_VERSION) return list
  // Version 1 kept charging. A resting sample within ten minutes of a
  // charging one was the pack held at its limit, so plugged in.
  return list.map(function(s) {
    if (s[2]) return s
    var near = list.some(function(o) { return o[2] && Math.abs(o[0] - s[0]) <= 600 })
    return near ? [s[0], s[1], 1] : s
  })
}

function serializeHistory(history) {
  return JSON.stringify({ version: HISTORY_VERSION, samples: history || [] }) + "\n"
}

function pushLevelSample(history, nowSec, level, plugged) {
  var list = (history || []).filter(function(s) { return nowSec - s[0] <= HISTORY_KEEP && s[0] <= nowSec })
  if (!hasLevel(level)) return list
  var sample = [Math.round(nowSec), Math.round(level), plugged ? 1 : 0]
  var last = list.length ? list[list.length - 1] : null
  if (last && sample[0] - last[0] < HISTORY_GAP && last[1] === sample[1] && last[2] === sample[2]) return list
  list.push(sample)
  return list
}

function historySince(history, nowSec, hours) {
  var from = nowSec - hours * 3600
  return (history || []).filter(function(s) { return s[0] >= from })
}

// Average drain on battery over the window, in % per hour, from the runs of
// unplugged samples (a gap over 15 minutes, a suspend, ends a run). Null
// until half an hour on battery has been seen.
function drainPerHour(history, nowSec, hours) {
  var list = historySince(history, nowSec, hours)
  var dropped = 0, seconds = 0
  for (var i = 1; i < list.length; i++) {
    var a = list[i - 1], b = list[i]
    if (a[2] || b[2] || b[0] - a[0] > 900 || b[1] > a[1]) continue
    dropped += a[1] - b[1]
    seconds += b[0] - a[0]
  }
  if (seconds < 1800) return null
  return dropped / (seconds / 3600)
}

function drainRate(perHour) {
  if (perHour === null || perHour === undefined) return ""
  return (perHour >= 10 ? Math.round(perHour) : Math.round(perHour * 10) / 10) + "%/h"
}

// How a charging icon moves: one soft dark band rises through it, then it rests.
// Each move repaints the whole window it sits in and makes the compositor draw
// that window again, so what costs is moves per second, and the rest costs
// nothing. Worked out from the clock rather than counted, so every monitor and
// the panel move together and a window never repaints twice for one step.
var CHARGE_CYCLE_MS = 4000
var CHARGE_SWEEP_MS = 2000
// How much of the icon still shows at the middle of the band.
var CHARGE_BAND_ALPHA = 0.3
// The band is three cells of the icon's twelve, so it takes fifteen steps to
// go from below the drawing to above it: a step a cell. Fewer steps than that
// stuttered, some moving the band and some not.
var CHARGE_BAND_CELLS = 3
var CHARGE_STEPS = 12 + CHARGE_BAND_CELLS
// Where the band holds still: on a charger but full or held at a limit, or
// with reduced motion. Over the middle of the drawing.
var CHARGE_HOLD_FLOW = 7 / CHARGE_STEPS

// `flow` runs from 0 (band below the drawing) to 1 (band above it, at rest),
// in CHARGE_STEPS steps. `wait` is how many ms until it next changes.
function chargeStep(now) {
  var t = ((now % CHARGE_CYCLE_MS) + CHARGE_CYCLE_MS) % CHARGE_CYCLE_MS
  if (t >= CHARGE_SWEEP_MS) return { flow: 1, wait: CHARGE_CYCLE_MS - t }
  var k = Math.floor(t * CHARGE_STEPS / CHARGE_SWEEP_MS)
  var next = Math.ceil((k + 1) * CHARGE_SWEEP_MS / CHARGE_STEPS)
  return { flow: k / CHARGE_STEPS, wait: Math.max(1, next - t) }
}

// ------------------------------------------------------------- ASCII panel

// Each battery's room takes a tone from the theme's terminal palette
// (colors.toml), one per kind of thing, the way DailyDash gives each health
// category one colour: power, audio, input, play and phones.
var KIND_TONES = {
  "laptop": "blue",
  "ups": "blue",
  "airpods": "magenta",
  "headset": "magenta",
  "headphones": "magenta",
  "speakers": "magenta",
  "media-player": "magenta",
  "mouse": "cyan",
  "keyboard": "cyan",
  "touchpad": "cyan",
  "pen": "cyan",
  "remote-control": "cyan",
  "gaming-input": "green",
  "phone": "yellow",
  "tablet": "yellow"
}

function kindTone(kind) {
  return KIND_TONES[kind] || "green"
}

// The named colours in a theme's colors.toml: { red: "#565d60", ... }.
function parsePalette(text) {
  var out = {}
  String(text || "").split("\n").forEach(function(line) {
    var m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (m) out[m[1]] = m[2]
  })
  return out
}

// Levels in a three-row block face, as seven segments: the top and the middle
// bar ride the upper half of their row, so the digit sits two and a half rows
// tall. Returns the three rows; anything unknown is a dash.
var SEGMENTS = {
  "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fbgc",
  "5": "afgcd", "6": "afgecd", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g"
}

// A one on the right-hand segments alone reads as a stray bar beside its
// neighbour, so it stands in the middle on a foot.
var BIG_ONE = ["\u2580\u2588 ", " \u2588 ", "\u2580\u2580\u2580"]

function bigDigits(text) {
  var rows = ["", "", ""]
  String(text).split("").forEach(function(ch, i) {
    var gap = i > 0 ? " " : ""
    if (ch === "1") {
      for (var r = 0; r < 3; r++) rows[r] += gap + BIG_ONE[r]
      return
    }
    var s = SEGMENTS[ch] === undefined ? SEGMENTS["-"] : SEGMENTS[ch]
    function on(seg) { return s.indexOf(seg) !== -1 }
    rows[0] += gap + (on("f") ? "█" : on("a") ? "▀" : " ") + (on("a") ? "▀" : " ") + (on("b") ? "█" : on("a") ? "▀" : " ")
    rows[1] += gap + (on("e") ? "█" : on("g") ? "▀" : " ") + (on("g") ? "▀" : " ") + (on("c") ? "█" : on("g") ? "▀" : " ")
    // Without a bottom bar (4, 7) the sides still reach the baseline.
    rows[2] += gap + (on("d") ? "▀▀▀" : (on("e") ? "▀" : " ") + " " + (on("c") ? "▀" : " "))
  })
  return rows
}

// A battery drawn as a body of cells, the way a phone draws one: ten cells
// for a tenth each, so the level can be counted at a glance. For each cell,
// how full it is (0..1), how lit (`glow`, 0..1: charge running through it or
// a ripple passing), how far the pointer presses it (`press`, 0..1) and, for
// the cell charging now, how bright its empty part breathes (`next`, 0..1).
//
// opts: segments, level (0..100, fractional while it fills in), t (ms, the
// panel's clock), charging, dent (0..1 across the body, where the pointer
// is) and ripples ([{ x, age }], x 0..1 across, age in ms).
var BATTERY = {
  FLOW_MS: 1600,       // a pulse of charge running up to the front
  BREATHE_MS: 1100,    // the charging cell breathing in and out
  RIPPLE_MS: 760,      // Weave's ripple
  RIPPLE_CELLS: 14,    // how far it travels, in cells
  DENT_CELLS: 1.6      // how wide the pointer presses, in cells
}

function batteryCells(opts) {
  var n = Math.max(1, Math.floor(opts.segments || 10))
  var level = hasLevel(opts.level) ? Math.max(0, Math.min(100, opts.level)) : 0
  var t = opts.t || 0
  var full = level / 100 * n
  var ripples = opts.ripples || []
  var flowAt = opts.charging ? (t % BATTERY.FLOW_MS) / BATTERY.FLOW_MS * (Math.ceil(full) + 2) - 1 : -99
  var breathe = 0.5 - 0.5 * Math.cos(t / BATTERY.BREATHE_MS * 2 * Math.PI)
  var out = []
  for (var i = 0; i < n; i++) {
    var fill = Math.max(0, Math.min(1, full - i))
    var glow = fill > 0 ? Math.max(0, 1 - Math.abs(i + 0.5 - flowAt) / 1.2) * 0.5 : 0
    for (var j = 0; j < ripples.length; j++) {
      var k = ripples[j].age / BATTERY.RIPPLE_MS
      if (k < 0 || k >= 1) continue
      var d = Math.abs(i + 0.5 - ripples[j].x * n)
      var ring = 1 - Math.abs(d - k * BATTERY.RIPPLE_CELLS) / 1.1
      if (ring > 0) glow = Math.max(glow, ring * (1 - k))
    }
    var press = 0
    if (opts.dent !== null && opts.dent !== undefined)
      press = Math.max(0, 1 - Math.abs(i + 0.5 - opts.dent * n) / BATTERY.DENT_CELLS)
    var next = opts.charging && level < 100 && i === Math.floor(full) ? breathe : 0
    out.push({ fill: fill, glow: glow, press: press, next: next })
  }
  return out
}

// A reading's pieces held together where a line may break: the dot stays at
// the end of the piece before it, "2h 00m", "18 W" and "just now" stay
// whole, so a wrapped line never starts with a dot or a unit.
var NBSP = "\u00A0"

function keepTogether(text) {
  return String(text || "")
    .replace(/ \u00B7 /g, NBSP + "\u00B7 ")
    .replace(/(\d+h) (\d+m)/g, "$1" + NBSP + "$2")
    .replace(/(\d+(?:\.\d+)?) (W|Wh|%|GHz)\b/g, "$1" + NBSP + "$2")
    .replace(/just now/g, "just" + NBSP + "now")
}

// ---------------------------------------------------------------- prompt

function escapeHtml(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// The prompt line `typed` characters in, as styled text that always lays out
// the whole line plus a cursor cell, the part not typed yet drawn clear, so a
// word never wraps differently while it types. The cursor stands in for the
// next character, except a space, which it would glue to the next word; once
// typed, it blinks in the cell kept for it at the end. An underscore, the
// terminal's own cursor: Monocraft has no block characters, and a glyph it
// lacks comes from a fallback font with taller lines. Sonus's, line for line.
var CURSOR = "_"
var CLEAR = "<font color=\"#00000000\">"

function revealLine(line, typed, cursorOn) {
  line = String(line || "")
  var n = Math.max(0, Math.min(line.length, Math.floor(typed) || 0))
  var shown = escapeHtml(line.substring(0, n))
  var rest
  if (n < line.length) {
    var next = line.charAt(n)
    shown += next === " " || next === NBSP ? next : CURSOR
    rest = line.substring(n + 1) + CURSOR
  } else if (cursorOn) {
    shown += CURSOR
    rest = ""
  } else {
    rest = CURSOR
  }
  return rest === "" ? shown : shown + CLEAR + escapeHtml(rest) + "</font>"
}

// Text arriving the way a terminal decodes it: the first `progress` of it
// is real, the rest cycles through glyphs. Spaces and separators stay put so
// the line keeps its shape. `seed` varies the noise between runs.
var GLITCH = "#%&*+=<>/\\|~:;?!$@"

function scramble(text, progress, seed) {
  text = String(text || "")
  var keep = Math.floor(Math.max(0, Math.min(1, progress)) * text.length)
  var tick = Math.floor(progress * 14)
  var out = ""
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    if (i < keep || ch === " " || ch === NBSP || ch === "\u00B7") { out += ch; continue }
    var h = (((i + 1) * 73856093) ^ (((seed || 0) + 1) * 19349663) ^ ((tick + 1) * 83492791)) >>> 0
    out += GLITCH.charAt(h % GLITCH.length)
  }
  return out
}

// The bar picks that belong to one room ("laptop", "airpods" or a device id),
// shown as switches when the room is opened.
function roomPicks(picks, room) {
  return (picks || []).filter(function(p) { return p.room === room })
}

// What reads each device, in words.
var SOURCE_LABELS = {
  "glorious": "Glorious dongle",
  "glorious-wired": "Glorious cable",
  "hyperx": "HyperX dongle",
  "razer": "openrazer",
  "jbl": "JBL Bluetooth service",
  "upower": "UPower",
  "headsetcontrol": "HeadsetControl",
  "iphone": "libimobiledevice",
  "kdeconnect": "KDE Connect"
}

// A device room's details, as label and value pairs.
function deviceFacts(device) {
  if (!device) return []
  var facts = [{ label: "State", value: statusText(device) }]
  var conn = connectionText(device)
  if (conn) facts.push({ label: "Link", value: conn })
  facts.push({ label: "Kind", value: kindLabel(device.kind) })
  if (device.model && device.name && device.model !== device.name) facts.push({ label: "Name", value: device.name })
  if (SOURCE_LABELS[device.source]) facts.push({ label: "Read by", value: SOURCE_LABELS[device.source] })
  if (device.stale) facts.push({ label: "Level", value: "last one seen" })
  return facts
}

// The AirPods room's details.
function airpodsFacts(pods) {
  if (!pods) return []
  var facts = []
  if (pods.model) facts.push({ label: "Model", value: pods.model })
  facts.push({ label: "Read by", value: "librepods" })
  return facts
}

// The mark beside a level, as a pixel icon: low first, else what the
// charger is doing (a bolt while charge flows in, a plug on a charger with
// nothing flowing), else nothing.
function markIcon(item, threshold) {
  if (!item || item.stale) return ""
  if (isLow(item, threshold)) return "battery-low"
  if (item.charging) return "zap"
  if (item.acOnline || item.powered) return "plug"
  return ""
}

// ------------------------------------------------------------- pixel type

// The bar's numbers in the panel's block face, as pixels: each digit is the
// face's columns by five half rows (bigDigits) with its middle column
// doubled, four wide, so the inside of a 0 or an 8 is two pixels and reads at
// bar size. The one keeps a single stem. Letters the bar needs ("44 W",
// "1h 22m", "zZ") and the % are drawn to match. Rows top to bottom, "#" on.
var PIXEL_FONT = {
  "1": [".##.", "..#.", "..#.", "..#.", ".###"],
  "%": ["##..#", "##.#.", "..#..", ".#.##", "#..##"],
  " ": ["..", "..", "..", "..", ".."],
  ".": [".", ".", ".", ".", "#"],
  "W": ["#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
  "h": ["#...", "#...", "####", "#..#", "#..#"],
  "m": [".....", "####.", "#.#.#", "#.#.#", "#.#.#"],
  "z": ["....", "####", "..#.", ".#..", "####"],
  "Z": ["####", "..#.", ".#..", "#...", "####"]
}
;(function() {
  "023456789-".split("").forEach(function(ch) {
    var rows = bigDigits(ch)
    var half = []
    rows.forEach(function(row) {
      var top = "", bottom = ""
      for (var i = 0; i < row.length; i++) {
        var c = row.charAt(i)
        var t = c === "\u2588" || c === "\u2580" ? "#" : "."
        var u = c === "\u2588" || c === "\u2584" ? "#" : "."
        // The middle column twice.
        top += i === 1 ? t + t : t
        bottom += i === 1 ? u + u : u
      }
      half.push(top, bottom)
    })
    PIXEL_FONT[ch] = half.slice(0, 5)
  })
})()

// A line in the pixel type: { width, height, rects }, in cells, rects as
// [x, y, w, h] merged along each row. A cell between letters; anything the
// type lacks is skipped.
function pixelText(text) {
  var rects = [], x = 0
  String(text || "").split("").forEach(function(ch) {
    var glyph = PIXEL_FONT[ch]
    if (!glyph) return
    if (x > 0) x += 1
    for (var r = 0; r < glyph.length; r++) {
      var row = glyph[r], c = 0
      while (c < row.length) {
        if (row.charAt(c) !== "#") { c++; continue }
        var start = c
        while (c < row.length && row.charAt(c) === "#") c++
        rects.push([x + start, r, c - start, 1])
      }
    }
    x += glyph[0].length
  })
  return { width: x, height: 5, rects: rects }
}

// ------------------------------------------------------------ room tones

// Each kind's own hue, DailyDash's, for themes whose palette is all greys.
var TONE_HUES = {
  blue: "#5ab4f5",
  magenta: "#c38af0",
  cyan: "#4fc9d9",
  green: "#5cc98a",
  yellow: "#f1b467"
}

function hexRgb(hex) {
  var m = String(hex || "").match(/^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i)
  return m ? { r: parseInt(m[1], 16) / 255, g: parseInt(m[2], 16) / 255, b: parseInt(m[3], 16) / 255 } : null
}

function rgbHex(c) {
  function h(v) { var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16); return s.length < 2 ? "0" + s : s }
  return "#" + h(c.r) + h(c.g) + h(c.b)
}

// HSL saturation, 0 to 1.
function saturation(c) {
  var max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b)
  var l = (max + min) / 2
  if (max === min) return 0
  return (max - min) / (1 - Math.abs(2 * l - 1))
}

// A room's tone: the theme's colour of that name when it is a colour, else
// the kind's own hue, either way softened a third of the way toward the
// theme's text colour so it sits quietly in the theme.
function roomToneHex(name, palette, foreground) {
  var own = hexRgb(palette ? palette[name] : null)
  var base = own && saturation(own) >= 0.3 ? own : hexRgb(TONE_HUES[name] || TONE_HUES.green)
  var fg = hexRgb(foreground) || { r: 0.8, g: 0.8, b: 0.8 }
  var k = 0.3
  return rgbHex({ r: base.r + (fg.r - base.r) * k, g: base.g + (fg.g - base.g) * k, b: base.b + (fg.b - base.b) * k })
}


// ------------------------------------------------------------ hover card

// The rows of the card that opens when the pointer rests on the bar item:
// every battery the panel shows, one line each, the AirPods a line a part.
// { key, name, icon, tone (a KIND_TONES name), level, charging, powered,
// stale, note }. `note` is a few words for a part that stopped answering.
// The hover card's last line: what the bar item's other buttons do. A click
// opens the panel, which the card itself says.
var HOVER_HINT = "middle: refresh \u00B7 right: settings"

function hoverRows(state, nowSec) {
  var rows = []
  if (!state) return rows
  var lap = state.laptop
  if (lap && hasLevel(lap.level)) {
    rows.push({ key: "laptop", name: "Laptop", icon: "laptop", tone: kindTone("laptop"), level: lap.level,
                charging: !!lap.charging, powered: !!lap.acOnline, stale: false, note: "" })
  }
  var pods = state.airpods
  if (airpodsShown(pods) && pods.known) {
    airpodsParts(pods).forEach(function(part) {
      var p = part.pod
      if (!p || !hasLevel(p.level)) return
      // The buds and the case by their part alone: the AirPods icon on the
      // row says whose, and "AirPods case  closed 1h" no longer fit a line.
      var name = part.key === "headset" ? (pods.name || "AirPods") : part.label
      rows.push({ key: "airpods-" + part.key, name: name, icon: part.key === "case" ? "airpods-case" : "airpods",
                  tone: kindTone("airpods"), level: p.level, charging: !!p.charging && !p.stale, powered: false,
                  stale: !!p.stale || !!pods.stale,
                  note: p.stale ? (part.key === "case" ? "closed " : "in case ") + ago((nowSec || Date.now() / 1000) - (p.seenAt || 0)).replace(" ago", "") : "" })
    })
  }
  ;(state.devices || []).forEach(function(d) {
    rows.push({ key: d.id, name: shortName(d), icon: kindPixel(d.kind), tone: kindTone(d.kind), level: hasLevel(d.level) ? d.level : null,
                charging: !!d.charging && !d.stale, powered: !!d.powered && !d.stale, stale: !!d.stale,
                note: d.status === "asleep" ? "asleep" : d.status === "no-access" ? "needs access" : "" })
  })
  return rows
}
