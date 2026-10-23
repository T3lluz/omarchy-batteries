import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Every battery-powered peripheral with its level, charging state and link.
// Click a device to show it in the bar.
Panel {
  id: root
  moduleName: "io.github.t3lluz.peripheral-battery"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var client: null
  property bool setupOpen: false
  property int cursor: -1

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var devices: client ? client.devices : []
  readonly property var primary: hostWidget ? hostWidget.primary : null
  readonly property int lowThreshold: hostWidget ? hostWidget.lowThreshold : 20
  readonly property bool needsAccess: !!client && client.needsAccess.length > 0

  readonly property var thresholds: [5, 10, 15, 20, 25, 30]

  function open() { root.controller.show() }
  function close() { root.controller.hide() }

  function setOption(key, value) {
    if (hostWidget && typeof hostWidget.persistSettings === "function")
      hostWidget.persistSettings(({ [key]: value }))
  }

  function choose(device) {
    if (device) setOption("device", device.id)
  }

  function heroMeta() {
    if (!client || !client.loaded) return "Looking for devices…"
    if (client.errorText) return client.errorText
    if (!primary) return "No battery-powered peripherals found"
    return Model.subtitle(primary)
  }

  function levelColor(device) {
    if (Model.isLow(device, lowThreshold)) return urgent
    if (device.charging) return accent
    return foreground
  }

  onOpenedChanged: {
    if (!opened) { setupOpen = false; return }
    cursor = -1
    if (client) client.pollNow()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        var n = root.devices.length
        if (n === 0) return
        var d = dy !== 0 ? dy : dx
        root.cursor = root.cursor < 0 ? (d > 0 ? 0 : n - 1) : Math.max(0, Math.min(n - 1, root.cursor + d))
      }
      onActivateRequested: if (root.cursor >= 0) root.choose(root.devices[root.cursor])
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
            title: root.primary ? root.primary.name : "Peripheral Battery"
            meta: root.heroMeta()
            detail: root.primary ? Model.percent(root.primary.level) : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.primary && !root.primary.stale ? 1.0 : 0.55
            iconComponent: Component {
              Item {
                implicitWidth: heroGlyph.implicitWidth
                implicitHeight: heroGlyph.implicitHeight

                Text {
                  id: heroGlyph
                  textFormat: Text.PlainText
                  text: root.primary ? Model.kindIcon(root.primary.kind) : "󰍽"
                  color: root.primary ? root.levelColor(root.primary) : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }

                BoltIcon {
                  visible: !!root.primary && root.primary.charging
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.rightMargin: -Style.space(4)
                  implicitHeight: Math.round(Style.font.display * 0.55)
                  color: root.accent
                }
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
                  tooltipText: root.setupOpen ? "Close settings (c)" : "Settings (c)"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.setupOpen = !root.setupOpen
                }
              }
            }
          }

          // ------------------------------------------------- hidraw access
          Column {
            visible: root.needsAccess
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "Reading this device needs a udev rule that lets your user open its HID node. It is installed once, with your password."
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

          // ------------------------------------------------------ devices
          Column {
            visible: !root.setupOpen
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
              text: "Nothing found. Wireless mice, keyboards, headsets and controllers show up here when the kernel, UPower, openrazer or HeadsetControl can read them."
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
                required property int index
                readonly property bool chosen: !!root.primary && root.primary.id === modelData.id
                readonly property bool hasLevel: modelData.level !== null && modelData.level !== undefined
                readonly property bool highlighted: rowMouse.containsMouse || root.cursor === index

                width: parent.width
                height: rowContent.implicitHeight + Style.space(14)
                radius: Style.cornerRadius
                color: highlighted ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.choose(row.modelData)
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
                    height: Math.max(textCol.implicitHeight, glyph.implicitHeight)

                    Text {
                      id: glyph
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(26)
                      textFormat: Text.PlainText
                      text: Model.kindIcon(row.modelData.kind)
                      color: row.modelData.stale ? root.dim : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.icon
                    }

                    Column {
                      id: textCol
                      anchors.left: glyph.right
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
                        font.bold: row.chosen
                      }

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: Model.subtitle(row.modelData)
                        elide: Text.ElideRight
                        color: row.modelData.status === "no-access" ? root.urgent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
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
                        color: row.hasLevel && !row.modelData.stale ? root.levelColor(row.modelData) : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                      }
                    }
                  }

                  Rectangle {
                    visible: row.hasLevel
                    width: parent.width
                    height: Math.max(3, Style.space(4))
                    radius: height / 2
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

                    Rectangle {
                      width: parent.width * Math.max(0, Math.min(100, row.modelData.level || 0)) / 100
                      height: parent.height
                      radius: parent.radius
                      color: row.modelData.stale ? root.dim : root.levelColor(row.modelData)
                      Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                  }
                }
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
              text: "BAR"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Toggle {
              width: parent.width
              label: "Show the percentage"
              checked: root.setting("showPercent", true) === true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.body
              onClicked: root.setOption("showPercent", !checked)
            }

            Toggle {
              width: parent.width
              label: "Hide when no device is found"
              checked: root.setting("hideWhenEmpty", true) === true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.body
              onClicked: root.setOption("hideWhenEmpty", !checked)
            }

            Toggle {
              width: parent.width
              label: "Pick the bar device automatically"
              description: "The first mouse found. Click a device in the list to pin it instead."
              checked: String(root.setting("device", "")) === ""
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.body
              onClicked: root.setOption("device", checked && root.primary ? root.primary.id : "")
            }

            PanelSeparator { foreground: root.foreground }

            PanelSectionHeader {
              text: "LOW BATTERY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Toggle {
              width: parent.width
              label: "Notify when a device runs low"
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
              text: "Back to devices"
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
