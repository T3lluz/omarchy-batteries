import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Every battery: the laptop with its draw, time left and health, AirPods bud
// by bud, and each peripheral. The gear picks what the bar shows.
Panel {
  id: root
  moduleName: "io.github.t3lluz.batteries"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var client: null
  property bool setupOpen: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var laptop: client ? client.laptop : null
  readonly property var airpods: client ? client.airpods : null
  readonly property var devices: client ? client.devices : []
  readonly property int lowThreshold: hostWidget ? hostWidget.lowThreshold : 20
  readonly property bool needsAccess: !!client && client.needsAccess.length > 0
  readonly property var barDevices: Array.isArray(settings ? settings.barDevices : null) ? settings.barDevices : null

  readonly property var thresholds: [5, 10, 15, 20, 25, 30]
  // Every row's icon box and the gap to its text, so sections line up.
  readonly property real iconSize: Style.font.display
  readonly property real iconGap: Style.space(12)

  readonly property var barOptions: {
    var opts = []
    if (laptop) {
      opts.push({ key: "barLaptop", icon: "device-laptop", label: "Laptop battery", fallback: true })
      opts.push({ key: "barLaptopRate", icon: "bolt", label: "Laptop charge or discharge rate", fallback: false })
      opts.push({ key: "barLaptopTime", icon: "clock-hour-4", label: "Laptop time left or to full", fallback: false })
    }
    if (airpods) {
      opts.push({ key: "barAirpods", icon: "device-airpods", label: airpods.name + " (the emptier bud)", fallback: true })
      if (!airpods.isHeadset) opts.push({ key: "barAirpodsCase", icon: "device-airpods-case", label: airpods.name + " case", fallback: false })
    }
    return opts
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }

  function setOption(key, value) {
    if (hostWidget && typeof hostWidget.persistSettings === "function")
      hostWidget.persistSettings(({ [key]: value }))
  }

  function toggleDevice(device) {
    setOption("barDevices", Model.toggleBarDevice(barDevices, device.id, devices))
  }

  function levelColor(item) {
    if (Model.isLow(item, lowThreshold) && !item.stale) return urgent
    if (item.stale) return dim
    return foreground
  }

  function heroMeta() {
    if (!client || !client.loaded) return "Reading batteries…"
    if (client.errorText) return client.errorText
    var parts = []
    if (laptop) parts.push("Laptop " + Model.percent(laptop.level))
    if (airpods && airpods.known && !airpods.stale) parts.push("AirPods " + Model.percent(airpods.level))
    for (var i = 0; i < devices.length && parts.length < 4; i++) parts.push(Model.kindLabel(devices[i].kind) + " " + Model.percent(devices[i].level))
    return parts.length ? parts.join(" · ") : "No batteries found"
  }

  onOpenedChanged: {
    if (!opened) { setupOpen = false; return }
    if (client) client.pollNow()
    if (panelFlick) panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // A level bar: a track, a fill, and an optional marker (the charge limit).
  component LevelBar: Rectangle {
    id: levelBar
    property real level: 0
    property color fill: root.foreground
    property real marker: 0
    height: Math.max(3, Style.space(4))
    radius: height / 2
    color: root.track

    Rectangle {
      width: parent.width * Math.max(0, Math.min(100, levelBar.level || 0)) / 100
      height: parent.height
      radius: parent.radius
      color: levelBar.fill
      Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    Rectangle {
      visible: levelBar.marker > 0 && levelBar.marker < 100
      x: levelBar.width * levelBar.marker / 100 - width / 2
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(2, Style.space(2))
      height: parent.height * 2.4
      radius: width / 2
      color: root.dim
    }
  }

  // One battery: icon, name over status, level on the right, bar beneath.
  // Laptop, AirPods and every device use it, so they line up.
  component BatteryRow: Column {
    id: batteryRow
    property string icon: "battery"
    property bool airpods: false
    property string variant: "buds"
    property string title: ""
    property string subtitle: ""
    property string subtitleIcon: ""
    property var level: null
    property bool charging: false
    property color tint: root.foreground
    property bool showBar: true
    property real marker: 0
    readonly property bool hasLevel: Model.hasLevel(level)

    width: parent ? parent.width : 0
    spacing: Style.space(6)

    Item {
      width: parent.width
      height: Math.max(iconBox.height, texts.implicitHeight)

      Item {
        id: iconBox
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize
        height: root.iconSize

        Icon {
          visible: !batteryRow.airpods
          anchors.centerIn: parent
          name: batteryRow.icon
          size: root.iconSize
          color: root.foreground
        }

        AirPodsIcon {
          visible: batteryRow.airpods
          anchors.centerIn: parent
          iconSize: root.iconSize
          color: root.foreground
          variant: batteryRow.variant
        }
      }

      Column {
        id: texts
        anchors.left: iconBox.right
        anchors.leftMargin: root.iconGap
        anchors.right: levelRow.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: batteryRow.title
          elide: Text.ElideRight
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        Row {
          width: parent.width
          spacing: Style.space(4)

          Icon {
            visible: batteryRow.subtitleIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: batteryRow.subtitleIcon || "battery"
            size: Style.font.caption
            color: root.dim
          }

          Text {
            width: parent.width - (batteryRow.subtitleIcon !== "" ? Style.font.caption + parent.spacing : 0)
            textFormat: Text.PlainText
            text: batteryRow.subtitle
            elide: Text.ElideRight
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Row {
        id: levelRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(4)

        BoltIcon {
          visible: batteryRow.charging
          anchors.verticalCenter: parent.verticalCenter
          implicitHeight: Math.round(Style.font.title * 1.05)
          color: root.accent
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: Model.percent(batteryRow.level)
          color: batteryRow.hasLevel ? batteryRow.tint : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }
    }

    LevelBar {
      visible: batteryRow.showBar
      width: parent.width
      level: batteryRow.hasLevel ? batteryRow.level : 0
      fill: batteryRow.charging ? root.accent : batteryRow.tint
      marker: batteryRow.marker
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
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
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Batteries"
            meta: root.heroMeta()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Icon {
                name: root.laptop ? Model.batteryIcon(root.laptop.level, root.laptop.charging) : "battery-4"
                size: root.iconSize
                color: root.foreground
              }
            }
            trailingControl: Component {
              Row {
                spacing: Style.space(2)

                PanelActionButton {
                  iconText: "󰑐"
                  tooltipText: "Refresh (r)"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: if (root.client) root.client.pollNow()
                }

                PanelActionButton {
                  iconText: "󰒓"
                  tooltipText: root.setupOpen ? "Close settings (c)" : "Settings: what the bar shows (c)"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.setupOpen = !root.setupOpen
                }
              }
            }
          }

          // ------------------------------------------------- hidraw access
          Column {
            visible: root.needsAccess && !root.setupOpen
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "Reading your mouse or headset needs a udev rule that lets your user open its HID node. It is installed once, with your password."
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Button {
              text: root.client && root.client.installing ? "Waiting for authentication…" : "Grant access"
              iconText: "󰌋"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: if (root.client) root.client.installAccess()
            }

            Text {
              visible: !!root.client && root.client.udevInstalled
              width: parent.width
              textFormat: Text.PlainText
              text: "The rule is installed. Unplug and replug the device if this stays."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ------------------------------------------------------- laptop
          Column {
            visible: !!root.laptop && !root.setupOpen
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { foreground: root.foreground }

            PanelSectionHeader {
              text: "LAPTOP"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            BatteryRow {
              icon: "device-laptop"
              title: root.laptop && root.laptop.batteries.length > 1 ? "Laptop (" + root.laptop.batteries.join(" + ") + ")" : "Laptop"
              subtitle: Model.laptopStatus(root.laptop)
              subtitleIcon: root.laptop && root.laptop.acOnline ? "plug-connected" : ""
              level: root.laptop ? root.laptop.level : null
              charging: !!root.laptop && root.laptop.charging
              tint: root.laptop ? root.levelColor(root.laptop) : root.foreground
              marker: root.laptop && root.laptop.chargeLimit ? root.laptop.chargeLimit : 0
            }

            // Details, indented to the text column above.
            Grid {
              x: root.iconSize + root.iconGap
              width: parent.width - x
              columns: 2
              columnSpacing: Style.space(10)
              rowSpacing: Style.space(6)

              Repeater {
                model: Model.laptopFacts(root.laptop)

                Row {
                  required property var modelData
                  width: (parent.width - parent.columnSpacing) / 2
                  spacing: Style.space(6)

                  Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.icon
                    size: Style.font.body
                    color: root.dim
                  }

                  Column {
                    width: parent.width - Style.font.body - parent.spacing
                    spacing: 0

                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: modelData.label
                      elide: Text.ElideRight
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    Text {
                      width: parent.width
                      textFormat: Text.PlainText
                      text: modelData.value
                      elide: Text.ElideRight
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }
                  }
                }
              }
            }
          }

          // ------------------------------------------------------ AirPods
          Column {
            visible: !!root.airpods && !root.setupOpen
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { foreground: root.foreground }

            PanelSectionHeader {
              text: "AIRPODS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            BatteryRow {
              airpods: true
              variant: Model.airpodsVariant(root.airpods)
              title: root.airpods ? root.airpods.name : ""
              subtitle: root.airpods ? [root.airpods.model, Model.airpodsStatus(root.airpods)].filter(function(s) { return s !== "" && s !== root.airpods.name }).join(" · ") : ""
              subtitleIcon: root.airpods && root.airpods.connected ? "bluetooth" : ""
              level: root.airpods ? root.airpods.level : null
              charging: !!root.airpods && root.airpods.charging
              tint: root.airpods ? root.levelColor(root.airpods) : root.foreground
              // Each part has its own bar below.
              showBar: false
            }

            // Each bud and the case, under the text column like the laptop details.
            Row {
              visible: !!root.airpods && root.airpods.known
              x: root.iconSize + root.iconGap
              width: parent.width - x
              spacing: Style.space(12)

              Repeater {
                id: podParts
                model: Model.airpodsParts(root.airpods)

                Column {
                  required property var modelData
                  readonly property var pod: modelData.pod
                  width: (parent.width - parent.spacing * (podParts.count - 1)) / Math.max(1, podParts.count)
                  spacing: Style.space(4)

                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      textFormat: Text.PlainText
                      text: modelData.label
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    BoltIcon {
                      visible: !!pod && pod.charging
                      anchors.verticalCenter: parent.verticalCenter
                      implicitHeight: Style.font.caption
                      color: root.accent
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: pod ? Model.percent(pod.level) : "--"
                    color: pod ? (root.airpods.stale ? root.dim : root.levelColor(pod)) : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  LevelBar {
                    width: parent.width
                    level: pod ? pod.level : 0
                    fill: pod && pod.charging ? root.accent : (root.airpods && root.airpods.stale ? root.dim : root.foreground)
                  }
                }
              }
            }
          }

          // -------------------------------------------------- peripherals
          Column {
            visible: !root.setupOpen && (root.devices.length > 0 || (!root.laptop && !root.airpods))
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { foreground: root.foreground }

            PanelSectionHeader {
              text: "DEVICES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.devices.length === 0 && !!root.client && root.client.loaded
              width: parent.width
              textFormat: Text.PlainText
              text: "Nothing found. Wireless mice, keyboards, headsets, controllers and phones show up here."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.devices

              BatteryRow {
                required property var modelData
                icon: Model.kindIcon(modelData.kind)
                title: modelData.name
                subtitle: Model.subtitle(modelData)
                subtitleIcon: Model.connectionIcon(modelData.connection)
                level: modelData.level
                charging: modelData.charging
                tint: Model.hasLevel(modelData.level) ? root.levelColor(modelData) : root.dim
              }
            }
          }

          // ----------------------------------------------------- settings
          Column {
            visible: root.setupOpen
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { foreground: root.foreground }

            PanelSectionHeader {
              text: "SHOW IN THE BAR"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.barOptions

              Toggle {
                required property var modelData
                readonly property bool on: root.setting(modelData.key, modelData.fallback) === true
                width: parent.width
                label: modelData.label
                checked: on
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                titleSize: Style.font.body
                onClicked: root.setOption(modelData.key, !on)
              }
            }

            Repeater {
              model: root.devices

              Toggle {
                required property var modelData
                readonly property bool on: Model.inBar(modelData, root.barDevices)
                width: parent.width
                label: modelData.name
                description: Model.kindLabel(modelData.kind) + " · " + Model.subtitle(modelData)
                checked: on
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                titleSize: Style.font.body
                onClicked: root.toggleDevice(modelData)
              }
            }

            Toggle {
              width: parent.width
              label: "Show percentages"
              description: "Turn off for icons only"
              checked: root.setting("barPercent", true) === true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.body
              onClicked: root.setOption("barPercent", !checked)
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "Turn everything off to show only the battery icon."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            PanelSeparator { foreground: root.foreground }

            PanelSectionHeader {
              text: "LOW BATTERY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Toggle {
              width: parent.width
              label: "Notify when something runs low"
              description: "The laptop battery keeps Omarchy's own warning"
              checked: root.setting("notifyLow", true) === true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.body
              onClicked: root.setOption("notifyLow", !checked)
            }

            Flow {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.thresholds

                Button {
                  required property int modelData
                  text: modelData + "%"
                  selected: root.lowThreshold === modelData
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.setOption("lowThreshold", modelData)
                }
              }
            }

            Button {
              text: "Back to batteries"
              iconText: "󰁍"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.setupOpen = false
            }
          }
        }
      }
    }
  }
}
