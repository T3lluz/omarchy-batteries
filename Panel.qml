import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Every battery, each device drawn big with its level beside it: the laptop
// with its readings, AirPods bud by bud, then the peripherals. Anything that
// charges pulses. The gear swaps them for the settings, which keep the
// family's panel kit.
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
  readonly property var airpods: client && Model.airpodsShown(client.airpods) ? client.airpods : null
  readonly property var devices: client ? client.devices : []
  readonly property var speakers: Model.jblSpeakers(devices)
  readonly property var others: Model.otherDevices(devices)
  readonly property int lowThreshold: hostWidget ? hostWidget.lowThreshold : 20
  readonly property bool needsAccess: !!client && client.needsAccess.length > 0
  readonly property var barDevices: Model.idList(setting("barDevices", null))

  readonly property var thresholds: [5, 10, 15, 20, 25, 30]
  readonly property real historyHours: 12
  readonly property var history: client ? client.history : []
  // The average drain on battery over the last hours, from the client's
  // charge history. Null until half an hour on battery has been seen.
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
  // The gap between a name and its status line.
  readonly property real lineGap: Style.space(3)
  readonly property real budNumberSize: Math.round(Style.font.display * 1.75)
  // A device's icon runs from its name's cap height to its status's
  // baseline.
  readonly property real deviceIconSize: nameType.height + lineGap + smallType.height - capInset(nameType) - smallType.descent

  // How far below a line's top its capitals start.
  function capInset(metrics) { return metrics.ascent - metrics.tightBoundingRect("H").height }

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

  // A reading as the panel prints it: the number big, the percent sign small
  // and dim beside it, or two dashes when there is none.
  component Reading: Row {
    id: reading
    property var level: null
    property real size: Style.font.heading
    property color color: root.foreground
    readonly property bool known: Model.hasLevel(level)

    spacing: Style.space(1)

    Text {
      id: number
      textFormat: Text.PlainText
      text: reading.known ? String(Math.round(reading.level)) : "--"
      color: reading.known ? reading.color : root.dim
      font.family: root.fontFamily
      font.pixelSize: reading.size
      font.bold: true
    }

    Text {
      visible: reading.known
      anchors.baseline: number.baseline
      textFormat: Text.PlainText
      text: "%"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Math.round(reading.size * 0.5)
      font.bold: true
    }
  }

  // A Tabler icon, filled where Tabler has a filled one, for kinds without a
  // drawing of their own. Fitted by what it draws rather than its 24-unit box,
  // so it can start and end on a line of text. `ink` is the drawing's extent on
  // Tabler's grid as [left, top, right, bottom], and the item is that box.
  component InkIcon: Item {
    id: inkIcon
    property string name: "battery"
    property var ink: [2, 2, 22, 22]
    property color color: root.foreground
    readonly property real unit: height / (ink[3] - ink[1])

    Icon {
      name: inkIcon.name
      solid: true
      size: inkIcon.unit * 24
      color: inkIcon.color
      x: -inkIcon.unit * inkIcon.ink[0]
      y: -inkIcon.unit * inkIcon.ink[1]
    }
  }

  // One bud: half of the AirPods drawing, cut where the pair meets and set
  // against the inner edge, so the two buds face each other. Its ink fills
  // the item's height.
  component BudArt: Item {
    id: budArt
    property bool rightBud: false
    property string variant: "pro"
    property color color: root.foreground
    clip: true

    AirPodsIcon {
      id: pair
      variant: budArt.variant
      color: budArt.color
      // The pair is fitted by its width, so this makes its ink as tall as
      // the bud's box.
      iconSize: budArt.height * pair.ink[2] / pair.ink[3]
      x: budArt.rightBud ? -iconSize / 2 : budArt.width - iconSize / 2
      y: -(iconSize - budArt.height) / 2
    }
  }

  // A bud's level beside it, set against the bud. The label says which bud,
  // or that it is charging, on one line so both buds keep one height.
  component BudReading: Column {
    id: budReading
    property var pod: null
    property string label: ""
    property bool alignRight: false
    property bool stale: false

    // Room for "100%" at the bud size.
    width: Math.round(root.budNumberSize * 2.2)
    spacing: Style.space(2)

    Reading {
      anchors.right: budReading.alignRight ? parent.right : undefined
      level: budReading.pod ? budReading.pod.level : null
      size: root.budNumberSize
      color: budReading.pod && !budReading.stale ? root.levelColor(budReading.pod) : root.dim
    }

    Text {
      width: parent.width
      horizontalAlignment: budReading.alignRight ? Text.AlignRight : Text.AlignLeft
      textFormat: Text.PlainText
      text: budReading.pod && budReading.pod.charging ? "Charging" : budReading.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // One peripheral: its icon (pulsing while on power), the name over its
  // status, and the reading on the right. The icon runs from the name's cap
  // height to the status's baseline.
  component DeviceRow: Item {
    id: deviceRow
    property var device: null
    readonly property bool hasLevel: !!device && Model.hasLevel(device.level)
    // A JBL speaker's title is the JBL mark and the model.
    readonly property bool jbl: !!device && device.source === "jbl"

    width: parent ? parent.width : 0
    height: labels.implicitHeight

    // The drawings share one column, as wide as a keyboard needs, so every
    // name starts at the same place.
    ChargeGlyph {
      id: deviceGlyph
      readonly property string drawing: deviceRow.device ? Model.kindGlyph(deviceRow.device.kind) : ""
      x: Style.space(2)
      y: root.capInset(nameType)
      width: Math.round(root.deviceIconSize * 1.5)
      height: root.deviceIconSize
      charging: !!deviceRow.device && (deviceRow.device.powered === true || deviceRow.device.charging === true)
      opacity: deviceRow.hasLevel && !deviceRow.device.stale ? 1 : 0.6
      glyph: Component {
        Item {
          DeviceGlyph {
            visible: deviceGlyph.drawing !== ""
            anchors.fill: parent
            name: deviceGlyph.drawing
            color: root.foreground
          }

          InkIcon {
            visible: deviceGlyph.drawing === ""
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            width: height
            name: deviceRow.device ? Model.kindIcon(deviceRow.device.kind) : "battery"
          }
        }
      }
    }

    Column {
      id: labels
      anchors.left: deviceGlyph.right
      anchors.leftMargin: Style.space(16)
      anchors.right: level.left
      anchors.rightMargin: Style.space(12)
      spacing: root.lineGap

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
          wrapMode: Text.WordWrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(5)

        Icon {
          id: connIcon
          readonly property string conn: deviceRow.device ? Model.connectionIcon(deviceRow.device.connection) : ""
          visible: conn !== ""
          anchors.verticalCenter: status.verticalCenter
          name: conn || "battery"
          size: Style.font.caption
          color: root.dim
        }

        Text {
          id: status
          width: parent.width - (connIcon.visible ? connIcon.width + parent.spacing : 0)
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: deviceRow.device ? Model.subtitle(deviceRow.device) : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    Reading {
      id: level
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: deviceGlyph.verticalCenter
      level: deviceRow.hasLevel ? deviceRow.device.level : null
      size: Style.font.display
      color: deviceRow.hasLevel ? root.levelColor(deviceRow.device) : root.dim
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
          // Roomier than the settings: the drawings need air around them.
          Column {
            visible: !root.setupOpen
            width: parent.width
            spacing: Style.space(20)

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

            // Type measured once, so drawings can line up with text: from the
            // cap height of a first line to the baseline of a last.
            FontMetrics { id: statusType; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
            FontMetrics { id: nameType; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
            FontMetrics { id: smallType; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            FontMetrics { id: budType; font.family: root.fontFamily; font.pixelSize: root.budNumberSize; font.bold: true }

            // ------------------------------------------------------ laptop
            // The laptop drawn as tall as what it is doing and its readings
            // beside it, with its level on the screen.
            Item {
              visible: !!root.laptop
              width: parent.width
              height: laptopInfo.implicitHeight

              // As tall as the readings, from the status's cap height to the
              // last row's baseline, in the drawing's own proportions
              // (Glyphs.js). The readings have a fixed width, so the drawing
              // can size from their height without a loop; past the room
              // left it shrinks and centres.
              Item {
                id: laptopArt
                readonly property real span: laptopInfo.implicitHeight - root.capInset(statusType) - smallType.descent
                readonly property real room: parent.width - laptopInfo.width - Style.space(20) - x
                x: Style.space(2)
                width: Math.min(room, Math.round(span * 44 / 27.4))
                height: Math.round(width * 27.4 / 44)
                y: root.capInset(statusType) + (span - height) / 2

                // Pulses while plugged in, full or not, so a connected
                // charger always shows.
                ChargeGlyph {
                  id: laptopGlyph
                  anchors.fill: parent
                  charging: !!root.laptop && (root.laptop.acOnline || root.laptop.charging)
                  glyph: Component { DeviceGlyph { name: "laptop"; color: root.foreground } }
                }

                // On the display, which is centred at 0.41 of the drawing's
                // height and is 0.69 of it tall.
                Reading {
                  anchors.horizontalCenter: parent.horizontalCenter
                  y: Math.round(laptopArt.height * 0.41 - height / 2)
                  level: root.laptop ? root.laptop.level : null
                  size: Math.round(laptopArt.height * 0.3)
                  color: root.laptop ? root.levelColor(root.laptop) : root.dim
                }
              }

              Column {
                id: laptopInfo
                anchors.right: parent.right
                anchors.rightMargin: Style.space(2)
                width: Style.space(156)
                spacing: Style.space(4)

                Text {
                  width: parent.width
                  bottomPadding: Style.space(4)
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  text: Model.statusLines(Model.laptopStatus(root.laptop))
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                }

                // Label on the left, reading on the right: power, health,
                // the limit, energy and the average drain.
                Repeater {
                  model: Model.laptopFacts(root.laptop, root.drain)

                  Item {
                    required property var modelData
                    width: laptopInfo.width
                    height: Math.max(factLabel.implicitHeight, factValue.implicitHeight)

                    Text {
                      id: factLabel
                      textFormat: Text.PlainText
                      text: modelData.label
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                    }

                    Text {
                      id: factValue
                      anchors.right: parent.right
                      width: Math.min(implicitWidth, parent.width - factLabel.implicitWidth - Style.space(10))
                      horizontalAlignment: Text.AlignRight
                      wrapMode: Text.WordWrap
                      textFormat: Text.PlainText
                      text: modelData.value
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }
                  }
                }
              }
            }

            // ----------------------------------------------------- AirPods
            PanelSeparator { visible: !!root.airpods && !!root.laptop; foreground: root.foreground }

            Column {
              visible: !!root.airpods
              width: parent.width
              spacing: Style.space(18)

              Item {
                width: parent.width
                height: Math.max(podName.implicitHeight, podStatus.implicitHeight)

                Text {
                  id: podName
                  x: Style.space(2)
                  textFormat: Text.PlainText
                  text: root.airpods ? root.airpods.name : ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Text {
                  id: podStatus
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(2)
                  anchors.baseline: podName.baseline
                  width: parent.width - podName.implicitWidth - Style.space(20)
                  horizontalAlignment: Text.AlignRight
                  wrapMode: Text.WordWrap
                  textFormat: Text.PlainText
                  text: Model.airpodsStatus(root.airpods)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              // The buds face each other, each with its level on its own
              // side, drawn as tall as the reading beside it.
              Row {
                id: budRow
                readonly property var parts: Model.airpodsParts(root.airpods)
                readonly property bool stale: !!root.airpods && root.airpods.stale
                readonly property real inkTop: root.capInset(budType)
                readonly property real inkHeight: leftReading.height - inkTop - smallType.descent
                visible: !!root.airpods && root.airpods.known && !root.airpods.isHeadset
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(18)

                BudReading {
                  id: leftReading
                  alignRight: true
                  pod: budRow.parts.length > 0 ? budRow.parts[0].pod : null
                  label: "Left"
                  stale: budRow.stale
                }

                Row {
                  y: budRow.inkTop
                  spacing: Style.space(12)

                  Repeater {
                    model: 2

                    ChargeGlyph {
                      id: bud
                      required property int index
                      readonly property var pod: budRow.parts.length > index ? budRow.parts[index].pod : null
                      height: budRow.inkHeight
                      // One bud's ink is about 0.73 of its height.
                      width: Math.ceil(height * 0.74)
                      charging: !!pod && pod.charging === true
                      opacity: budRow.stale ? 0.6 : 1
                      glyph: Component {
                        BudArt { rightBud: bud.index === 1; variant: Model.airpodsVariant(root.airpods) }
                      }
                    }
                  }
                }

                BudReading {
                  pod: budRow.parts.length > 1 ? budRow.parts[1].pod : null
                  label: "Right"
                  stale: budRow.stale
                }
              }

              // The case, quieter, under the buds.
              Row {
                readonly property var pod: root.airpods ? root.airpods["case"] : null
                visible: !!root.airpods && root.airpods.known && !root.airpods.isHeadset
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(8)

                ChargeGlyph {
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(16)
                  width: Math.round(height * 40 / 30)
                  charging: !!parent.pod && parent.pod.charging === true
                  glyph: Component { DeviceGlyph { name: "airpods-case"; color: root.foreground } }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: parent.pod && parent.pod.charging ? "Case charging" : "Case"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Reading {
                  anchors.verticalCenter: parent.verticalCenter
                  level: parent.pod ? parent.pod.level : null
                  size: Style.font.subtitle
                  color: parent.pod ? root.levelColor(parent.pod) : root.dim
                }
              }

              // AirPods Max: one drawing as tall as the reading.
              Row {
                id: headsetRow
                readonly property var pod: root.airpods ? root.airpods.headset : null
                visible: !!root.airpods && root.airpods.known && root.airpods.isHeadset
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(18)

                ChargeGlyph {
                  y: root.capInset(budType)
                  height: headsetReading.height - y - smallType.descent
                  width: height
                  charging: !!headsetRow.pod && headsetRow.pod.charging === true
                  glyph: Component { AirPodsIcon { iconSize: height; variant: "max"; color: root.foreground } }
                }

                BudReading {
                  id: headsetReading
                  pod: headsetRow.pod
                  label: root.airpods && root.airpods.model ? root.airpods.model : "AirPods Max"
                  stale: !!root.airpods && root.airpods.stale
                }
              }

              Caption {
                foreground: root.foreground
                fontFamily: root.fontFamily
                visible: !!root.airpods && !root.airpods.known
                width: parent.width
                leftPadding: Style.space(2)
                wrapMode: Text.WordWrap
                text: (root.airpods && root.airpods.model ? root.airpods.model + ". " : "") + "Waiting for each bud and the case…"
              }
            }

            // ------------------------------------------------ JBL, devices
            PanelSeparator {
              visible: (!!root.laptop || !!root.airpods) && root.speakers.length + root.others.length > 0
              foreground: root.foreground
            }

            Column {
              visible: root.speakers.length + root.others.length > 0
              width: parent.width
              spacing: Style.space(20)

              Repeater {
                model: root.speakers.concat(root.others)

                DeviceRow {
                  required property var modelData
                  device: modelData
                }
              }
            }

            Caption {
              foreground: root.foreground
              fontFamily: root.fontFamily
              visible: root.devices.length === 0 && !root.laptop && !root.airpods
              width: parent.width
              leftPadding: Style.space(2)
              wrapMode: Text.WordWrap
              text: root.client && root.client.loaded
                ? "Nothing found yet. Wireless mice, keyboards, headsets, controllers and phones show up here."
                : "Looking for batteries…"
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
