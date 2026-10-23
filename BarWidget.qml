import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry: the chosen peripheral's icon and level, with a bolt while it
// charges. The bar draws this widget once per monitor; the first instance
// owns the poller and the others read from it.
BarWidget {
  id: root
  moduleName: "io.github.t3lluz.peripheral-battery"

  readonly property string preferredDevice: String(setting("device", ""))
  readonly property bool showPercent: setting("showPercent", true) === true
  readonly property bool hideWhenEmpty: setting("hideWhenEmpty", true) === true
  readonly property int lowThreshold: Number(setting("lowThreshold", 20)) || 20
  readonly property bool notifyLow: setting("notifyLow", true) === true
  readonly property int intervalSec: Number(setting("refreshIntervalSec", 30)) || 30

  property var leader: root
  readonly property bool isLeader: leader === root
  readonly property var ownClient: ownClientLoader.item ? ownClientLoader.item : null
  readonly property var client: isLeader ? ownClient : (leader ? leader.ownClient : null)

  readonly property var devices: client ? client.devices : []
  readonly property var primary: Model.pickPrimary(devices, preferredDevice)
  readonly property bool hasLevel: !!primary && primary.level !== null && primary.level !== undefined
  readonly property bool empty: !!client && client.loaded && devices.length === 0
  readonly property bool needsAccess: !!client && client.needsAccess.length > 0
  readonly property color barFg: bar ? bar.barForeground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(barFg, 1.55)
  readonly property color levelColor: {
    if (!primary) return dim
    if (Model.isLow(primary, lowThreshold) && !primary.stale) return urgent
    if (primary.stale || primary.status === "asleep" || primary.status === "offline") return dim
    return barFg
  }

  // Persists inline settings to this widget's shell.json entry, applied
  // locally first so the panel reacts on the click itself.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function electLeader() {
    var items = bar && typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : []
    for (var i = 0; i < items.length; i++) {
      if (items[i] && "ownClient" in items[i]) {
        if (leader !== items[i]) leader = items[i]
        return
      }
    }
    if (leader !== root) leader = root
  }

  // ---- Panel lifecycle, forwarded so shell summon/hide/toggle route here.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  property bool countedOpen: false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function refresh() { if (client) client.pollNow() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
    target.client = root.client
  }

  function syncOpenCount() {
    var want = opened && !!client
    if (want === countedOpen) return
    countedOpen = want
    if (client) client.openPanels = Math.max(0, client.openPanels + (want ? 1 : -1))
  }

  visible: !(hideWhenEmpty && empty)
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  onBarChanged: { electLeader(); injectPanel() }
  onSettingsChanged: injectPanel()
  onClientChanged: injectPanel()
  onOpenedChanged: syncOpenCount()
  Component.onCompleted: electLeader()
  Component.onDestruction: if (countedOpen && client) client.openPanels = Math.max(0, client.openPanels - 1)

  // moduleWidgets is not reactive, and monitors come and go.
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.electLeader()
  }

  Loader {
    id: ownClientLoader
    active: root.isLeader
    sourceComponent: Component { BatteryClient { } }
  }

  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "intervalSec"; value: root.intervalSec }
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "lowThreshold"; value: root.lowThreshold }
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "notifyLow"; value: root.notifyLow }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.t3lluz.peripheral-battery"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string {
      var c = root.client
      return JSON.stringify({
        primary: root.primary,
        devices: c ? c.devices : [],
        needsAccess: c ? c.needsAccess : [],
        error: c ? c.errorText : "loading"
      })
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    tooltipText: root.needsAccess ? "Peripheral Battery: click to grant access to your mouse"
      : Model.tooltip(root.devices, root.primary)
    fixedWidth: root.vertical ? -1 : content.implicitWidth + scaledHorizontalMargin * 2
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(4)

      Item {
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        anchors.verticalCenter: parent.verticalCenter

        OpticalGlyph {
          anchors.fill: parent
          text: root.primary ? Model.kindIcon(root.primary.kind) : "󰍽"
          fontFamily: button.fontFamily
          fontSize: Style.bar.iconFont
          color: root.needsAccess ? root.urgent : root.levelColor
        }
      }

      BoltIcon {
        visible: !!root.primary && root.primary.charging
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: Math.round(button.fontSize * 1.05)
        color: Color.accent
      }

      Text {
        visible: root.showPercent && !root.vertical && !!root.primary
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.primary ? (root.hasLevel ? Model.percent(root.primary.level)
          : (root.primary.status === "asleep" ? "zZ" : "--")) : ""
        color: root.levelColor
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
      }
    }
  }
}
