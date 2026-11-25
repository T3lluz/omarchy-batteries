import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "Model.js" as Model

// Owns polling and state. All reading happens in bin/batteries; this side
// schedules it, remembers the last levels of sleeping devices, and sends
// low-battery notifications.
Item {
  id: root
  visible: false

  property int intervalSec: 30
  property int lowThreshold: 20
  property bool notifyLow: true
  // Watts and time left move constantly, so poll faster while they show.
  property bool liveBar: false
  property int openPanels: 0

  property var laptop: null
  property var airpods: null
  property var devices: []
  property var needsAccess: []
  property bool udevInstalled: false
  property bool loaded: false
  property string errorText: ""
  property bool installing: false
  // The password prompt was dismissed or refused (pkexec's 126 and 127), so
  // the panel can say so instead of waiting on nothing.
  property bool accessDeclined: false
  property real lastPollMs: 0
  property bool pollAgain: false

  readonly property var state: ({ laptop: laptop, airpods: airpods, devices: devices })
  readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("bin/batteries").toString().replace(/^file:\/\//, ""))
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
  readonly property string podsStatePath: stateHome + "/librepods/status.json"
  // The laptop's level over the last day (Model.pushLevelSample), kept on
  // disk so the panel's graph survives a restart.
  readonly property string historyDir: stateHome + "/omarchy-batteries"
  readonly property string historyPath: historyDir + "/history.json"
  property var history: []
  property bool historyLoaded: false

  // Updates go through bin/plugin-update, as in ROG Deck and Server
  // Dashboard; the settings' About section and the update banner read it.
  property bool autoUpdateCheck: true
  readonly property alias updater: updaterItem

  Updater {
    id: updaterItem
    pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "")).replace(/\/$/, "")
    autoCheck: root.autoUpdateCheck
  }

  PersistentProperties {
    id: persisted
    reloadableId: "io.github.t3lluz.batteries"
    property var lastDevices: []
    property var lastAirpods: null
    property var notified: ({})
  }

  function pollNow() {
    if (probeProc.running) { pollAgain = true; return }
    probeProc.running = true
  }

  function installAccess() {
    if (installProc.running) return
    installing = true
    accessDeclined = false
    installProc.running = true
  }

  function handleProbe(out, err) {
    var parsed = Model.parseProbe(out)
    if (!parsed) {
      // What went wrong goes to the log; the panel says it plainly.
      var why = String(err || "").trim()
      if (why) console.warn("batteries: probe failed: " + why)
      errorText = "Couldn't read the batteries"
      loaded = true
      return
    }
    errorText = ""
    var next = Model.withLastKnown(parsed.devices, persisted.lastDevices)
    var pods = Model.airpodsWithLastKnown(parsed.airpods, persisted.lastAirpods, Date.now() / 1000)
    devices = next
    airpods = pods
    laptop = parsed.laptop
    if (laptop && historyLoaded) {
      var grown = Model.pushLevelSample(history, Date.now() / 1000, laptop.level, laptop.charging || laptop.acOnline)
      if (grown.length !== history.length || grown[grown.length - 1] !== history[history.length - 1]) {
        history = grown
        historySave.restart()
      }
    }
    persisted.lastDevices = next
    if (pods && pods.known) {
      persisted.lastAirpods = pods
      saveAirpods(pods)
    }
    needsAccess = parsed.needsAccess
    udevInstalled = parsed.udevInstalled
    lastPollMs = Date.now()
    loaded = true

    var low = Model.lowBatteryAlerts(Model.alertables(root.state), lowThreshold, persisted.notified || {})
    persisted.notified = low.notified
    if (notifyLow) {
      for (var i = 0; i < low.alerts.length; i++) sendAlert(low.alerts[i], false)
    }
    followAlerts()
  }

  // ------------------------------------------------------------- alerts

  // A battery that goes low gets a real notification, so it takes its place
  // in the shell's stack and history and keeps to Do Not Disturb, dressed in
  // the panel's look: its picture is a pixel badge (`bin/batteries badge`)
  // drawn for the focused screen's scale, and a click opens the panel. The
  // notification follows the battery: plugged in, the same card turns to
  // its thanks in the room's colour and goes; back above the line or out of
  // reach, it is withdrawn.

  // The bar widget that knows the room colours (its alertTone).
  property var toneHost: null
  // Device id -> its notice, while its notification is up.
  property var notices: ({})

  function sendAlert(device, preview) {
    if (notices[device.id]) return
    var notice = noticeComponent.createObject(root, { note: Model.alertNote(device), preview: !!preview })
    var next = Object.assign({}, notices)
    next[device.id] = notice
    notices = next
  }

  function followAlerts() {
    for (var id in notices) {
      var n = notices[id]
      if (!n || n.preview || n.answered) continue
      var now = Model.alertState(id, root.state, lowThreshold)
      if (now.state === "charging") n.thank(now.level)
      else if (now.state !== "low") n.withdraw()
    }
  }

  function forget(id, notice) {
    if (notices[id] !== notice) return
    var next = Object.assign({}, notices)
    delete next[id]
    notices = next
  }

  // The shell draws a sender's picture in a slot 40 wide; at the focused
  // screen's scale, a whole number of device pixels, so it stays sharp.
  function badgeSize() {
    var m = Hyprland.focusedMonitor
    var scale = m && m.scale > 0 ? m.scale : 1
    return Math.round(Style.space(40) * scale)
  }

  function toneHex(name, low) {
    var c = toneHost && typeof toneHost.alertTone === "function" ? toneHost.alertTone(name, low) : null
    return c ? String(c) : "#ffffff"
  }

  // The notification as the panel would show it, on a made-up level: it goes
  // low, and after a few seconds it is plugged in.
  function previewAlert() {
    var real = Model.alertables(root.state).filter(function(d) { return Model.hasLevel(d.level) })[0]
    var old = notices["preview"]
    if (old) old.withdraw()
    forget("preview", old)
    sendAlert({ id: "preview", name: real ? real.name : "Wireless mouse", kind: real ? real.kind : "mouse", level: 12 }, true)
  }

  Component {
    id: noticeComponent

    Item {
      id: notice
      visible: false

      property var note: ({})
      property bool preview: false
      // The notification's id, once the shell has it.
      property string nid: ""
      property bool answered: false
      property bool thanked: false

      readonly property string base: root.historyDir + "/alerts/" + String(note.key).replace(/[^A-Za-z0-9_-]/g, "_")
      readonly property string openArgv: JSON.stringify(["omarchy-shell", "io.github.t3lluz.batteries", "open"])

      // Draws the badge, then sends it; --wait keeps this running until the
      // notification closes, which is how the notice knows it is gone.
      readonly property string sendScript: 'python3 -B "$1" badge "$2" "$3" "$4" "$5" "$6"; img="$2"; [ -s "$img" ] || img=battery-caution; '
        + 'exec notify-send -p --wait -a Batteries -u critical -i "$img" -h "string:omarchy-exec-argv:$7" -- "$8" "$9"'
      readonly property string thankScript: 'python3 -B "$1" badge "$2" "$3" "$4" "$5" "$6"; img="$2"; [ -s "$img" ] || img=battery-good-charging; '
        + 'exec notify-send -r "${10}" -a Batteries -u normal -t 5000 -h boolean:transient:true -i "$img" -h "string:omarchy-exec-argv:$7" -- "$8" "$9"'

      function thank(level) {
        if (answered || !nid) return
        answered = true
        thanked = true
        thanker.command = ["sh", "-c", thankScript, "batteries-alert", root.scriptPath, base + "-charging.png", String(root.badgeSize()),
                           note.icon, String(Model.hasLevel(level) ? Math.round(level) : note.level), root.toneHex(note.tone, false),
                           openArgv, note.chargingTitle, note.chargingBody, nid]
        thanker.running = true
      }

      function withdraw() {
        if (answered) return
        answered = true
        if (!nid) return
        closer.command = ["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                          "--object-path", "/org/freedesktop/Notifications",
                          "--method", "org.freedesktop.Notifications.CloseNotification", nid]
        closer.running = true
      }

      Process {
        id: sender
        stdout: SplitParser {
          onRead: function(line) {
            var id = String(line).trim()
            if (!notice.nid && /^[0-9]+$/.test(id)) notice.nid = id
          }
        }
        onExited: {
          root.forget(notice.note.key, notice)
          notice.destroy(1000)
        }
      }

      Process { id: thanker }
      Process { id: closer }

      Timer {
        interval: 6000
        running: notice.preview && notice.nid !== ""
        onTriggered: notice.thank(13)
      }

      Component.onCompleted: {
        sender.command = ["sh", "-c", sendScript, "batteries-alert", root.scriptPath, base + "-low.png", String(root.badgeSize()),
                          note.icon, String(note.level), root.toneHex(note.tone, true), openArgv, note.title, note.body]
        sender.running = true
      }
    }
  }

  // The AirPods' last levels go to disk too, so a bud left in its case
  // keeps its level through a shell restart. Written only when a level or
  // what answers changes, not on every poll.
  readonly property string airpodsPath: historyDir + "/airpods.json"
  property string airpodsSaved: ""

  function saveAirpods(pods) {
    var key = JSON.stringify(["left", "right", "case", "headset"].map(function(k) {
      return pods[k] ? [pods[k].level, !!pods[k].stale] : null
    }).concat([pods.name]))
    if (key === airpodsSaved) return
    airpodsSaved = key
    airpodsFile.setText(JSON.stringify(pods) + "\n")
  }

  FileView {
    id: airpodsFile
    path: root.airpodsPath
    blockLoading: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (persisted.lastAirpods) return
      try {
        var saved = JSON.parse(text())
        if (saved && saved.name) persisted.lastAirpods = saved
      } catch (e) {}
    }
  }

  Component.onCompleted: Qt.callLater(pollNow)

  Timer {
    running: true
    repeat: true
    interval: (root.openPanels > 0 ? 5 : root.liveBar ? Math.min(10, root.intervalSec) : Math.max(5, root.intervalSec)) * 1000
    onTriggered: root.pollNow()
  }

  // Plugging a cable or the charger in or out, or a Bluetooth device coming
  // and going, re-polls right away so the bolt follows the cable.
  Process {
    id: udevWatch
    running: true
    command: ["udevadm", "monitor", "--udev", "--subsystem-match=hidraw", "--subsystem-match=power_supply"]
    stdout: SplitParser {
      onRead: function(line) { if (/^UDEV\s/.test(line)) hotplugDebounce.restart() }
    }
    onExited: udevRestart.start()
  }

  Timer {
    id: udevRestart
    interval: 10000
    onTriggered: udevWatch.running = true
  }

  // A replugged mouse enumerates in stages; wait for it to settle.
  Timer {
    id: hotplugDebounce
    interval: 1500
    onTriggered: root.pollNow()
  }

  // librepods rewrites its status file whenever the AirPods change.
  FileView {
    path: root.podsStatePath
    watchChanges: true
    printErrors: false
    onFileChanged: podsDebounce.restart()
  }

  Timer {
    id: podsDebounce
    interval: 400
    onTriggered: root.pollNow()
  }

  Process {
    id: historyMkdir
    command: ["mkdir", "-p", root.historyDir]
    running: true
    onExited: historyFile.reload()
  }

  FileView {
    id: historyFile
    path: root.historyPath
    blockLoading: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.history = Model.parseHistory(text())
      root.historyLoaded = true
    }
    onLoadFailed: root.historyLoaded = true
  }

  // At most once a minute: a sample lands every couple of minutes anyway.
  Timer {
    id: historySave
    interval: 60000
    onTriggered: historyFile.setText(Model.serializeHistory(root.history))
  }

  Component.onDestruction: if (historySave.running) historyFile.setText(Model.serializeHistory(root.history))

  Process {
    id: probeProc
    running: false
    command: ["python3", root.scriptPath, "probe"]
    stdout: StdioCollector { id: probeOut; waitForEnd: true }
    stderr: StdioCollector { id: probeErr; waitForEnd: true }
    onExited: {
      root.handleProbe(String(probeOut.text || ""), String(probeErr.text || ""))
      if (root.pollAgain) {
        root.pollAgain = false
        Qt.callLater(root.pollNow)
      }
    }
  }

  Process {
    id: installProc
    running: false
    command: ["pkexec", root.scriptPath, "install-udev"]
    onExited: function(exitCode) {
      root.installing = false
      root.accessDeclined = exitCode === 126 || exitCode === 127
      hotplugDebounce.restart()
    }
  }
}
