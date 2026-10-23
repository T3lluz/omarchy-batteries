import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry: the batteries picked in settings, each as an icon and level,
// with a bolt while it charges. The bar draws this widget once per monitor;
// the first instance owns the poller and the others read from it.
BarWidget {
  id: root
  moduleName: "io.github.t3lluz.batteries"

  readonly property var barOptions: ({
    laptop: setting("barLaptop", true) === true,
    laptopRate: setting("barLaptopRate", false) === true,
    laptopTime: setting("barLaptopTime", false) === true,
    airpods: setting("barAirpods", true) === true,
    airpodsCase: setting("barAirpodsCase", false) === true,
    devices: Model.idList(setting("barDevices", null)),
    percent: setting("barPercent", true) === true,
    lowThreshold: lowThreshold
  })
  readonly property int lowThreshold: Number(setting("lowThreshold", 20)) || 20
  readonly property bool notifyLow: setting("notifyLow", true) === true
  readonly property int intervalSec: Number(setting("refreshIntervalSec", 30)) || 30

  property var leader: root
  readonly property bool isLeader: leader === root
  readonly property var ownClient: ownClientLoader.item ? ownClientLoader.item : null
  readonly property var client: isLeader ? ownClient : (leader ? leader.ownClient : null)

  readonly property var batteryState: client ? client.state : ({ laptop: null, airpods: null, devices: [] })
  readonly property var items: Model.barItems(batteryState, barOptions)
  readonly property var shownItems: vertical ? items.slice(0, 1) : items
  readonly property bool needsAccess: !!client && client.needsAccess.length > 0
  readonly property color barFg: bar ? bar.barForeground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(barFg, 1.55)

  function toneColor(tone) {
    if (tone === "low") return urgent
    if (tone === "dim") return dim
    return barFg
  }

  // Settings come from shell.json itself rather than the bar's copy, so
  // every monitor agrees and a list survives a restart (WidgetSettings.qml).
  function setting(name, fallback) { return prefs.get(name, fallback) }
  function persistSettings(values) { prefs.save(values) }

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

  // summon, hide or toggle through the shell; this widget's own panel when
  // there is no shell to ask.
  function summon(how) {
    var shell = root.bar ? root.bar.shell : null
    var done = false
    if (shell && how === "summon" && typeof shell.summon === "function") done = shell.summon(root.moduleName, "{}")
    else if (shell && how === "hide" && typeof shell.hide === "function") done = shell.hide(root.moduleName)
    else if (shell && how === "toggle" && typeof shell.toggle === "function") done = shell.toggle(root.moduleName, "{}")
    if (done) return
    if (how === "summon") root.open()
    else if (how === "hide") root.close()
    else root.toggle()
  }
  function refresh() { if (client) client.pollNow() }
  function prepareSettings() { if (panelLoader.item) panelLoader.item.setupOpen = true }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.prefs = prefs
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

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: { electLeader(); injectPanel() }
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

  WidgetSettings {
    id: prefs
    moduleName: root.moduleName
    injected: root.settings
    shell: root.bar ? root.bar.shell : null
  }

  Loader {
    id: ownClientLoader
    active: root.isLeader
    sourceComponent: Component { BatteryClient { } }
  }

  // Every widget writes the same values, so the shared client sees one config.
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "intervalSec"; value: root.intervalSec }
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "lowThreshold"; value: root.lowThreshold }
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "notifyLow"; value: root.notifyLow }
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "liveBar"; value: root.barOptions.laptopRate || root.barOptions.laptopTime }

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
    target: "io.github.t3lluz.batteries"

    // Through the shell, which opens the panel on the focused monitor; this
    // handler belongs to whichever monitor's widget registered first.
    function open(): void { root.summon("summon") }
    function close(): void { root.summon("hide") }
    function show(): void { root.summon("summon") }
    function hide(): void { root.summon("hide") }
    function toggle(): void { root.summon("toggle") }
    function settings(): void {
      root.broadcast("prepareSettings")
      root.summon("summon")
    }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string {
      var c = root.client
      return JSON.stringify({
        options: root.barOptions,
        bar: root.items,
        laptop: c ? c.laptop : null,
        airpods: c ? c.airpods : null,
        devices: c ? c.devices : [],
        needsAccess: c ? c.needsAccess : [],
        history: c ? c.history.length : 0,
        error: c ? c.errorText : "loading"
      })
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    tooltipText: root.needsAccess ? "Batteries: click to grant access to your mouse" : Model.tooltip(root.batteryState)
    fixedWidth: root.vertical ? -1 : content.implicitWidth + scaledHorizontalMargin * 2
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(5)

      // Nothing picked, or nothing present: the battery mark alone.
      Icon {
        visible: root.shownItems.length === 0
        anchors.verticalCenter: parent.verticalCenter
        name: "battery"
        size: Style.bar.iconFont
        color: root.needsAccess ? root.urgent : root.barFg
      }

      Repeater {
        model: root.shownItems

        Row {
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          Icon {
            visible: modelData.icon !== "airpods"
            anchors.verticalCenter: parent.verticalCenter
            name: modelData.icon
            size: Style.bar.iconFont
            color: root.toneColor(modelData.tone)
          }

          AirPodsIcon {
            visible: modelData.icon === "airpods"
            anchors.verticalCenter: parent.verticalCenter
            iconSize: Style.bar.iconFont
            color: root.toneColor(modelData.tone)
            variant: Model.airpodsVariant(root.batteryState.airpods)
          }

          BoltIcon {
            visible: modelData.charging
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Math.round(button.fontSize * 1.05)
            color: Color.accent
          }

          Text {
            visible: text !== "" && !root.vertical
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: modelData.text
            color: root.toneColor(modelData.tone)
            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            renderType: Text.NativeRendering
          }
        }
      }
    }
  }
}
