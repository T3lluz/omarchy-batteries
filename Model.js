.pragma library

// Pure helpers for the widget, kept free of QML so tests/model.test.js can
// run them under node. The bar's icons are names in Icons.js (Tabler outlines);
// the panel's are Nerd Font glyphs, the set Omarchy's own panels type.

var KIND_ICONS = {
  "mouse": "mouse",
  "keyboard": "keyboard",
  "headset": "headset",
  "headphones": "headphones",
  "speakers": "device-speaker",
  "gaming-input": "device-gamepad-2",
  "touchpad": "hand-finger",
  "tablet": "device-tablet",
  "pen": "ballpen",
  "phone": "device-mobile",
  "media-player": "music",
  "remote-control": "device-remote",
  "ups": "battery-automotive",
  "bluetooth-generic": "bluetooth",
  "laptop": "device-laptop",
  "airpods": "device-airpods"
}

// "airpods" is drawn by AirPodsIcon.qml; every other name is in Icons.js.
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

function kindIcon(kind) {
  return KIND_ICONS[kind] || "battery"
}

// What a device is called in the panel: the model when the reader knows it
// (a JBL speaker renamed in the JBL app), else its name.
function deviceTitle(device) {
  return device ? device.model || device.name || "" : ""
}

// A JBL row draws the JBL mark itself, so its title drops the brand.
function jblTitle(device) {
  return deviceTitle(device).replace(/^JBL\s+/i, "")
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

// The panel header's battery: the ramps Omarchy's power panel uses, ten steps.
var BATTERY_RAMP = ["\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}", "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"]
var CHARGING_RAMP = ["\u{F089C}", "\u{F0086}", "\u{F0087}", "\u{F0088}", "\u{F089D}", "\u{F0089}", "\u{F089E}", "\u{F008A}", "\u{F008B}", "\u{F0085}"]

function batteryGlyph(level, charging) {
  if (!hasLevel(level)) return GLYPHS.unknownBattery
  var step = Math.max(0, Math.min(9, Math.floor(level / 10)))
  return (charging ? CHARGING_RAMP : BATTERY_RAMP)[step]
}

// The mark beside a level: a bolt while charge flows in, a plug while a charger
// is connected but nothing flows (full, or held at a limit), else nothing. An
// old reading says nothing about the charger now.
function powerGlyph(item) {
  if (!item) return ""
  if (item.stale) return ""
  if (item.charging) return GLYPHS.bolt
  if (item.acOnline || item.powered) return GLYPHS.plug
  return ""
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

// AirPods in their case stop advertising after a while and librepods drops
// the levels; the panel keeps the last ones, marked stale.
function airpodsWithLastKnown(pods, previous) {
  if (!pods) return null
  var out = copy(pods)
  out.stale = false
  if (!pods.known && previous && previous.known && previous.name === pods.name) {
    out.left = previous.left
    out.right = previous.right
    out["case"] = previous["case"]
    out.headset = previous.headset
    out.level = previous.level
    out.charging = false
    out.known = true
    out.stale = true
  }
  return out
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

// AirPodsIcon.qml's outline for these AirPods: "pro", "max" or "buds".
function airpodsVariant(pods) {
  if (!pods) return "buds"
  if (pods.isHeadset) return "max"
  return pods.isPro ? "pro" : "buds"
}

function airpodsParts(pods) {
  if (!pods) return []
  // "airpods" is drawn by AirPodsIcon.qml rather than from Icons.js.
  if (pods.isHeadset) return [{ key: "headset", label: pods.model || "AirPods Max", icon: "airpods", pod: pods.headset }]
  return [
    { key: "left", label: "Left", icon: "airpods", pod: pods.left },
    { key: "right", label: "Right", icon: "airpods", pod: pods.right },
    { key: "case", label: "Case", icon: "device-airpods-case", pod: pods["case"] }
  ]
}

// The panel shows AirPods only while they are connected, the way a mouse
// that is switched off drops out of the device list.
function airpodsShown(pods) {
  return !!pods && pods.connected === true
}

function airpodsStatus(pods) {
  if (!pods) return ""
  if (pods.stale) return (pods.connected ? "Connected" : "Not connected") + " · last levels"
  if (pods.connected) {
    if (!pods.known) return "Connected · waiting for levels"
    var inEar = [pods.left, pods.right].filter(function(p) { return p && p.inEar }).length
    return "Connected" + (inEar === 2 ? " · in both ears" : inEar === 1 ? " · in one ear" : "")
  }
  return pods.known ? "In range, not connected" : "Not connected"
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
    var pack = pods["case"]
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
    picks.push({ key: "barLaptop", icon: kindGlyph("laptop"), label: "Laptop", hint: "Its level; charge flows up through the icon while plugged in", fallback: true })
    picks.push({ key: "barLaptopRate", icon: GLYPHS.bolt, label: "Laptop power", hint: "Watts going in or out", fallback: false })
    picks.push({ key: "barLaptopTime", icon: GLYPHS.clock, label: "Laptop time", hint: "Time left, or time to full while charging", fallback: false })
  }
  var pods = state ? state.airpods : null
  if (airpodsShown(pods)) {
    picks.push({ key: "barAirpods", icon: GLYPHS.earbuds, label: pods.name || "AirPods", hint: "The emptier bud, while they are connected", fallback: true })
    if (!pods.isHeadset) picks.push({ key: "barAirpodsCase", icon: GLYPHS.airpodsCase, label: "AirPods case", hint: "While the case is open and in range", fallback: false })
  }
  var devices = (state && state.devices) || []
  devices.forEach(function(d) {
    // A half-width tile fits "Mouse", not a model. The model takes over when
    // two devices of a kind need telling apart, and the tooltip always names it.
    var alone = devices.filter(function(o) { return o.kind === d.kind }).length === 1
    picks.push({ device: d, icon: kindGlyph(d.kind), label: alone ? shortName(d) : deviceTitle(d), hint: deviceTitle(d) + " · " + subtitle(d) })
  })
  return picks
}

// The picker header's reading: how many are on, or that the bar shows only
// the icon.
function barPickedText(count) {
  return count > 0 ? count + " SHOWN" : "ICON ONLY"
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
      icon: kindIcon(d.kind),
      text: opts.percent ? (hasLevel(d.level) ? percent(d.level) : (d.status === "asleep" ? "zZ" : "--")) : "",
      powered: !!(d.powered || d.charging),
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
        powered: !!pods.charging,
        tone: isLow(pods, t) ? "low" : "normal"
      })
    }
    if (opts.airpodsCase && !pods.isHeadset && pods["case"]) {
      items.push({
        key: "airpods-case",
        icon: "device-airpods-case",
        text: opts.percent ? percent(pods["case"].level) : "",
        powered: !!pods["case"].charging,
        tone: "normal"
      })
    }
  }

  var lap = state.laptop
  if (lap) {
    if (opts.laptop) {
      items.push({
        key: "laptop",
        icon: "device-laptop",
        text: opts.percent ? percent(lap.level) : "",
        // Full or held at a charge limit still shows, so the charger is
        // visibly connected.
        powered: !!(lap.acOnline || lap.charging),
        tone: isLow(lap, t) ? "low" : "normal"
      })
    }
    if (opts.laptopRate && lap.rateW > 0) {
      items.push({ key: "laptop-rate", icon: lap.charging ? "plug-connected" : "bolt", text: watts(lap.rateW), powered: false, tone: "normal" })
    }
    if (opts.laptopTime && (lap.timeToEmpty || lap.timeToFull)) {
      items.push({ key: "laptop-time", icon: "clock-hour-4", text: duration(lap.timeToEmpty || lap.timeToFull), powered: false, tone: "normal" })
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

function tooltip(state) {
  var lines = []
  var lap = state.laptop
  if (lap) lines.push("Laptop  " + percent(lap.level) + "  " + laptopStatus(lap))
  var pods = state.airpods
  if (pods && pods.known) {
    var parts = airpodsParts(pods).map(function(p) { return p.label + " " + (p.pod ? percent(p.pod.level) : "--") })
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
// `flow` runs from 0 (band below the drawing) to 1 (band above it, at rest).
// `wait` is how many ms until it next changes.
function chargeStep(now, stepMs) {
  var t = now % CHARGE_CYCLE_MS
  if (t >= CHARGE_SWEEP_MS) return { flow: 1, wait: CHARGE_CYCLE_MS - t }
  return { flow: Math.floor(t / stepMs) * stepMs / CHARGE_SWEEP_MS, wait: stepMs - t % stepMs }
}
