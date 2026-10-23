.pragma library

// Pure helpers for the widget, kept free of QML so tests/model.test.js can
// run them under node. Icon names refer to Icons.js (Tabler outline icons).

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
var CONNECTION_ICONS = { usb: "usb", wireless: "antenna-bars-5", bluetooth: "bluetooth" }

function kindIcon(kind) {
  return KIND_ICONS[kind] || "battery"
}

function connectionIcon(connection) {
  return CONNECTION_ICONS[connection] || ""
}

function kindLabel(kind) {
  if (kind === "gaming-input") return "Controller"
  if (kind === "ups") return "UPS"
  if (!kind) return "Device"
  var s = String(kind).replace(/-/g, " ")
  return s.charAt(0).toUpperCase() + s.slice(1)
}

function hasLevel(level) {
  return level !== null && level !== undefined
}

// Battery outline with as many bars as the level earns.
function batteryIcon(level, charging) {
  if (charging) return "battery-charging"
  if (!hasLevel(level)) return "battery-off"
  if (level >= 88) return "battery-4"
  if (level >= 63) return "battery-3"
  if (level >= 38) return "battery-2"
  if (level >= 13) return "battery-1"
  return "battery"
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
  var conn = connectionText(device)
  if (conn) parts.push(conn)
  if (device && device.stale && device.status !== "discharging") parts.push("last level")
  return parts.join(" · ")
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

// Label/value rows for the laptop card.
function laptopFacts(lap) {
  if (!lap) return []
  var rows = []
  if (lap.status === "charging" || lap.status === "discharging")
    rows.push({ icon: "bolt", label: lap.status === "charging" ? "Charging at" : "Drawing", value: watts(lap.rateW) })
  if (lap.timeToEmpty) rows.push({ icon: "clock-hour-4", label: "Time left", value: duration(lap.timeToEmpty) })
  if (lap.timeToFull) rows.push({ icon: "clock-hour-4", label: "Until " + (lap.chargeLimit ? lap.chargeLimit + "%" : "full"), value: duration(lap.timeToFull) })
  if (lap.energyFullWh) rows.push({ icon: "battery-2", label: "Energy", value: lap.energyWh + " / " + lap.energyFullWh + " Wh" })
  if (hasLevel(lap.health)) rows.push({ icon: "heartbeat", label: "Health", value: lap.health + "% of " + lap.energyDesignWh + " Wh" })
  if (lap.cycles) rows.push({ icon: "repeat", label: "Cycles", value: String(lap.cycles) })
  if (lap.chargeLimit) rows.push({ icon: "battery-eco", label: "Charge limit", value: (lap.chargeStart ? lap.chargeStart + "–" : "") + lap.chargeLimit + "%" })
  rows.push({ icon: lap.acOnline ? "plug-connected" : "plug", label: "Power", value: lap.acOnline ? "AC adapter" : "Battery" })
  return rows
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

function airpodsStatus(pods) {
  if (!pods) return ""
  if (pods.stale) return "Not connected · last levels"
  if (pods.connected) {
    var inEar = [pods.left, pods.right].filter(function(p) { return p && p.inEar }).length
    return "Connected" + (inEar === 2 ? " · in both ears" : inEar === 1 ? " · in one ear" : "")
  }
  return pods.known ? "In range, not connected" : "Not connected"
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
      charging: d.charging,
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
        charging: pods.charging,
        tone: isLow(pods, t) ? "low" : "normal"
      })
    }
    if (opts.airpodsCase && !pods.isHeadset && pods["case"]) {
      items.push({
        key: "airpods-case",
        icon: "device-airpods-case",
        text: opts.percent ? percent(pods["case"].level) : "",
        charging: pods["case"].charging,
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
        charging: lap.charging,
        tone: isLow(lap, t) ? "low" : "normal"
      })
    }
    if (opts.laptopRate && lap.rateW > 0) {
      items.push({ key: "laptop-rate", icon: lap.charging ? "plug-connected" : "bolt", text: watts(lap.rateW), charging: false, tone: "normal" })
    }
    if (opts.laptopTime && (lap.timeToEmpty || lap.timeToFull)) {
      items.push({ key: "laptop-time", icon: "clock-hour-4", text: duration(lap.timeToEmpty || lap.timeToFull), charging: false, tone: "normal" })
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

// The laptop's level over time, for the panel's graph: [[unixSeconds, level,
// charging 0/1], ...], oldest first. A sample is kept every `gap` seconds,
// or sooner when the level or charging changes, for `keep` seconds.
var HISTORY_GAP = 120
var HISTORY_KEEP = 24 * 3600

function parseHistory(text) {
  var data
  try { data = JSON.parse(String(text || "")) } catch (e) { return [] }
  var list = data && Array.isArray(data.samples) ? data.samples : []
  return list.filter(function(s) {
    return Array.isArray(s) && s.length >= 3 && isFinite(s[0]) && isFinite(s[1]) && s[1] >= 0 && s[1] <= 100
  }).map(function(s) { return [Math.round(s[0]), Math.round(s[1]), s[2] ? 1 : 0] })
}

function pushLevelSample(history, nowSec, level, charging) {
  var list = (history || []).filter(function(s) { return nowSec - s[0] <= HISTORY_KEEP && s[0] <= nowSec })
  if (!hasLevel(level)) return list
  var sample = [Math.round(nowSec), Math.round(level), charging ? 1 : 0]
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
// discharging samples (a gap over 15 minutes, a suspend, ends a run). Null
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

function drainText(perHour) {
  if (perHour === null || perHour === undefined) return ""
  return (perHour >= 10 ? Math.round(perHour) : Math.round(perHour * 10) / 10) + "% an hour on battery"
}

