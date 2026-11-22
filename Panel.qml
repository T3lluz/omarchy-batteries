import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Every battery as a room of its own. A prompt line heads the panel; under
// it each battery gets a tile tinted in a tone from the theme's terminal
// palette, led by its level in a block face, over the battery itself
// (Battery.qml: a body of cells, a tenth each). The batteries fill in from
// empty when the panel opens and charge runs through them while it flows
// in. A click opens a room to its details and its bar switches. The gear
// swaps the rooms for the settings, which keep the family's panel kit.
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

  readonly property real roomPad: Style.space(10)
  readonly property real roomGap: Style.space(3)
  // Room icons: pixel art at about 20 px (24 device pixels on a 1.25 scale).
  readonly property real iconColumn: Math.round(Style.font.heading * 1.25)
  readonly property real textInset: iconColumn + Style.space(10)

  // ------------------------------------------------------------- tones

  // The theme's terminal colours, read from its colors.toml whenever the
  // panel opens, so a theme switch shows on the next open.
  property var palette: ({})

  FileView {
    id: paletteFile
    path: Commons.Color.currentThemePath + "/colors.toml"
    blockLoading: false
    printErrors: false
    onLoaded: root.palette = Model.parsePalette(text())
  }

  // A room's colour (Model.roomToneHex): the theme's colour of that name, or
  // the kind's own hue where the theme's is a grey, softened toward the text
  // colour. The foreground where it would still read too faint. Only the
  // panel's rooms take these; the bar keeps the bar's colours.
  function toneOf(name) {
    var c = Qt.color(Model.roomToneHex(name, palette, String(foreground)))
    return Model.contrast(c, Commons.Color.background) >= 2.6 ? c : foreground
  }

  // A room's tone: its kind's colour, the urgent one while low.
  function roomTone(kind, item) {
    return item && !item.stale && Model.isLow(item, lowThreshold) ? lowTone : toneOf(Model.kindTone(kind))
  }

  // The mark beside a level, a Tabler icon: low first, else what the
  // charger is doing.
  function markOf(item) { return Model.markIcon(item, lowThreshold) }

  // The open room, by key: "laptop", "airpods" or a device id. One at a time.
  property string openRoom: ""
  function toggleRoom(key) { openRoom = openRoom === key ? "" : key }

  // ------------------------------------------------------------- motion

  // One clock for everything that moves, ticking only while something does:
  // charge flowing in somewhere, or a ripple still running.
  readonly property real clockBase: Date.now()
  property real clock: 0
  property real awakeUntil: 0
  readonly property bool live: opened && !setupOpen
  readonly property bool anyCharging: {
    if (laptop && laptop.charging) return true
    // An old reading says nothing about the charger now.
    if (airpods && !airpods.stale) {
      var parts = ["left", "right", "case", "headset"]
      for (var p = 0; p < parts.length; p++) if (airpods[parts[p]] && airpods[parts[p]].charging) return true
    }
    for (var i = 0; i < devices.length; i++) if (devices[i].charging && !devices[i].stale) return true
    return false
  }

  function wake(ms) {
    clock = Date.now() - clockBase
    awakeUntil = Math.max(awakeUntil, clock + ms)
  }

  Timer {
    interval: 70
    repeat: true
    running: root.live && !Style.reduceMotion && (root.anyCharging || root.clock < root.awakeUntil)
    onTriggered: root.clock = Date.now() - root.clockBase
  }

  // "4m ago" moves on by itself.
  property real nowSec: Date.now() / 1000
  Timer {
    interval: 20000
    repeat: true
    running: root.opened
    onTriggered: root.nowSec = Date.now() / 1000
  }

  // --------------------------------------------------------- the prompt

  // The line under the title (Model.heroPhrases), typed out a character at a
  // time behind a cursor. One line holds still.
  readonly property var phrases: {
    if (setupOpen) return ["Changes save as you make them"]
    if (!client || !client.loaded) return ["Reading batteries"]
    if (client.errorText) return ["Can't read batteries"]
    return Model.heroPhrases(batteries, lowThreshold)
  }
  readonly property bool phrasesTurn: phrases.length > 1
  property int phraseIndex: 0
  readonly property string caption: phrases[phraseIndex % phrases.length]
  property int typed: 0
  property bool cursorOn: true

  readonly property var heroBattery: Model.heroBattery(batteries, lowThreshold)

  onCaptionChanged: typed = Style.reduceMotion ? caption.length : 0

  Timer {
    interval: 2800
    repeat: true
    running: root.opened && root.phrasesTurn
    onTriggered: root.phraseIndex = (root.phraseIndex + 1) % root.phrases.length
  }

  Timer {
    interval: 22
    repeat: true
    running: root.opened && root.typed < root.caption.length
    onTriggered: root.typed = Math.min(root.caption.length, root.typed + 1)
  }

  Timer {
    interval: 530
    repeat: true
    running: root.opened && !Style.reduceMotion
    onTriggered: root.cursorOn = !root.cursorOn
  }

  // Reading the batteries by hand spins the refresh icon once.
  property real spin: 0
  NumberAnimation { id: spinRun; target: root; property: "spin"; from: 0; to: 360; duration: Style.duration(620); easing.type: Easing.OutCubic }

  function readNow() {
    if (client) client.pollNow()
    if (!Style.reduceMotion) spinRun.restart()
  }

  // Switching between the rooms and the settings slides the new page in from
  // the side it lives on, and the gear turns (or the arrow nudges) as it does.
  property real pageShift: 0
  property real pageFade: 1
  property real gearTurn: 0
  ParallelAnimation {
    id: pageIn
    NumberAnimation { target: root; property: "pageShift"; to: 0; duration: Style.duration(320); easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "pageFade"; to: 1; duration: Style.duration(220); easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "gearTurn"; to: 0; duration: Style.duration(420); easing.type: Easing.OutCubic }
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

  onOpenedChanged: {
    if (!opened) { setupOpen = false; openRoom = ""; return }
    phraseIndex = 0
    typed = Style.reduceMotion ? caption.length : 0
    nowSec = Date.now() / 1000
    paletteFile.reload()
    if (client) client.pollNow()
    if (panelFlick) panelFlick.contentY = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onSetupOpenChanged: {
    phraseIndex = 0
    typed = Style.reduceMotion ? caption.length : 0
    if (panelFlick) panelFlick.contentY = 0
    if (!opened || Style.reduceMotion) return
    pageShift = Style.space(setupOpen ? 18 : -18)
    pageFade = 0
    gearTurn = setupOpen ? 1 : -1
    pageIn.restart()
  }

  // --------------------------------------------------------- components

  // A battery's tile: its tone washed over the panel, joined to the next by
  // a small gap, as DailyDash's tiles are. When the panel opens the rooms
  // rise into place one after another and each icon acts itself out.
  // Pointing at a room presses the cells of its batteries. A click opens it
  // to its details and bar switches (one room at a time), with a ripple out
  // from the pointer and the icon acting out again.
  component Room: Rectangle {
    id: room
    property string key: ""
    property color tone: root.foreground
    property bool stale: false
    property var cells: []
    // How long after the panel opens this room comes in, in ms.
    property int delay: 0
    // Goes up each time the icon should act itself out.
    property int story: 0
    property real rise: 0
    property real fade: 1
    readonly property bool expanded: root.openRoom === key
    default property alias content: inner.data

    width: parent ? parent.width : 0
    implicitHeight: inner.implicitHeight + root.roomPad * 2
    radius: Style.cornerRadius
    color: Qt.rgba(tone.r, tone.g, tone.b, area.containsMouse || expanded ? 0.11 : 0.065)
    opacity: (stale ? 0.6 : 1) * fade
    transform: Translate { y: room.rise }

    Behavior on color { ColorAnimation { duration: Style.duration(140) } }

    function enter() {
      riseIn.stop()
      if (Style.reduceMotion) { rise = 0; fade = 1; return }
      rise = Style.space(12)
      fade = 0
      riseIn.start()
    }

    Connections {
      target: root
      function onLiveChanged() { if (root.live) room.enter() }
    }

    SequentialAnimation {
      id: riseIn
      PauseAnimation { duration: Style.duration(room.delay) }
      ParallelAnimation {
        NumberAnimation { target: room; property: "rise"; to: 0; duration: Style.duration(460); easing.type: Easing.OutCubic }
        NumberAnimation { target: room; property: "fade"; to: 1; duration: Style.duration(280); easing.type: Easing.OutCubic }
      }
      ScriptAction { script: room.story++ }
    }

    // Under the content, so the switches in an open room take their own
    // clicks; hover reaches it all the same.
    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onPositionChanged: function(mouse) {
        for (var i = 0; i < room.cells.length; i++) {
          var p = room.cells[i].mapFromItem(room, mouse.x, mouse.y)
          room.cells[i].hover(p.x, p.y)
        }
      }
      onExited: { for (var i = 0; i < room.cells.length; i++) room.cells[i].dent = null }
      onClicked: function(mouse) {
        // The clock first: a ripple is stamped with it.
        root.wake(Model.BATTERY.RIPPLE_MS + 200)
        for (var i = 0; i < room.cells.length; i++) {
          var p = room.cells[i].mapFromItem(room, mouse.x, mouse.y)
          room.cells[i].press(p.x, p.y)
        }
        room.story++
        root.toggleRoom(room.key)
      }
    }

    Column {
      id: inner
      x: root.roomPad
      y: root.roomPad
      width: parent.width - root.roomPad * 2
      spacing: Style.space(8)
    }
  }

  // What an open room adds: it slides open under the rest of the room.
  component Drawer: Item {
    id: drawer
    property bool open: false
    default property alias content: drawerColumn.data

    width: parent ? parent.width : 0
    height: open ? drawerColumn.implicitHeight : 0
    visible: height > 0.5
    clip: true
    opacity: open ? 1 : 0

    Behavior on height { NumberAnimation { duration: Style.duration(280); easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }

    Column {
      id: drawerColumn
      width: parent.width
      spacing: Style.space(10)
      topPadding: Style.space(4)
    }
  }

  // A room's first line: icon, name over state, and the level in the block
  // face on the right. The chevron by the name says the room opens.
  component RoomHeader: Item {
    id: head
    property string title: ""
    property string status: ""
    // A pixel icon (Pixels.js).
    property string icon: "battery-medium"
    property color tone: root.foreground
    property bool showFigure: true
    property var value: null
    property string figureMark: ""
    property bool charging: false
    property bool expanded: false
    property int delay: 0
    // The icon's story (Model.storyOf) and a count that plays it each time
    // it goes up.
    property string story: "pop"
    property int tick: 0
    property real k: 1
    readonly property var pose: Model.storyPose(story, k)

    width: parent ? parent.width : 0
    implicitHeight: Math.max(labels.implicitHeight, showFigure ? figure.implicitHeight : 0)

    onTickChanged: if (!Style.reduceMotion) storyRun.restart()

    NumberAnimation {
      id: storyRun
      target: head
      property: "k"
      from: 0
      to: 1
      duration: Style.duration(head.story === "buzz" ? 520 : 660)
    }

    // Moves in whole pixels of its own grid, so it never smears.
    PixelIcon {
      id: iconBox
      x: Math.round((root.iconColumn - width) / 2)
      y: Math.round((head.height - height) / 2)
      name: head.icon
      size: root.iconColumn
      color: head.tone
      transform: Translate { x: head.pose.x * iconBox.cell; y: head.pose.y * iconBox.cell }
    }

    Column {
      id: labels
      anchors.left: parent.left
      anchors.leftMargin: root.textInset
      anchors.right: head.showFigure ? figure.left : parent.right
      anchors.rightMargin: head.showFigure ? Style.space(10) : 0
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Row {
        width: parent.width
        spacing: Style.space(5)

        Text {
          id: titleText
          width: Math.min(implicitWidth, parent.width - chevron.width - parent.spacing)
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: head.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        // Flips when the room opens; turned pixel art would smear on the way.
        PixelIcon {
          id: chevron
          anchors.verticalCenter: titleText.verticalCenter
          name: "chevron-down"
          size: Style.font.caption
          color: root.dim
          rotation: head.expanded ? 180 : 0
        }
      }

      Decode {
        width: parent.width
        visible: value !== ""
        wrapMode: Text.WordWrap
        value: head.status
        delay: head.delay
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    BigFigure {
      id: figure
      visible: head.showFigure
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      value: head.value
      tone: head.tone
      foreground: root.foreground
      mark: head.figureMark
      breathing: head.charging && root.live
      clock: root.clock
      fontFamily: root.fontFamily
    }
  }

  // Text that decodes into place, a terminal's way, when the panel opens.
  // Later changes just swap, so a reading that moves every few seconds
  // stays easy to read.
  component Decode: Text {
    id: dec
    property string value: ""
    property int delay: 0
    property real progress: 1
    property int seed: 0

    textFormat: Text.PlainText
    text: progress >= 1 ? value : Model.scramble(value, progress, seed)

    function run(wait) {
      decodeRun.stop()
      if (Style.reduceMotion) { progress = 1; return }
      seed = seed + 1
      decodeWait.duration = Style.duration(wait)
      progress = 0
      decodeRun.start()
    }

    Connections {
      target: root
      function onLiveChanged() { if (root.live) dec.run(dec.delay) }
    }

    SequentialAnimation {
      id: decodeRun
      PauseAnimation { id: decodeWait; duration: 0 }
      NumberAnimation { target: dec; property: "progress"; to: 1; duration: Style.duration(Math.min(560, 180 + dec.value.length * 14)) }
    }
  }

  // A reading: dim label, value on the right, as Power prints them. A long
  // value wraps rather than running under the label.
  component InfoPair: Item {
    id: pair
    property string label: ""
    property string value: ""
    property int delay: 0

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

    Decode {
      id: pairValue
      anchors.right: parent.right
      width: Math.min(implicitWidth, pair.width - pairLabel.implicitWidth - Style.space(8))
      horizontalAlignment: Text.AlignRight
      wrapMode: Text.WordWrap
      value: pair.value
      delay: pair.delay
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // Readings two to a line.
  component Facts: Grid {
    id: factGrid
    property var facts: []
    property int delay: 0

    visible: facts.length > 0
    width: parent ? parent.width : 0
    columns: 2
    columnSpacing: Style.space(20)
    rowSpacing: Style.spacing.labelGap

    readonly property real cellWidth: (width - columnSpacing) / 2

    Repeater {
      model: factGrid.facts

      InfoPair {
        required property var modelData
        required property int index
        width: factGrid.cellWidth
        label: modelData.label
        value: modelData.value
        delay: factGrid.delay + index * 40
      }
    }
  }

  // An open room's switches for what of it the bar shows: the same picks as
  // the settings page, here where the battery is.
  component RoomPicks: Column {
    id: picks
    property string room: ""
    readonly property var list: Model.roomPicks(root.barPicks, room)

    visible: list.length > 0
    width: parent ? parent.width : 0
    spacing: Style.space(6)

    Repeater {
      model: picks.list

      SwitchRow {
        required property var modelData
        width: picks.width
        // No icon: the kit's are Nerd Font glyphs, the rooms' are Tabler
        // outlines, and the label says it all.
        icon: ""
        label: modelData.inRoom
        checked: root.pickOn(modelData)
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        onToggled: root.togglePick(modelData)
      }
    }
  }

  // One part of the AirPods, a third of the room: which part, its level in
  // the block face over a small battery, and what it is doing or where it
  // went.
  component PodCell: Column {
    id: cell
    property string key: ""
    property string label: ""
    property string icon: "airpods"
    property var pod: null
    property color tone: root.foreground
    property int delay: 0
    readonly property bool seen: !!cell.pod && Model.hasLevel(cell.pod.level)
    readonly property bool stale: !seen || cell.pod.stale === true
    readonly property alias pad: cellPad

    spacing: Style.space(6)
    opacity: !seen ? 0.45 : stale ? 0.6 : 1

    Row {
      spacing: Style.space(5)

      PixelIcon {
        anchors.verticalCenter: parent.verticalCenter
        name: cell.icon
        size: Style.font.bodySmall
        color: cell.tone
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: cell.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    BigFigure {
      value: cell.seen ? cellPad.shown : null
      tone: cell.tone
      foreground: root.foreground
      mark: cell.seen ? root.markOf(cell.pod) : ""
      breathing: cell.seen && cell.pod.charging === true && root.live
      clock: root.clock
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
    }

    Battery {
      id: cellPad
      width: parent.width
      small: true
      segments: 5
      level: cell.seen ? cell.pod.level : 0
      known: cell.seen
      charging: cell.seen && cell.pod.charging === true
      tone: cell.tone
      foreground: root.foreground
      clock: root.clock
      live: root.live
      delay: cell.delay
    }

    Decode {
      width: parent.width
      wrapMode: Text.WordWrap
      value: Model.podPartState(cell.key, cell.pod, root.nowSec)
      delay: cell.delay + 80
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
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
        if (key === "r") root.readNow()
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

          // The title over a prompt line, beside the hero battery as a cell.
          Item {
            width: parent.width
            implicitHeight: Math.max(heroCell.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)

            // The hero battery as the panel's mark.
            Battery {
              id: heroCell
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: Style.font.display * 1.9
              implicitHeight: Style.font.display * 0.95
              segments: 4
              small: true
              nub: true
              level: Model.hasLevel(root.heroBattery.level) ? root.heroBattery.level : 0
              known: Model.hasLevel(root.heroBattery.level)
              charging: root.heroBattery.charging
              tone: root.heroBattery.low ? root.lowTone : root.foreground
              foreground: root.foreground
              clock: root.clock
              live: root.live
            }

            Column {
              id: heroLabels
              anchors.left: heroCell.right
              anchors.leftMargin: Style.space(12)
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
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                // The prompt sign in the accent, the line in the dim colour.
                text: "❯ " + root.caption.substring(0, root.typed) + (root.cursorOn || root.typed < root.caption.length ? "▌" : " ")
                color: !root.setupOpen && root.heroBattery.low ? root.lowTone : Qt.darker(root.foreground, 1.3)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              id: heroActions
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              // The shell's own buttons, with the glyph laid over them so it
              // can turn.
              PanelActionButton {
                id: refreshButton
                visible: !root.setupOpen
                iconText: ""
                tooltipText: "Read batteries now (r)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.readNow()

                Glyph {
                  anchors.centerIn: parent
                  icon: Model.GLYPHS.refresh
                  size: refreshButton.fontSize
                  color: root.foreground
                  fontFamily: root.fontFamily
                  // Turns in quarters, as pixel art does.
                  rotation: Math.round(root.spin / 90) * 90
                }
              }

              PanelActionButton {
                id: gearButton
                iconText: ""
                tooltipText: root.setupOpen ? "Back to batteries (c)" : "Bar, alerts and updates (c)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.setupOpen = !root.setupOpen

                Glyph {
                  anchors.centerIn: parent
                  icon: root.setupOpen ? Model.GLYPHS.back : Model.GLYPHS.gear
                  size: gearButton.fontSize
                  color: root.foreground
                  fontFamily: root.fontFamily
                  // The gear turns a quarter, the arrow nudges in, in whole steps.
                  rotation: root.setupOpen ? 0 : Math.round(root.gearTurn * -2) * 45
                  transform: Translate { x: root.setupOpen ? Math.round(root.gearTurn * 2) * Style.space(2) : 0 }
                }
              }
            }
          }

          // ======================================================== batteries
          Column {
            visible: !root.setupOpen
            width: parent.width
            spacing: root.roomGap
            opacity: root.pageFade
            transform: Translate { x: root.pageShift }

            Column {
              width: parent.width
              spacing: Style.space(8)
              bottomPadding: visible && height > 0 ? Style.space(6) : 0
              visible: root.needsAccess || (!!root.client && root.client.errorText !== "") || (!!root.updater && !!root.updater.notice)

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
            }

            // ------------------------------------------------------ laptop
            Room {
              id: laptopRoom
              readonly property var facts: Model.laptopFacts(root.laptop, root.drain)
              visible: !!root.laptop
              key: "laptop"
              tone: root.roomTone("laptop", root.laptop)
              cells: [laptopPad]
              delay: 0

              RoomHeader {
                title: "Laptop"
                status: Model.laptopStatus(root.laptop)
                icon: Model.kindPixel("laptop")
                tone: laptopRoom.tone
                expanded: laptopRoom.expanded
                story: Model.storyOf("laptop")
                tick: laptopRoom.story
                delay: laptopRoom.delay + 120
                charging: !!root.laptop && root.laptop.charging
                value: root.laptop ? laptopPad.shown : null
                figureMark: root.markOf(root.laptop)
              }

              Battery {
                id: laptopPad
                width: parent.width
                level: root.laptop ? root.laptop.level : 0
                charging: !!root.laptop && root.laptop.charging
                marker: root.laptop && root.laptop.chargeLimit ? root.laptop.chargeLimit : 0
                tone: laptopRoom.tone
                foreground: root.foreground
                clock: root.clock
                live: root.live
                delay: laptopRoom.delay + 80
              }

              // Power and health always; the rest when the room is open.
              Facts {
                facts: laptopRoom.facts.slice(0, 2)
                delay: laptopRoom.delay + 200
              }

              Drawer {
                open: laptopRoom.expanded

                Facts {
                  facts: laptopRoom.facts.slice(2)
                }

                RoomPicks {
                  room: "laptop"
                }
              }
            }

            // ----------------------------------------------------- AirPods
            Room {
              id: podsRoom
              readonly property bool isHeadset: !!root.airpods && root.airpods.isHeadset
              readonly property var headset: isHeadset && root.airpods.headset ? Object.assign({ stale: root.airpods.stale }, root.airpods.headset) : null
              visible: !!root.airpods
              key: "airpods"
              stale: !!root.airpods && root.airpods.stale
              tone: root.toneOf(Model.kindTone("airpods"))
              delay: root.laptop ? 70 : 0
              cells: isHeadset ? [headsetPad] : [leftCell.pad, rightCell.pad, caseCell.pad]

              RoomHeader {
                title: root.airpods ? root.airpods.name : ""
                status: Model.airpodsStatus(root.airpods)
                icon: podsRoom.isHeadset ? "headphone" : "airpods"
                tone: podsRoom.headset ? root.roomTone("airpods", podsRoom.headset) : podsRoom.tone
                expanded: podsRoom.expanded
                story: Model.storyOf("airpods")
                tick: podsRoom.story
                delay: podsRoom.delay + 120
                charging: !!podsRoom.headset && podsRoom.headset.charging
                showFigure: podsRoom.isHeadset
                value: podsRoom.headset ? headsetPad.shown : null
                figureMark: root.markOf(podsRoom.headset)
              }

              Battery {
                id: headsetPad
                visible: podsRoom.isHeadset
                width: parent.width
                level: podsRoom.headset ? podsRoom.headset.level : 0
                known: !!podsRoom.headset
                charging: !!podsRoom.headset && podsRoom.headset.charging
                tone: podsRoom.headset ? root.roomTone("airpods", podsRoom.headset) : podsRoom.tone
                foreground: root.foreground
                clock: root.clock
                live: root.live
                delay: podsRoom.delay + 80
              }

              Row {
                id: podCells
                visible: !podsRoom.isHeadset
                width: parent.width
                spacing: Style.space(12)

                readonly property real cellWidth: (width - spacing * 2) / 3

                PodCell {
                  id: leftCell
                  width: podCells.cellWidth
                  key: "left"
                  label: "Left"
                  pod: root.airpods ? root.airpods.left : null
                  tone: root.roomTone("airpods", pod)
                  delay: podsRoom.delay + 80
                }

                PodCell {
                  id: rightCell
                  width: podCells.cellWidth
                  key: "right"
                  label: "Right"
                  pod: root.airpods ? root.airpods.right : null
                  tone: root.roomTone("airpods", pod)
                  delay: podsRoom.delay + 130
                }

                PodCell {
                  id: caseCell
                  width: podCells.cellWidth
                  key: "case"
                  label: "Case"
                  icon: "airpods-case"
                  pod: root.airpods ? root.airpods["case"] : null
                  tone: root.roomTone("airpods", pod)
                  delay: podsRoom.delay + 180
                }
              }

              Drawer {
                open: podsRoom.expanded

                Facts {
                  facts: Model.airpodsFacts(root.airpods)
                }

                RoomPicks {
                  room: "airpods"
                }
              }
            }

            // ----------------------------------------------------- devices
            Repeater {
              model: root.peripherals

              Room {
                id: deviceRoom
                required property var modelData
                required property int index
                stale: modelData.stale === true
                key: modelData.id
                tone: root.roomTone(modelData.kind, modelData)
                cells: [devicePad]
                delay: ((root.laptop ? 1 : 0) + (root.airpods ? 1 : 0) + index) * 70

                RoomHeader {
                  title: Model.deviceTitle(deviceRoom.modelData)
                  status: Model.subtitle(deviceRoom.modelData)
                  icon: Model.kindPixel(deviceRoom.modelData.kind)
                  tone: deviceRoom.tone
                  expanded: deviceRoom.expanded
                  story: Model.storyOf(deviceRoom.modelData.kind)
                  tick: deviceRoom.story
                  delay: deviceRoom.delay + 120
                  charging: deviceRoom.modelData.charging === true && !deviceRoom.modelData.stale
                  value: Model.hasLevel(deviceRoom.modelData.level) ? devicePad.shown : null
                  figureMark: root.markOf(deviceRoom.modelData)
                }

                Battery {
                  id: devicePad
                  width: parent.width
                  level: Model.hasLevel(deviceRoom.modelData.level) ? deviceRoom.modelData.level : 0
                  known: Model.hasLevel(deviceRoom.modelData.level)
                  charging: deviceRoom.modelData.charging === true && !deviceRoom.modelData.stale
                  tone: deviceRoom.tone
                  foreground: root.foreground
                  clock: root.clock
                  live: root.live
                  delay: deviceRoom.delay + 80
                }

                Drawer {
                  open: deviceRoom.expanded

                  Facts {
                    facts: Model.deviceFacts(deviceRoom.modelData)
                  }

                  RoomPicks {
                    room: deviceRoom.modelData.id
                  }
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

          PanelSeparator { visible: root.setupOpen; foreground: root.foreground }

          // ========================================================= settings
          Column {
            visible: root.setupOpen
            width: parent.width
            opacity: root.pageFade
            transform: Translate { x: root.pageShift }
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
