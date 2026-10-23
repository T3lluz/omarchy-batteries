import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Owns polling and state. All device I/O happens in bin/peripheral-battery;
// this side schedules it, remembers the last level of sleeping devices, and
// sends low-battery notifications.
Item {
  id: root
  visible: false

  property int intervalSec: 30
  property int lowThreshold: 20
  property bool notifyLow: true
  property int openPanels: 0

  property var devices: []
  property var needsAccess: []
  property bool udevInstalled: false
  property bool loaded: false
  property string errorText: ""
  property bool installing: false
  property real lastPollMs: 0
  property bool pollAgain: false

  readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("bin/peripheral-battery").toString().replace(/^file:\/\//, ""))

  PersistentProperties {
    id: persisted
    reloadableId: "io.github.t3lluz.peripheral-battery"
    property var lastDevices: []
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
      errorText = String(err || "").trim().split("\n").pop() || "peripheral-battery gave no answer"
      loaded = true
      return
    }
    errorText = ""
    var next = Model.withLastKnown(parsed.devices, persisted.lastDevices)
    devices = next
    persisted.lastDevices = next
    needsAccess = parsed.needsAccess
    udevInstalled = parsed.udevInstalled
    lastPollMs = Date.now()
    loaded = true

    var low = Model.lowBatteryAlerts(next, lowThreshold, persisted.notified || {})
    persisted.notified = low.notified
    if (notifyLow) {
      for (var i = 0; i < low.alerts.length; i++) {
        var d = low.alerts[i]
        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Peripheral Battery",
          "-i", "battery-caution", Model.kindLabel(d.kind) + " battery low",
          d.name + " is at " + Model.percent(d.level) + ". Plug it in."])
      }
    }
  }

  Component.onCompleted: Qt.callLater(pollNow)

  Timer {
    running: true
    repeat: true
    interval: (root.openPanels > 0 ? 5 : Math.max(5, root.intervalSec)) * 1000
    onTriggered: root.pollNow()
  }

  // Plugging the cable in or out, or a Bluetooth device coming and going,
  // re-polls right away so the charging bolt follows the cable.
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
