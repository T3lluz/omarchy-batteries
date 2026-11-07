import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Every battery as one stack of gauges, on the measures of Omarchy's own panels:
// the hero of Power and Bluetooth, then one row per battery with its icon, name,
// state, level and a bar. A bar pulses while charge flows in. The gear swaps the
// list for the settings, which keep the family's panel kit.
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
  // A theme's "red" can be a dark grey. Low must not read quieter than normal.
  readonly property color lowTone: Model.contrast(urgent, Commons.Color.background) >= 3.5 ? urgent : foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var updater: client ? client.updater : null
  readonly property var laptop: client ? client.laptop : null
  readonly property var airpods: client && Model.airpodsShown(client.airpods) ? client.airpods : null
  readonly property var devices: client ? client.devices : []
  readonly property var peripherals: Model.jblSpeakers(devices).concat(Model.otherDevices(devices))
  readonly property int lowThreshold: hostWidget ? hostWidget.lowThreshold : 20
  readonly property bool needsAccess: !!client && client.needsAccess.length > 0
  readonly property var barDevices: Model.idList(setting("barDevices", null))
  readonly property var batteries: ({ laptop: laptop, airpods: airpods, devices: devices })

  readonly property var thresholds: [5, 10, 15, 20, 25, 30]
  readonly property real historyHours: 12
  readonly property var history: client ? client.history : []
  // The average drain on battery over the last hours, from the client's
  // charge history. Null until half an hour on battery has been seen.
  readonly property var drain: Model.drainPerHour(history, Date.now() / 1000, historyHours)

  readonly property var barPicks: Model.barPicks(batteries)
  readonly property int barPickedCount: {
    var n = 0
    for (var i = 0; i < barPicks.length; i++) if (pickOn(barPicks[i])) n++
    return n
  }

  // Icons sit in one column as wide as the hero's, so every name, bar and
  // reading starts under the panel's title.
  readonly property real iconColumn: Style.font.display
  readonly property real textInset: iconColumn + Style.space(14)
  readonly property real rowGap: Style.space(12)

  // The caption under the title (Model.heroPhrases). One line holds still.
  readonly property var phrases: {
    if (setupOpen) return ["Changes save as you make them"]
    if (!client || !client.loaded) return ["Reading batteries"]
    if (client.errorText) return ["Can't read batteries"]
    return Model.heroPhrases(batteries, lowThreshold)
  }
  readonly property bool phrasesTurn: phrases.length > 1
  property int phraseIndex: 0
  readonly property string caption: phrases[phraseIndex % phrases.length]

  readonly property var heroBattery: Model.heroBattery(batteries, lowThreshold)

  // One value for every bar that charges, so they pulse together, on Power's
  // measures: 1 to 0.55 and back, 950 ms each way, only while it can be seen.
  readonly property bool anyCharging: {
    if (laptop && laptop.charging) return true
    // An old reading says nothing about the charger now.
    if (airpods && !airpods.stale) {
      if (airpods.charging) return true
      if (airpods["case"] && airpods["case"].charging) return true
    }
    for (var i = 0; i < devices.length; i++) if (devices[i].charging && !devices[i].stale) return true
    return false
  }
  property real pulse: 1

  SequentialAnimation on pulse {
    running: root.opened && !root.setupOpen && root.anyCharging && !Style.reduceMotion
    loops: Animation.Infinite
    alwaysRunToEnd: true
    NumberAnimation { from: 1; to: 0.55; duration: Style.duration(950); easing.type: Easing.InOutSine }
    NumberAnimation { from: 0.55; to: 1; duration: Style.duration(950); easing.type: Easing.InOutSine }
  }

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

  // A battery's colour: urgent while low. An old reading is dimmed by its row.
  function levelColor(item) {
    return item && !item.stale && Model.isLow(item, lowThreshold) ? lowTone : foreground
  }

  // The mark in front of a level: low first, else what the charger is doing.
  function levelMark(item) {
    return Model.isLow(item, lowThreshold) && !item.stale ? Model.GLYPHS.lowBattery : Model.powerGlyph(item)
  }

  onOpenedChanged: {
    if (!opened) { setupOpen = false; return }
    phraseIndex = 0
    if (client) client.pollNow()
    if (panelFlick) panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onSetupOpenChanged: {
    phraseIndex = 0
    if (panelFlick) panelFlick.contentY = 0
  }
  // Leaving mid-swap would strand the caption half faded.
  onPhrasesTurnChanged: if (!phrasesTurn) {
    phraseSwap.stop()
    heroStatus.opacity = 1
  }

  Timer {
    interval: 2800
    repeat: true
    running: root.opened && root.phrasesTurn
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    NumberAnimation { target: heroStatus; property: "opacity"; to: 0; duration: Style.duration(150); easing.type: Easing.OutCubic }
    ScriptAction { script: root.phraseIndex = (root.phraseIndex + 1) % root.phrases.length }
    NumberAnimation { target: heroStatus; property: "opacity"; to: 1; duration: Style.duration(200); easing.type: Easing.OutCubic }
  }

  // A level with its mark in front: low, a bolt while charging, a plug while on
  // a charger with nothing flowing.
  component Reading: Row {
    id: reading
    property var item: null
    property var level: item ? item.level : null
    property real size: Style.font.title
    readonly property bool known: Model.hasLevel(level)
    readonly property string mark: root.levelMark(item)

    spacing: Style.space(4)

    Glyph {
      visible: reading.mark !== ""
      anchors.verticalCenter: parent.verticalCenter
      icon: reading.mark
      size: reading.size
      color: root.levelColor(reading.item)
      fontFamily: root.fontFamily
    }

    Text {
      textFormat: Text.PlainText
      text: Model.percent(reading.level)
      color: reading.known ? root.levelColor(reading.item) : root.dim
      font.family: root.fontFamily
      font.pixelSize: reading.size
      font.bold: true
    }
  }

  // A battery's bar: how full it is, the charge limit if it has one, pulsing
  // while charge flows in.
  component Gauge: LevelBar {
    id: gauge
    property var item: null
    readonly property color tone: root.levelColor(item)

    level: item && Model.hasLevel(item.level) ? item.level : 0
    fill: item && item.charging && !item.stale ? Qt.rgba(tone.r, tone.g, tone.b, root.pulse) : tone
    track: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    markerColor: root.dim
  }

  // One battery: its icon in the hero's column, the name over the state, the
  // level on the right and a bar across the bottom. `showLevel` is off for
  // AirPods, whose levels sit in the cells under them.
  component BatteryRow: Item {
    id: row
    property var item: null
    property string title: ""
    property string status: ""
    property string icon: ""
    // Drawn marks for what no font has: "jbl", or AirPods in `variant`.
    property string mark: ""
    property string variant: "buds"
    property bool showLevel: true
    property real marker: 0
    property bool stale: !!item && item.stale === true

    width: parent ? parent.width : 0
    implicitHeight: labels.implicitHeight + (showLevel ? Style.space(6) + gauge.height : 0)
    opacity: stale ? 0.6 : 1

    Item {
      x: 0
      y: Math.round((labels.implicitHeight - height) / 2)
      width: root.iconColumn
      height: Style.font.heading

      Glyph {
        visible: row.mark === ""
        anchors.centerIn: parent
        icon: row.icon
        size: Style.font.heading
        color: root.foreground
        fontFamily: root.fontFamily
      }

      Icon {
        visible: row.mark === "jbl"
        anchors.centerIn: parent
        name: "jbl"
        size: Style.font.heading
        width: Math.round(Style.font.heading * 1.25)
        color: root.foreground
      }

      AirPodsIcon {
        visible: row.mark === "airpods"
        anchors.centerIn: parent
        iconSize: Style.font.heading
        variant: row.variant
        color: root.foreground
      }
    }

    Column {
      id: labels
      anchors.left: parent.left
      anchors.leftMargin: root.textInset
      anchors.right: reading.visible ? reading.left : parent.right
      anchors.rightMargin: reading.visible ? Style.space(10) : 0
      spacing: Style.space(1)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: row.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        width: parent.width
        visible: text !== ""
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        text: row.status
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Reading {
      id: reading
      visible: row.showLevel
      anchors.right: parent.right
      y: Math.round((labels.implicitHeight - height) / 2)
      item: row.item
    }

    Gauge {
      id: gauge
      visible: row.showLevel
      anchors.left: labels.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      item: row.item
      marker: row.marker
    }
  }

  // A reading of the laptop's: dim label, value on the right, as Power prints
  // them. A long value wraps rather than running under the label.
  component InfoPair: Item {
    id: pair
    property string label: ""
    property string value: ""

    implicitHeight: Math.max(pairLabel.implicitHeight, pairValue.implicitHeight)

    Text {
      id: pairLabel
      textFormat: Text.PlainText
      text: pair.label
      color: root.foreground
      opacity: 0.6
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      id: pairValue
      anchors.right: parent.right
      width: Math.min(implicitWidth, pair.width - pairLabel.implicitWidth - Style.space(8))
      horizontalAlignment: Text.AlignRight
      wrapMode: Text.WordWrap
      textFormat: Text.PlainText
      text: pair.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // One part of the AirPods, a third of the row: which part and its level over
  // a bar.
  component PodCell: Column {
    id: cell
    property string label: ""
    property var pod: null
    property bool stale: false
    readonly property var reading: pod ? Object.assign({ stale: stale }, pod) : null

    spacing: Style.space(4)
    opacity: stale ? 0.6 : 1

    Item {
      width: parent.width
      height: cellReading.implicitHeight

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: cell.label
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Reading {
        id: cellReading
        anchors.right: parent.right
        item: cell.reading
        level: cell.pod ? cell.pod.level : null
        size: Style.font.bodySmall
      }
    }

    Gauge {
      width: parent.width
      item: cell.reading
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

          // Laid out by hand, as Power and Bluetooth do: PanelHero cuts a
          // caption that does not fit, and this one's text is not ours alone.
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)

            Glyph {
              id: heroIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: root.iconColumn
              icon: root.setupOpen ? Model.GLYPHS.gear : Model.batteryGlyph(root.heroBattery.level, root.heroBattery.charging)
              size: Style.font.display
              color: !root.setupOpen && root.heroBattery.low ? root.lowTone : root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: heroActions.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.setupOpen ? "Settings" : "Batteries"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                id: heroStatus
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                text: root.caption.toUpperCase()
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
              }
            }

            Row {
              id: heroActions
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              PanelActionButton {
                visible: !root.setupOpen
                iconText: Model.GLYPHS.refresh
                tooltipText: "Read batteries now (r)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: if (root.client) root.client.pollNow()
              }

              PanelActionButton {
                iconText: root.setupOpen ? Model.GLYPHS.back : Model.GLYPHS.gear
                tooltipText: root.setupOpen ? "Back to batteries (c)" : "Bar, alerts and updates (c)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.setupOpen = !root.setupOpen
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ======================================================== batteries
          Column {
            visible: !root.setupOpen
            width: parent.width
            spacing: Style.space(14)

            Notice {
              visible: root.needsAccess
              tone: "urgent"
              icon: Model.GLYPHS.key
              text: {
                if (root.client && root.client.installing) return "Waiting for your password…"
                if (root.client && root.client.udevInstalled) return "Access granted. Replug the device if this stays."
                return "A mouse or headset needs access to be read."
              }
              actionLabel: "Grant access"
              busy: !!root.client && root.client.installing
              foreground: root.foreground
              accent: root.accent
              urgent: root.lowTone
              fontFamily: root.fontFamily
              onActioned: if (root.client) root.client.installAccess()
            }

            Notice {
              visible: !!root.client && root.client.errorText !== ""
              tone: "urgent"
              icon: Model.GLYPHS.alert
              text: root.client ? root.client.errorText : ""
              foreground: root.foreground
              accent: root.accent
              urgent: root.lowTone
              fontFamily: root.fontFamily
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
              urgent: root.lowTone
              fontFamily: root.fontFamily
              onActioned: root.updater.apply()
              onDismissed: root.updater.dismiss()
            }

            // ------------------------------------------------------ laptop
            Column {
              visible: !!root.laptop
              width: parent.width
              spacing: Style.space(8)

              BatteryRow {
                item: root.laptop
                title: "Laptop"
                status: Model.laptopStatus(root.laptop)
                icon: Model.kindGlyph("laptop")
                marker: root.laptop && root.laptop.chargeLimit ? root.laptop.chargeLimit : 0
              }

              Grid {
                id: facts
                x: root.textInset
                width: parent.width - x
                columns: 2
                columnSpacing: Style.space(20)
                rowSpacing: Style.spacing.labelGap

                readonly property real cellWidth: (width - columnSpacing) / 2

                Repeater {
                  model: Model.laptopFacts(root.laptop, root.drain)

                  InfoPair {
                    required property var modelData
                    width: facts.cellWidth
                    label: modelData.label
                    value: modelData.value
                  }
                }
              }
            }

            // ----------------------------------------------------- AirPods
            PanelSeparator { visible: !!root.airpods && !!root.laptop; foreground: root.foreground }

            Column {
              id: podsSection
              readonly property var parts: Model.airpodsParts(root.airpods)
              readonly property bool isHeadset: !!root.airpods && root.airpods.isHeadset
              readonly property bool stale: !!root.airpods && root.airpods.stale
              visible: !!root.airpods
              width: parent.width
              spacing: Style.space(8)

              BatteryRow {
                item: podsSection.isHeadset && root.airpods ? Object.assign({ stale: podsSection.stale }, root.airpods.headset) : null
                title: root.airpods ? root.airpods.name : ""
                status: Model.airpodsStatus(root.airpods)
                mark: "airpods"
                variant: Model.airpodsVariant(root.airpods)
                showLevel: podsSection.isHeadset
                stale: podsSection.stale
              }

              Row {
                id: podCells
                visible: !!root.airpods && root.airpods.known && !podsSection.isHeadset
                x: root.textInset
                width: parent.width - x
                spacing: Style.space(12)

                readonly property real cellWidth: (width - spacing * 2) / 3

                Repeater {
                  model: podsSection.isHeadset ? [] : podsSection.parts

                  PodCell {
                    required property var modelData
                    width: podCells.cellWidth
                    label: modelData.label
                    pod: modelData.pod
                    stale: podsSection.stale
                  }
                }
              }
            }

            // ----------------------------------------------------- devices
            PanelSeparator {
              visible: (!!root.laptop || !!root.airpods) && root.peripherals.length > 0
              foreground: root.foreground
            }

            Column {
              visible: root.peripherals.length > 0
              width: parent.width
              spacing: root.rowGap

              Repeater {
                model: root.peripherals

                BatteryRow {
                  required property var modelData
                  readonly property bool jbl: modelData.source === "jbl"
                  item: modelData
                  title: jbl ? Model.jblTitle(modelData) : modelData.name
                  status: Model.subtitle(modelData)
                  icon: Model.kindGlyph(modelData.kind)
                  mark: jbl ? "jbl" : ""
                }
              }
            }

            Text {
              visible: root.devices.length === 0 && !root.laptop && !root.airpods && !!root.client && root.client.loaded && root.client.errorText === ""
              width: parent.width
              textFormat: Text.PlainText
              wrapMode: Text.WordWrap
              text: "Wireless mice, keyboards, headsets, controllers and phones show up here."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          // ========================================================= settings
          Column {
            visible: root.setupOpen
            width: parent.width
            spacing: Style.space(14)

            Column {
              width: parent.width
              spacing: Style.space(10)

              SectionHeader {
                icon: Model.GLYPHS.barTop
                title: "SHOW IN THE BAR"
                detail: Model.barPickedText(root.barPickedCount)
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Grid {
                id: barGrid
                width: parent.width
                columns: 2
                columnSpacing: Style.space(6)
                rowSpacing: Style.space(6)

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
                icon: Model.GLYPHS.percent
                label: "Show percentages"
                checked: root.setting("barPercent", true) === true
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onToggled: root.setOption("barPercent", !checked)
              }
            }

            PanelSeparator { foreground: root.foreground }

            Column {
              width: parent.width
              spacing: Style.space(10)

              SectionHeader {
                icon: Model.GLYPHS.lowBattery
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
                icon: Model.GLYPHS.bell
                label: "Notify when a device runs low"
                checked: root.setting("notifyLow", true) === true
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onToggled: root.setOption("notifyLow", !checked)
              }
            }

            PanelSeparator { foreground: root.foreground }

            UpdateSection {
              icon: Model.GLYPHS.update
              autoCheckIcon: Model.GLYPHS.clock
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
