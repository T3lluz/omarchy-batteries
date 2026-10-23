import QtQuick
import Quickshell
import Quickshell.Io
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
  property real lastPollMs: 0
  property bool pollAgain: false

  readonly property var state: ({ laptop: laptop, airpods: airpods, devices: devices })
  readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("bin/batteries").toString().replace(/^file:\/\//, ""))
  readonly property string podsStatePath: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/librepods/status.json"

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
    installProc.running = true
  }

  function handleProbe(out, err) {
    var parsed = Model.parseProbe(out)
    if (!parsed) {
      errorText = String(err || "").trim().split("\n").pop() || "bin/batteries gave no answer"
      loaded = true
      return
    }
    errorText = ""
    var next = Model.withLastKnown(parsed.devices, persisted.lastDevices)
    var pods = Model.airpodsWithLastKnown(parsed.airpods, persisted.lastAirpods)
    devices = next
    airpods = pods
    laptop = parsed.laptop
    persisted.lastDevices = next
    if (pods && pods.known) persisted.lastAirpods = pods
    needsAccess = parsed.needsAccess
    udevInstalled = parsed.udevInstalled
    lastPollMs = Date.now()
    loaded = true

    var low = Model.lowBatteryAlerts(Model.alertables(root.state), lowThreshold, persisted.notified || {})
    persisted.notified = low.notified
    if (notifyLow) {
      for (var i = 0; i < low.alerts.length; i++) {
        var d = low.alerts[i]
        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Batteries",
          "-i", "battery-caution", (d.kind === "airpods" ? "AirPods" : Model.kindLabel(d.kind)) + " battery low",
          d.name + " is at " + Model.percent(d.level) + ". Plug it in."])
      }
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
    onExited: {
      root.installing = false
      hotplugDebounce.restart()
    }
  }
}
