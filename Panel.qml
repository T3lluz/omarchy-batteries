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

  // A level bar: a track and a fill, urgent when low.
  component LevelBar: Rectangle {
    property real level: 0
    property color fill: root.foreground
    height: Math.max(3, Style.space(4))
    radius: height / 2
    color: root.track

    Rectangle {
      width: parent.width * Math.max(0, Math.min(100, parent.level || 0)) / 100
      height: parent.height
      radius: parent.radius
      color: parent.fill
      Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
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
                size: Style.font.display
                color: root.laptop ? root.levelColor(root.laptop) : root.foreground
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

            Item {
              width: parent.width
              height: Math.max(lapIcon.height, lapText.implicitHeight)

              Icon {
                id: lapIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: "device-laptop"
                size: Style.font.display
                color: root.foreground
              }

              Column {
                id: lapText
                anchors.left: lapIcon.right
                anchors.leftMargin: Style.space(10)
                anchors.right: lapLevel.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: Model.laptopStatus(root.laptop)
                  elide: Text.ElideRight
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  width: parent.width
                  visible: !!root.laptop && root.laptop.batteries.length > 1
                  textFormat: Text.PlainText
                  text: root.laptop ? root.laptop.batteries.join(" + ") : ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Row {
                id: lapLevel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                BoltIcon {
                  visible: !!root.laptop && root.laptop.charging
                  anchors.verticalCenter: parent.verticalCenter
                  implicitHeight: Math.round(Style.font.title * 1.0)
                  color: root.accent
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: root.laptop ? Model.percent(root.laptop.level) : ""
                  color: root.laptop ? root.levelColor(root.laptop) : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }
            }

            LevelBar {
              width: parent.width
              level: root.laptop ? root.laptop.level : 0
              fill: root.laptop ? (root.laptop.charging ? root.accent : root.levelColor(root.laptop)) : root.foreground

              // The charge limit, marked on the track.
              Rectangle {
                visible: !!root.laptop && !!root.laptop.chargeLimit
                x: parent.width * (root.laptop && root.laptop.chargeLimit ? root.laptop.chargeLimit : 100) / 100 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(2, Style.space(2))
                height: parent.height * 2.4
                radius: width / 2
                color: root.dim
              }
            }

            Grid {
              width: parent.width
              columns: 2
              columnSpacing: Style.space(10)
              rowSpacing: Style.space(6)

              Repeater {
                model: Model.laptopFacts(root.laptop)

                Row {
                  required property var modelData
                  width: (column.width - Style.space(10)) / 2
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

            Item {
              width: parent.width
              height: Math.max(podsIcon.height, podsTitle.implicitHeight)

              AirPodsIcon {
                id: podsIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconSize: Style.font.display
                color: root.airpods && root.airpods.known && !root.airpods.stale ? root.foreground : root.dim
                variant: Model.airpodsVariant(root.airpods)
              }

              Column {
                id: podsTitle
                anchors.left: podsIcon.right
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: root.airpods ? root.airpods.name + (root.airpods.model && root.airpods.model !== root.airpods.name ? "  ·  " + root.airpods.model : "") : ""
                  elide: Text.ElideRight
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: Model.airpodsStatus(root.airpods)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Row {
              visible: !!root.airpods && root.airpods.known
              width: parent.width
              spacing: Style.space(10)

              Repeater {
                id: podParts
                model: Model.airpodsParts(root.airpods)

                Column {
                  required property var modelData
                  readonly property var pod: modelData.pod
                  width: (parent.width - parent.spacing * (podParts.count - 1)) / Math.max(1, podParts.count)
                  spacing: Style.space(5)

                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(4)

                    Icon {
                      visible: modelData.icon !== "airpods"
                      anchors.verticalCenter: parent.verticalCenter
                      name: modelData.icon
                      size: Style.font.display
                      color: pod ? root.foreground : root.dim
                    }

                    AirPodsIcon {
                      visible: modelData.icon === "airpods"
                      anchors.verticalCenter: parent.verticalCenter
                      iconSize: Style.font.display
                      color: pod ? root.foreground : root.dim
                      variant: Model.airpodsVariant(root.airpods)
                    }

                    BoltIcon {
                      visible: !!pod && pod.charging
                      anchors.verticalCenter: parent.verticalCenter
                      implicitHeight: Math.round(Style.font.body * 1.1)
                      color: root.accent
                    }
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: pod ? Model.percent(pod.level) : "--"
                    color: pod ? (root.airpods.stale ? root.dim : root.levelColor(pod)) : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: modelData.label + (pod && pod.inEar ? " · in ear" : "")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
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
            spacing: Style.space(4)

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

              Rectangle {
                id: row
                required property var modelData
                readonly property bool shown: Model.inBar(modelData, root.barDevices)
                readonly property bool hasLevel: Model.hasLevel(modelData.level)

                width: parent.width
                height: rowContent.implicitHeight + Style.space(14)
                radius: Style.cornerRadius
                color: rowMouse.containsMouse ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleDevice(row.modelData)
                }

                Column {
                  id: rowContent
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(6)

                  Item {
                    width: parent.width
                    height: Math.max(textCol.implicitHeight, glyph.height)

                    Icon {
                      id: glyph
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      name: Model.kindIcon(row.modelData.kind)
                      size: Style.font.display
                      color: row.modelData.stale ? root.dim : root.foreground
                    }

                    Column {
                      id: textCol
                      anchors.left: glyph.right
                      anchors.leftMargin: Style.space(10)
                      anchors.right: levelRow.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(1)

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: row.modelData.name
                        elide: Text.ElideRight
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: row.shown
                      }

                      Row {
                        spacing: Style.space(4)

                        Icon {
                          visible: name !== ""
                          anchors.verticalCenter: parent.verticalCenter
                          name: Model.connectionIcon(row.modelData.connection)
                          size: Style.font.caption
                          color: root.dim
                        }

                        Text {
                          textFormat: Text.PlainText
                          text: Model.subtitle(row.modelData)
                          color: row.modelData.status === "no-access" ? root.urgent : root.dim
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
                        visible: row.modelData.charging
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: Math.round(Style.font.body * 1.1)
                        color: root.accent
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: Model.percent(row.modelData.level)
                        color: row.hasLevel ? root.levelColor(row.modelData) : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                      }
                    }
                  }

                  LevelBar {
                    visible: row.hasLevel
                    width: parent.width
                    level: row.modelData.level || 0
                    fill: row.modelData.charging ? root.accent : root.levelColor(row.modelData)
                  }
                }
              }
            }

            Text {
              visible: root.devices.length > 0
              width: parent.width
              textFormat: Text.PlainText
              text: "Click a device to show or hide it in the bar. Bold ones are shown."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
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
