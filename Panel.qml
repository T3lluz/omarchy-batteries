import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Every battery, in the same sections, tiles and rows as ROG Deck and Sonus:
// the laptop with its draw, health and the last hours, AirPods bud by bud,
// and the peripherals. The gear swaps them for what the bar shows.
Panel {
  id: root
  moduleName: "io.github.t3lluz.batteries"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var client: null
  // The host widget's WidgetSettings: shell.json as every monitor sees it.
  property var prefs: null
  property bool setupOpen: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var updater: client ? client.updater : null
  readonly property var laptop: client ? client.laptop : null
  readonly property var airpods: client ? client.airpods : null
  readonly property var devices: client ? client.devices : []
  readonly property var speakers: Model.jblSpeakers(devices)
  readonly property var others: Model.otherDevices(devices)
  readonly property int lowThreshold: hostWidget ? hostWidget.lowThreshold : 20
  readonly property bool needsAccess: !!client && client.needsAccess.length > 0
  readonly property var barDevices: Model.idList(setting("barDevices", null))

  readonly property var thresholds: [5, 10, 15, 20, 25, 30]
  readonly property real historyHours: 12
  readonly property var history: client ? client.history : []
  readonly property bool hasHistory: Model.historySince(history, Date.now() / 1000, historyHours).length > 1
  // Null until half an hour on battery has been seen.
  readonly property var drain: Model.drainPerHour(history, Date.now() / 1000, historyHours)

  readonly property var barPicks: Model.barPicks({ laptop: laptop, airpods: airpods, devices: devices })
  readonly property int barPickedCount: {
    var n = 0
    for (var i = 0; i < barPicks.length; i++) if (pickOn(barPicks[i])) n++
    return n
  }

  // The family's rhythm: ROG Deck's gap between sections and between tiles.
  readonly property real sectionGap: Style.space(12)
  readonly property real tileGap: Style.space(8)
  readonly property real iconSize: Style.font.display

  function setting(name, fallback) { return prefs ? prefs.get(name, fallback) : fallback }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }

  function setOption(key, value) {
    if (hostWidget && typeof hostWidget.persistSettings === "function")
      hostWidget.persistSettings(({ [key]: value }))
  }

  function pickOn(pick) {
    if (pick.device) return Model.inBar(pick.device, barDevices)
    return setting(pick.key, pick.fallback) === true
  }

  function togglePick(pick) {
    if (pick.device) setOption("barDevices", Model.toggleBarDevice(barDevices, pick.device.id, devices))
    else setOption(pick.key, !pickOn(pick))
  }

  function levelColor(item) {
    if (Model.isLow(item, lowThreshold) && !item.stale) return urgent
    if (item.stale) return dim
    return foreground
  }

  function heroMeta() {
    if (setupOpen) return "Changes save as you make them"
    if (!client || !client.loaded) return "Reading batteries…"
    if (client.errorText) return client.errorText
    return Model.summary({ laptop: laptop, airpods: airpods, devices: devices }, lowThreshold)
  }

  onOpenedChanged: {
    if (!opened) { setupOpen = false; return }
    if (client) client.pollNow()
    if (panelFlick) panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onSetupOpenChanged: if (panelFlick) panelFlick.contentY = 0

  // One peripheral, laid out like ROG Deck's option rows: icon, name over
  // status, the level on the right and a bar beneath.
  component DeviceRow: Column {
    id: deviceRow
    property var device: null
    readonly property bool hasLevel: !!device && Model.hasLevel(device.level)
    // A JBL speaker has no icon: its title is the JBL mark and the model.
    readonly property bool jbl: !!device && device.source === "jbl"

    width: parent ? parent.width : 0
    spacing: Style.space(6)

    Item {
      width: parent.width
      height: Math.max(Style.font.title, labels.implicitHeight)

      Item {
        id: iconBox
        visible: !deviceRow.jbl
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(22)
        height: Style.font.title

        Icon {
          anchors.centerIn: parent
          name: deviceRow.device ? Model.kindIcon(deviceRow.device.kind) : "battery"
          size: Style.font.title
          color: root.foreground
          opacity: deviceRow.hasLevel ? 1 : 0.6
        }
      }

      Column {
        id: labels
        anchors.left: deviceRow.jbl ? parent.left : iconBox.right
        anchors.leftMargin: deviceRow.jbl ? Style.space(8) : Style.space(10)
        anchors.right: level.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Row {
          width: parent.width
          spacing: Style.space(5)

          // Sized so the mark's letters stand as tall as the name's capitals.
          Icon {
            visible: deviceRow.jbl
            anchors.verticalCenter: parent.verticalCenter
            name: "jbl"
            size: title.font.pixelSize
            width: Math.round(title.font.pixelSize * 1.3)
            color: root.foreground
          }

          Text {
            id: title
            width: parent.width - (deviceRow.jbl ? Math.round(font.pixelSize * 1.3) + parent.spacing : 0)
            textFormat: Text.PlainText
            text: deviceRow.jbl ? Model.jblTitle(deviceRow.device) : deviceRow.device ? deviceRow.device.name : ""
            color: root.foreground
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(4)

          Icon {
            readonly property string conn: deviceRow.device ? Model.connectionIcon(deviceRow.device.connection) : ""
            visible: conn !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: conn || "battery"
            size: Style.font.caption
            color: root.foreground
            opacity: 0.55
          }

          Caption {
            foreground: root.foreground
            fontFamily: root.fontFamily
            width: parent.width - Style.font.caption - parent.spacing
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            text: deviceRow.device ? Model.subtitle(deviceRow.device) : ""
          }
        }
      }

      Row {
        id: level
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        BoltIcon {
          visible: !!deviceRow.device && deviceRow.device.charging
          anchors.verticalCenter: parent.verticalCenter
          implicitHeight: Style.font.body
          color: root.accent
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: deviceRow.device ? Model.percent(deviceRow.device.level) : "--"
          color: deviceRow.hasLevel ? root.levelColor(deviceRow.device) : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }
    }

    LevelBar {
      visible: deviceRow.hasLevel
      x: deviceRow.jbl ? Style.space(8) : Style.space(40)
      width: parent.width - x - Style.space(4)
      level: deviceRow.hasLevel ? deviceRow.device.level : 0
      fill: deviceRow.device && deviceRow.device.charging ? root.accent : (deviceRow.hasLevel ? root.levelColor(deviceRow.device) : root.dim)
      markerColor: root.dim
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function") root.bar.switchPanelFrom(root.hostWidget || root, direction)
      }
      onTextKey: function(t) {
        var key = t.toLowerCase()
        if (key === "r") { if (root.client) root.client.pollNow() }
        else if (key === "c" || key === ",") root.setupOpen = !root.setupOpen
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: root.setupOpen ? "Settings" : "Batteries"
            meta: root.heroMeta()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Icon {
                name: Model.batteryIcon(root.laptop ? root.laptop.level : 100, false)
                size: root.iconSize
                color: root.foreground
              }
            }
            trailingControl: Component {
              Row {
                spacing: Style.space(2)

                PanelActionButton {
                  visible: !root.setupOpen
                  iconText: "󰑐"
                  tooltipText: "Refresh (r)"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: if (root.client) root.client.pollNow()
                }

                PanelActionButton {
                  iconText: root.setupOpen ? "󰁍" : "󰒓"
                  tooltipText: root.setupOpen ? "Back to batteries (c)" : "Settings: the bar, low battery and updates (c)"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.setupOpen = !root.setupOpen
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ======================================================== batteries
          Column {
            visible: !root.setupOpen
            width: parent.width
            spacing: root.sectionGap

            Notice {
              visible: root.needsAccess
              tone: "urgent"
              icon: "lock-open"
              text: {
                if (root.client && root.client.installing) return "Waiting for your password to install the udev rule…"
                if (root.client && root.client.udevInstalled) return "The rule is installed. Unplug and replug the device if this stays."
                return "Your mouse or headset needs a udev rule to be read. It is installed once, with your password."
              }
              actionLabel: "Grant access"
              busy: !!root.client && root.client.installing
              foreground: root.foreground
              accent: root.accent
              urgent: root.urgent
              fontFamily: root.fontFamily
              onActioned: if (root.client) root.client.installAccess()
            }

            Notice {
              readonly property var update: root.updater ? root.updater.notice : null
              visible: !!update
              tone: update ? update.tone : "accent"
              icon: update ? update.icon : ""
              text: update ? update.text : ""
              actionLabel: update && update.actionLabel ? update.actionLabel : ""
              busy: !!update && !!update.busy
              dismissable: !!update && !!update.dismissable
              foreground: root.foreground
              accent: root.accent
              urgent: root.urgent
              fontFamily: root.fontFamily
              onActioned: root.updater.apply()
              onDismissed: root.updater.dismiss()
            }

            // ------------------------------------------------------ laptop
            SectionHeader {
              visible: !!root.laptop
              icon: "device-laptop"
              title: root.laptop && root.laptop.batteries.length > 1 ? "LAPTOP · " + root.laptop.batteries.join(" + ") : "LAPTOP"
              detail: Model.laptopStatus(root.laptop).toUpperCase()
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            // The level, big, with what the pack holds on the right.
            Column {
              visible: !!root.laptop
              width: parent.width
              spacing: Style.space(8)

              Item {
                width: parent.width
                height: bigLevel.implicitHeight

                Row {
                  id: bigLevel
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(4)
                  spacing: Style.space(6)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: root.laptop ? Model.percent(root.laptop.level) : "--"
                    color: root.laptop ? root.levelColor(root.laptop) : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display
                    font.bold: true
                  }

                  BoltIcon {
                    visible: !!root.laptop && root.laptop.charging
                    anchors.verticalCenter: parent.verticalCenter
                    implicitHeight: Style.font.heading
                    color: root.accent
                  }
                }

                Caption {
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(4)
                  text: Model.laptopEnergy(root.laptop)
                }
              }

              LevelBar {
                width: parent.width
                level: root.laptop && Model.hasLevel(root.laptop.level) ? root.laptop.level : 0
                fill: root.laptop && root.laptop.charging ? root.accent : (root.laptop ? root.levelColor(root.laptop) : root.foreground)
                marker: root.laptop && root.laptop.chargeLimit ? root.laptop.chargeLimit : 0
                markerColor: root.dim
              }
            }

            Grid {
              id: laptopTiles
              visible: !!root.laptop
              width: parent.width
              columns: 3
              columnSpacing: root.tileGap
              rowSpacing: root.tileGap

              readonly property real tileWidth: (width - columnSpacing * (columns - 1)) / columns

              Repeater {
                model: Model.laptopTiles(root.laptop)

                StatTile {
                  required property var modelData
                  width: laptopTiles.tileWidth
                  icon: modelData.icon
                  caption: modelData.caption
                  value: modelData.value
                  note: modelData.note
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                }
              }
            }

            // ----------------------------------------------------- history
            PanelSeparator { visible: root.hasHistory; foreground: root.foreground }

            SectionHeader {
              visible: root.hasHistory
              icon: "chart-line"
              title: "LAST " + root.historyHours + " HOURS"
              detail: Model.drainText(root.drain).toUpperCase()
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              visible: root.hasHistory
              width: parent.width
              spacing: Style.space(4)

              HistoryGraph {
                width: parent.width
                samples: root.history
                hours: root.historyHours
                foreground: root.foreground
                accent: root.accent
              }

              Item {
                width: parent.width
                height: axisStart.implicitHeight

                Caption { id: axisStart; foreground: root.foreground; fontFamily: root.fontFamily; anchors.left: parent.left; text: root.historyHours + "h ago" }
                Caption { foreground: root.foreground; fontFamily: root.fontFamily; anchors.horizontalCenter: parent.horizontalCenter; text: root.historyHours / 2 + "h" }
                Caption { foreground: root.foreground; fontFamily: root.fontFamily; anchors.right: parent.right; text: "now" }
              }
            }

            // ----------------------------------------------------- AirPods
            PanelSeparator { visible: !!root.airpods && !!root.laptop; foreground: root.foreground }

            SectionHeader {
              visible: !!root.airpods
              icon: "device-airpods"
              title: root.airpods ? root.airpods.name.toUpperCase() : ""
              detail: Model.airpodsStatus(root.airpods).toUpperCase()
              detailColor: root.airpods && root.airpods.connected ? Qt.darker(root.foreground, 1.15) : root.dim
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              id: podTiles
              visible: !!root.airpods && root.airpods.known
              width: parent.width
              columns: Math.max(1, Model.airpodsTiles(root.airpods).length)
              columnSpacing: root.tileGap

              readonly property real tileWidth: (width - columnSpacing * (columns - 1)) / columns

              Repeater {
                model: Model.airpodsTiles(root.airpods)

                StatTile {
                  required property var modelData
                  readonly property bool stale: !!root.airpods && root.airpods.stale
                  width: podTiles.tileWidth
                  icon: modelData.icon
                  iconColor: modelData.charging ? root.accent : root.foreground
                  caption: modelData.caption
                  value: modelData.value
                  valueColor: modelData.pod && !stale ? root.levelColor(modelData.pod) : root.dim
                  showLevel: true
                  level: modelData.level
                  levelColor: modelData.charging ? root.accent : (stale ? root.dim : root.foreground)
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                }
              }
            }

            Caption {
              foreground: root.foreground
              fontFamily: root.fontFamily
              visible: !!root.airpods && !root.airpods.known
              width: parent.width
              leftPadding: Style.space(8)
              wrapMode: Text.WordWrap
              text: (root.airpods && root.airpods.model ? root.airpods.model + ". " : "") + "Connect them to see each bud and the case."
            }

            // --------------------------------------------------------- JBL
            PanelSeparator {
              visible: (!!root.laptop || !!root.airpods) && root.speakers.length > 0
              foreground: root.foreground
            }

            SectionHeader {
              visible: root.speakers.length > 0
              icon: "jbl"
              title: "SPEAKERS"
              detail: Model.jblStatus(root.speakers).toUpperCase()
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              visible: root.speakers.length > 0
              width: parent.width
              spacing: Style.space(14)

              Repeater {
                model: root.speakers

                DeviceRow {
                  required property var modelData
                  device: modelData
                }
              }
            }

            // ----------------------------------------------------- devices
            PanelSeparator {
              visible: (!!root.laptop || !!root.airpods || root.speakers.length > 0) && root.others.length > 0
              foreground: root.foreground
            }

            SectionHeader {
              visible: root.others.length > 0 || root.devices.length === 0 && !root.laptop && !root.airpods
              icon: "devices"
              title: "DEVICES"
              detail: root.others.length > 0 ? root.others.length + " FOUND" : ""
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Caption {
              foreground: root.foreground
              fontFamily: root.fontFamily
              visible: root.devices.length === 0 && !root.laptop && !root.airpods
              width: parent.width
              leftPadding: Style.space(8)
              wrapMode: Text.WordWrap
              text: root.client && root.client.loaded
                ? "Nothing found yet. Wireless mice, keyboards, headsets, controllers and phones show up here."
                : "Looking for batteries…"
            }

            Column {
              visible: root.others.length > 0
              width: parent.width
              spacing: Style.space(14)

              Repeater {
                model: root.others

                DeviceRow {
                  required property var modelData
                  device: modelData
                }
              }
            }
          }

          // ========================================================= settings
          Column {
            visible: root.setupOpen
            width: parent.width
            spacing: root.sectionGap

            SectionHeader {
              icon: "layout-navbar"
              title: "SHOW IN THE BAR"
              detail: Model.barPickedText(root.barPickedCount)
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              id: barGrid
              width: parent.width
              columns: 2
              columnSpacing: root.tileGap
              rowSpacing: root.tileGap

              readonly property real tileWidth: (width - columnSpacing) / 2

              Repeater {
                model: root.barPicks

                ToggleTile {
                  required property var modelData
                  width: barGrid.tileWidth
                  icon: modelData.icon
                  label: modelData.label
                  hint: modelData.hint || ""
                  checked: root.pickOn(modelData)
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  onToggled: root.togglePick(modelData)
                }
              }
            }

            SwitchRow {
              icon: "percentage"
              label: "Show percentages"
              hint: "Off shows the icons alone"
              checked: root.setting("barPercent", true) === true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onToggled: root.setOption("barPercent", !checked)
            }

            PanelSeparator { foreground: root.foreground }

            SectionHeader {
              icon: "battery-1"
              title: "LOW BATTERY"
              detail: "UNDER " + root.lowThreshold + "%"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Seg {
              options: root.thresholds.map(function(t) { return { value: t, label: t + "%" } })
              value: root.lowThreshold
              foreground: root.foreground
              fontFamily: root.fontFamily
              onPicked: function(value) { root.setOption("lowThreshold", value) }
            }

            SwitchRow {
              icon: "bell"
              label: "Notify when something runs low"
              hint: "The laptop keeps Omarchy's own warning"
              checked: root.setting("notifyLow", true) === true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onToggled: root.setOption("notifyLow", !checked)
            }

            PanelSeparator { foreground: root.foreground }

            UpdateSection {
              icon: "refresh"
              autoCheckIcon: "clock-hour-4"
              name: "Batteries"
              version: root.updater ? root.updater.version : ""
              line: root.updater ? root.updater.line : ""
              available: !!root.updater && root.updater.available
              checking: !!root.updater && root.updater.checking
              busy: !!root.updater && root.updater.busy
              managed: !root.updater || root.updater.managed
              notes: root.updater ? root.updater.notes : []
              showAutoCheck: true
              autoCheck: root.setting("autoUpdateCheck", true) === true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onVisibleChanged: if (visible && root.updater && !root.updater.check && !root.updater.checking) root.updater.checkNow()
              onCheckRequested: root.updater.checkNow()
              onApplyRequested: root.updater.apply()
              onAutoCheckToggled: root.setOption("autoUpdateCheck", !autoCheck)
            }
          }
        }
      }
    }
  }
}
