.pragma library

// Pure helpers for the widget, kept free of QML so tests/model.test.js can
// run them under node.

var KIND_ICONS = {
  "mouse": "󰍽",
  "keyboard": "󰌌",
  "headset": "󰋎",
  "headphones": "󰋋",
  "speakers": "󰓃",
  "gaming-input": "󰊴",
  "touchpad": "󰟸",
  "tablet": "󰓶",
  "pen": "󰏪",
  "phone": "󰏲",
  "media-player": "󰎈",
  "remote-control": "󰑔",
  "bluetooth-generic": "󰂯"
}

var CONNECTION_LABELS = { usb: "USB cable", wireless: "2.4 GHz", bluetooth: "Bluetooth" }

function kindIcon(kind) {
  return KIND_ICONS[kind] || "󰁹"
}

function kindLabel(kind) {
  if (kind === "gaming-input") return "Controller"
  if (!kind) return "Device"
  var s = String(kind).replace(/-/g, " ")
  return s.charAt(0).toUpperCase() + s.slice(1)
}

// Parses bin/peripheral-battery's JSON. Returns null when it is not that.
function parseProbe(text) {
  var data
  try { data = JSON.parse(String(text || "").trim()) } catch (e) { return null }
  if (!data || !Array.isArray(data.devices)) return null
  return {
    devices: data.devices.filter(function(d) { return d && d.id }),
    needsAccess: Array.isArray(data.needsAccess) ? data.needsAccess : [],
    udevInstalled: data.udevInstalled === true
  }
}

// A sleeping 2.4 GHz mouse answers without a level. Keep the last one seen
// so the bar does not blank every time it naps; `stale` marks it as such.
function withLastKnown(devices, previous) {
  var byId = {}
  for (var i = 0; i < (previous || []).length; i++) byId[previous[i].id] = previous[i]
  return devices.map(function(d) {
    var out = {}
    for (var k in d) out[k] = d[k]
    out.stale = false
    var prev = byId[d.id]
    if ((out.level === null || out.level === undefined) && prev && prev.level !== null && prev.level !== undefined) {
      out.level = prev.level
      out.stale = true
    }
    return out
  })
}

// The bar device: the configured id, else the first mouse, else the first
// device that has a level.
function pickPrimary(devices, preferredId) {
  if (!devices || devices.length === 0) return null
  if (preferredId) {
    for (var i = 0; i < devices.length; i++) if (devices[i].id === preferredId) return devices[i]
  }
  for (var j = 0; j < devices.length; j++) if (devices[j].kind === "mouse") return devices[j]
  for (var k = 0; k < devices.length; k++) if (devices[k].level !== null && devices[k].level !== undefined) return devices[k]
  return devices[0]
}

function percent(level) {
  return level === null || level === undefined ? "--" : Math.round(level) + "%"
}

function isLow(device, threshold) {
  return !!device && !device.charging && device.level !== null && device.level !== undefined && device.level <= threshold
}

function statusText(device) {
  if (!device) return ""
  var s = device.status
  if (s === "charging") return device.level !== null && device.level !== undefined ? "Charging" : "Charging (level unknown)"
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

function tooltip(devices, primary) {
  if (!devices || devices.length === 0) return "No battery-powered peripherals found"
  return devices.map(function(d) {
    return d.name + "  " + percent(d.level) + (d.charging ? " charging" : "") + (d.stale ? " (last seen)" : "")
  }).join("\n")
}
