import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry: the batteries picked in settings, each as a pixel icon and its
// level in the panel's block face, drawn as pixels in the bar's own colours,
// a dark band rising through the icon while it is on a charger. The bar draws this widget once per monitor;
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
  // Everything on whole device pixels, never scaled. Figures in the pixel
  // type stand as tall as the bar's own digits. Icons take the largest sharp
  // size that is not bigger than the shell's own (its icon size, with pixel
  // art's two units clear around the 24): twelve device pixels on a 1.25
  // scale, twenty-four on a 2.
  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
  readonly property int pixelUnit: Math.max(1, Math.round(button.fontSize * 0.72 * dpr / 5))
  readonly property int iconUnit: Math.max(1, Math.floor(Style.bar.iconSize * 24 / 20 * dpr / 12))
  // The panel's and the hover card's text is set in Monocraft, shipped in
  // assets/fonts so it needs no install. The bold is its own file, so bold
  // text is drawn, not smeared. Until it loads, the shell's font stands in.
  readonly property string textFont: monocraft.status === FontLoader.Ready ? monocraft.name : Style.font.family

  FontLoader { id: monocraft; source: Qt.resolvedUrl("assets/fonts/Monocraft.ttf") }
  FontLoader { source: Qt.resolvedUrl("assets/fonts/Monocraft-Bold.ttf") }

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
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "autoUpdateCheck"; value: setting("autoUpdateCheck", true) === true }
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client; property: "liveBar"; value: root.barOptions.laptopRate || root.barOptions.laptopTime }
  // The colours of the low-battery notification's badge: the panel's room
  // colours, the low one while low.
  Binding { restoreMode: Binding.RestoreNone; target: root.client; when: !!root.client && root.isLeader; property: "toneHost"; value: root }
  function alertTone(name, low) {
    var panel = panelLoader.item
    if (!panel) return low ? root.urgent : root.barFg
    return low ? panel.lowTone : panel.toneOf(name)
  }

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
    // The low-battery notification on a made-up level: it goes low, and a
    // few seconds later it is plugged in.
    function previewAlert(): string {
      if (!root.client) return "loading"
      root.client.previewAlert()
      return "ok"
    }
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

  // The hover card: after the shell's tooltip delay, gone the moment the
  // pointer leaves or the panel opens.
  readonly property var hoverRows: Model.hoverRows(batteryState, Date.now() / 1000)
  readonly property bool cardWanted: button.tooltipHovered && !opened && !needsAccess && hoverRows.length > 0
  property bool cardShown: false
  onCardWantedChanged: if (!cardWanted) cardShown = false

  Timer {
    interval: 400
    running: root.cardWanted && !root.cardShown
    onTriggered: root.cardShown = true
  }

  HoverCard {
    target: button
    bar: root.bar
    shown: root.cardShown
    rows: root.hoverRows
    palette: panelLoader.item ? panelLoader.item.palette : ({})
    lowThreshold: root.lowThreshold
    unit: root.pixelUnit
    fontFamily: root.textFont
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    // The hover card below takes the place of the plain tooltip; the plain
    // one stays only to point at the access the panel needs.
    tooltipText: root.needsAccess ? "Batteries: click to grant access to your mouse" : ""
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
      PixelIcon {
        visible: root.shownItems.length === 0
        anchors.verticalCenter: parent.verticalCenter
        name: "battery-medium"
        unit: root.iconUnit
        color: root.needsAccess ? root.urgent : root.barFg
      }

      Repeater {
        model: root.shownItems

        Row {
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3)

          BarIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: modelData.icon
            unit: root.iconUnit
            color: root.toneColor(modelData.tone)
            powered: modelData.powered
          }

          PixelText {
            visible: text !== "" && !root.vertical
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.text
            unit: root.pixelUnit
            color: root.toneColor(modelData.tone)
          }
        }
      }
    }
  }
}
