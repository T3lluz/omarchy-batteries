import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// The card that drops in at the top of the focused screen when AirPods
// arrive: they connect, or the case's lid opens (Model.airpodsArrival,
// BatteryClient.airpodsArrived). It is the panel's AirPods room taken apart:
// a room with the name over a prompt line, then a room each for the left
// bud, the right bud and the case, each with its level in the block face
// over a battery and what it is doing. It slides out from under the bar,
// stays six seconds (while the pointer rests on it, as long as it does), and
// slides back. A click opens the panel; a right-click sends it away.
//
// Top centre, so it never lands on the notification deck, which hangs from
// the top-right corner. One window for the whole shell, owned by the leading
// bar widget, mapped fresh on each arrival so a monitor that goes away takes
// nothing with it.
PanelWindow {
  id: card

  // The bar widget's client, bar, fonts and low line.
  property var client: null
  property var bar: null
  property string fontFamily: Style.font.family
  property string shellFamily: Style.font.family
  property int lowThreshold: 20

  signal openPanel()

  // ------------------------------------------------------------- state

  // "connected" or "opened", which words the prompt starts with.
  property string reason: ""
  // Made-up AirPods for `previewAirpods`, in place of the client's.
  property var preview: null
  readonly property var pods: preview ? preview : (client ? client.airpods : null)
  readonly property var parts: Model.airpodsCardParts(pods)

  // Waiting for a level: a connection lands a moment before the buds say
  // how full they are.
  property bool pending: false
  // The window is up, from the first frame to the end of its slide back.
  property bool mapped: false
  // Shown at the window's real scale, and not on its way out.
  property bool live: false
  property bool leaving: false

  function arrive(why, previewPods) {
    reason = why || "connected"
    preview = previewPods || null
    if (mapped && !leaving) {
      // Already up: it stays for the new news.
      hideTimer.interval = 6000
      hideTimer.restart()
      return
    }
    if (Model.airpodsCardReady(pods)) present()
    else {
      pending = true
      waitTimer.restart()
    }
  }

  onPodsChanged: if (pending && Model.airpodsCardReady(pods)) present()

  Timer {
    id: waitTimer
    interval: 4000
    // No level in four seconds: the card says what it knows, if anything.
    onTriggered: if (card.pending) {
      if (card.pods && card.pods.known) card.present()
      else card.pending = false
    }
  }

  function present() {
    pending = false
    waitTimer.stop()
    liftOut.stop()
    leaving = false
    nowSec = Date.now() / 1000
    paletteFile.reload()
    targetScreen = focusedScreen()
    Hyprland.refreshMonitors()
    mapped = true
  }

  function dismiss() {
    pending = false
    hideTimer.stop()
    if (!mapped || leaving) return
    leaving = true
    if (Style.reduceMotion || !live) { finish(); return }
    dropIn.stop()
    liftOut.start()
  }

  function finish() {
    mapped = false
    live = false
    leaving = false
    preview = null
    revealed = false
  }

  // Six seconds, and more while the pointer is on it.
  Timer {
    id: hideTimer
    interval: 6000
    onTriggered: if (!cardArea.containsMouse) card.dismiss()
  }

  // ------------------------------------------------------------ window

  property var targetScreen: null
  readonly property var targetMonitor: {
    var monitors = Hyprland.monitors.values
    for (var i = 0; i < monitors.length; i++)
      if (targetScreen && monitors[i].name === targetScreen.name) return monitors[i]
    return null
  }

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || "") : ""
    for (var i = 0; i < Quickshell.screens.length; i++)
      if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (card.mapped && Quickshell.screens.indexOf(card.targetScreen) < 0) card.finish()
    }
  }

  // Under the bar when it is on top, else from the top edge.
  readonly property real barEdge: {
    if (!bar || bar.barHidden || String(bar.position || "top") !== "top") return 0
    var size = typeof bar.barSizeFor === "function" && targetScreen ? Number(bar.barSizeFor(targetScreen.name)) : NaN
    return isFinite(size) && size > 0 ? size : Style.bar.sizeHorizontal
  }
  // The gap under the bar, on whole device pixels.
  readonly property real dpr: devicePixelRatio > 0 ? devicePixelRatio : 1
  readonly property real gap: Math.round(Math.max(Style.gapsOut, Style.space(6)) * dpr) / dpr

  visible: mapped && !!targetScreen
  screen: targetScreen
  color: "transparent"
  anchors.top: true
  margins.top: barEdge
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.namespace: "omarchy-batteries-airpods"
  implicitWidth: Math.ceil(frame.width)
  implicitHeight: Math.ceil(gap + frame.height)
  // Only the card takes the pointer; the rest of the strip lets it through.
  mask: Region { item: frame }

  // A fresh surface maps at a whole-number scale before it learns the
  // output's fractional one; it stays clear until the two match, as the
  // shell's overlays do.
  readonly property bool scaleReady: visible && !!targetMonitor && Math.round(devicePixelRatio * 120) === Math.round(targetMonitor.scale * 120)
  property bool revealed: false
  onScaleReadyChanged: if (scaleReady) Qt.callLater(function() { if (card.scaleReady && card.mapped) card.revealed = true })
  onRevealedChanged: if (revealed && !leaving) enter()

  function enter() {
    hideTimer.interval = 6000
    typed = Style.reduceMotion ? line.length : 0
    if (Style.reduceMotion) { drop = gap; fade = 1; live = true; hideTimer.restart(); return }
    drop = -frame.height
    fade = 0
    live = true
    dropIn.restart()
    hideTimer.restart()
  }

  // ------------------------------------------------------------ motion

  property real drop: 0
  property real fade: 0

  ParallelAnimation {
    id: dropIn
    NumberAnimation { target: card; property: "drop"; to: card.gap; duration: Style.duration(340); easing.type: Easing.OutCubic }
    NumberAnimation { target: card; property: "fade"; to: 1; duration: Style.duration(200); easing.type: Easing.OutCubic }
  }

  SequentialAnimation {
    id: liftOut
    ParallelAnimation {
      NumberAnimation { target: card; property: "drop"; to: -frame.height; duration: Style.duration(240); easing.type: Easing.InCubic }
      NumberAnimation { target: card; property: "fade"; to: 0; duration: Style.duration(240); easing.type: Easing.InCubic }
    }
    ScriptAction { script: card.finish() }
  }

  // The charge pulse's clock, ticking only while something charges.
  readonly property real clockBase: Date.now()
  property real clock: 0
  readonly property bool anyCharging: {
    if (!pods || pods.stale) return false
    for (var i = 0; i < parts.length; i++) if (pods[parts[i].key] && pods[parts[i].key].charging) return true
    return false
  }

  Timer {
    interval: 70
    repeat: true
    running: card.live && !Style.reduceMotion && card.anyCharging
    onTriggered: card.clock = Date.now() - card.clockBase
  }

  property real nowSec: Date.now() / 1000

  // The prompt, typed out behind a cursor as the panel's is.
  readonly property string line: Model.airpodsCardLine(pods, reason)
  property int typed: 0
  property bool cursorOn: true
  onLineChanged: typed = Style.reduceMotion || !live ? line.length : 0

  Timer {
    interval: 22
    repeat: true
    running: card.live && card.typed < card.line.length
    onTriggered: card.typed = Math.min(card.line.length, card.typed + 1)
  }

  Timer {
    interval: 530
    repeat: true
    running: card.live && !Style.reduceMotion
    onTriggered: card.cursorOn = !card.cursorOn
  }

  // ------------------------------------------------------------- tones

  property var palette: ({})

  FileView {
    id: paletteFile
    path: Commons.Color.currentThemePath + "/colors.toml"
    blockLoading: false
    printErrors: false
    onLoaded: card.palette = Model.parsePalette(text())
  }

  readonly property color foreground: Commons.Color.popups.text
  readonly property color background: Commons.Color.popups.background
  readonly property color dim: Qt.tint(foreground, Qt.rgba(background.r, background.g, background.b, 0.4))
  readonly property color urgent: bar && bar.urgent ? bar.urgent : Commons.Color.urgent
  readonly property color lowTone: Model.contrast(urgent, background) >= 3.5 ? urgent : foreground
  readonly property color tone: {
    var c = Qt.color(Model.roomToneHex(Model.kindTone("airpods"), palette, String(foreground)))
    return Model.contrast(c, background) >= 2.6 ? c : foreground
  }

  function partTone(pod) {
    return pod && !pod.stale && Model.isLow(pod, lowThreshold) ? lowTone : tone
  }

  readonly property real roomPad: Style.space(10)
  readonly property real roomGap: Style.space(3)
  readonly property real iconColumn: Math.round(Style.font.heading * 1.25)
  // A part's own icon, the room's lead: twice the room icons' size.
  readonly property real bigIcon: Math.round(Style.font.heading * 2.5)

  // --------------------------------------------------------- components

  // A room: the tone washed over the card, rising into place after `delay`
  // as the card comes down, its icon acting out what it is once it lands.
  component Room: Rectangle {
    id: room
    property color tone: card.tone
    property int delay: 0
    property int acts: 0
    property real rise: 0
    property real roomFade: 1
    property var cells: []
    readonly property bool hovered: roomArea.containsMouse
    default property alias content: inner.data

    implicitHeight: inner.implicitHeight + card.roomPad * 2
    radius: Style.cornerRadius
    color: Qt.rgba(tone.r, tone.g, tone.b, hovered ? 0.11 : 0.065)
    opacity: roomFade
    transform: Translate { y: room.rise }

    Behavior on color { ColorAnimation { duration: Style.duration(140) } }

    Connections {
      target: card
      function onLiveChanged() {
        if (!card.live) return
        riseIn.stop()
        if (Style.reduceMotion) { room.rise = 0; room.roomFade = 1; return }
        room.rise = Style.space(12)
        room.roomFade = 0
        riseIn.start()
      }
    }

    SequentialAnimation {
      id: riseIn
      PauseAnimation { duration: Style.duration(120 + room.delay) }
      ParallelAnimation {
        NumberAnimation { target: room; property: "rise"; to: 0; duration: Style.duration(460); easing.type: Easing.OutCubic }
        NumberAnimation { target: room; property: "roomFade"; to: 1; duration: Style.duration(280); easing.type: Easing.OutCubic }
      }
      ScriptAction { script: room.acts++ }
    }

    MouseArea {
      id: roomArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onEntered: room.acts++
      // The cells under the pointer give, as in the panel.
      onPositionChanged: function(mouse) {
        for (var i = 0; i < room.cells.length; i++) {
          var p = room.cells[i].mapFromItem(room, mouse.x, mouse.y)
          room.cells[i].hover(p.x, p.y)
        }
      }
      onExited: { for (var i = 0; i < room.cells.length; i++) room.cells[i].dent = null }
    }

    Column {
      id: inner
      x: card.roomPad
      y: card.roomPad
      width: parent.width - card.roomPad * 2
      spacing: Style.space(6)
    }
  }

  // Text that decodes into place as the card comes in; later changes swap.
  component Decode: Words {
    id: dec
    property string value: ""
    property int delay: 0
    property real progress: 1
    property int seed: 0
    readonly property string kept: Model.keepTogether(value)

    text: progress >= 1 ? kept : Model.scramble(kept, progress, seed)

    Connections {
      target: card
      function onLiveChanged() {
        if (!card.live) return
        decodeRun.stop()
        if (Style.reduceMotion) { dec.progress = 1; return }
        dec.seed = dec.seed + 1
        dec.progress = 0
        decodeRun.start()
      }
    }

    SequentialAnimation {
      id: decodeRun
      PauseAnimation { duration: Style.duration(dec.delay) }
      NumberAnimation { target: dec; property: "progress"; to: 1; duration: Style.duration(Math.min(560, 180 + dec.value.length * 14)) }
    }
  }

  // ------------------------------------------------------------- card

  BorderSurface {
    id: frame
    y: card.drop
    width: Math.round(Style.space(500))
    height: Math.ceil(borderTop + borderBottom + framePad * 2 + rooms.implicitHeight)
    opacity: card.revealed ? card.fade : 0
    color: card.background
    borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
    radius: Style.cornerRadius

    readonly property real framePad: Style.space(8)

    // Left opens the panel, right sends the card away. The rooms inside take
    // no buttons, only hover, so a click anywhere lands here, and the card
    // counts as pointed at while the pointer is on any room.
    MouseArea {
      id: cardArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      // Pointed at and left: it goes a little after.
      onExited: if (card.live && !card.leaving) {
        hideTimer.interval = 2500
        hideTimer.restart()
      }
      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) card.openPanel()
        card.dismiss()
      }

      Column {
        id: rooms
        x: frame.borderLeft + frame.framePad
        y: frame.borderTop + frame.framePad
        width: frame.width - frame.borderLeft - frame.borderRight - frame.framePad * 2
        spacing: card.roomGap

        // The AirPods themselves: a slim strip with the icon, the name and,
        // on the same line, the prompt. A name too long for both puts the
        // prompt under it.
        Room {
          id: head
          width: parent.width
          delay: 0

          Item {
            id: headLine
            width: parent.width
            implicitHeight: Math.max(headIcon.height, labels.height)

            readonly property real gapW: Style.space(10)
            readonly property real promptNatural: promptSign.implicitWidth + promptSign.advance + promptLine.implicitWidth
            readonly property bool oneLine: nameText.implicitWidth + gapW + promptNatural <= labels.width

            PixelIcon {
              id: headIcon
              x: Math.round((card.iconColumn - width) / 2)
              anchors.verticalCenter: parent.verticalCenter
              name: card.pods && card.pods.isHeadset ? "headphone" : "airpods"
              size: card.iconColumn
              color: card.tone
              play: head.acts
            }

            Item {
              id: labels
              anchors.left: parent.left
              anchors.leftMargin: card.iconColumn + Style.space(10)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: headLine.oneLine ? nameText.height : prompt.y + prompt.height

              Words {
                id: nameText
                width: Math.min(implicitWidth, parent.width)
                text: card.pods ? card.pods.name : ""
                color: card.foreground
                fontFamily: card.fontFamily
                step: "body"
              }

              // The prompt sign, then the line, laid out whole and revealed
              // as it types, so a word never jumps to the next line. On the
              // name's baseline when it fits beside it.
              Item {
                id: prompt
                x: headLine.oneLine ? Math.round(nameText.implicitWidth + headLine.gapW) : 0
                y: headLine.oneLine ? Math.round(nameText.baselineOffset - promptLine.baselineOffset) : nameText.height + Style.space(1)
                width: parent.width - x
                height: promptLine.implicitHeight

                Words {
                  id: promptSign
                  text: "\u203A"
                  color: card.dim
                  fontFamily: card.fontFamily
                  step: "small"
                }

                Words {
                  id: promptLine
                  anchors.left: promptSign.right
                  anchors.leftMargin: promptSign.advance
                  anchors.right: parent.right
                  textFormat: Text.StyledText
                  text: Model.revealLine(Model.keepTogether(card.line), card.typed, card.cursorOn)
                  color: card.dim
                  fontFamily: card.fontFamily
                  step: "small"
                }
              }
            }
          }
        }

        // A room a part, side by side, all as tall as the tallest.
        Row {
          id: partRow
          width: parent.width
          spacing: card.roomGap

          readonly property real roomWidth: (width - spacing * (card.parts.length - 1)) / Math.max(1, card.parts.length)
          property real tallest: 0

          function measure() {
            var h = 0
            for (var i = 0; i < partRooms.count; i++) {
              var r = partRooms.itemAt(i)
              if (r) h = Math.max(h, r.implicitHeight)
            }
            tallest = h
          }

          Repeater {
            id: partRooms
            model: card.parts.length

            Room {
              id: partRoom
              required property int index
              readonly property var part: card.parts[index] || ({ key: "left", label: "", icon: "airpod-left" })
              readonly property var pod: card.pods ? card.pods[part.key] : null
              readonly property bool seen: !!pod && Model.hasLevel(pod.level)
              readonly property bool stale: !seen || pod.stale === true

              width: Math.floor(partRow.roomWidth * 100) / 100
              height: Math.max(implicitHeight, partRow.tallest)
              onImplicitHeightChanged: Qt.callLater(partRow.measure)
              tone: card.partTone(pod)
              delay: 70 * (index + 1)
              cells: [pad]

              // The part as a big icon, its level beside it. A bud in a
              // closed case reads as it was, dimmed.
              Item {
                width: parent.width
                implicitHeight: Math.max(partIcon.height, figure.implicitHeight)
                opacity: !partRoom.seen ? 0.45 : partRoom.stale ? 0.6 : 1

                PixelIcon {
                  id: partIcon
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  name: partRoom.part.icon
                  size: card.bigIcon
                  color: partRoom.tone
                  play: partRoom.acts
                }

                BigFigure {
                  id: figure
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  value: partRoom.seen ? pad.shown : null
                  target: partRoom.seen ? partRoom.pod.level : null
                  tone: partRoom.tone
                  foreground: card.foreground
                  mark: partRoom.seen ? Model.markIcon(partRoom.pod, card.lowThreshold) : ""
                  live: card.live
                  play: partRoom.acts
                  delay: 120
                  fontFamily: card.shellFamily
                  fontSize: Style.font.bodySmall
                }
              }

              Battery {
                id: pad
                width: parent.width
                opacity: !partRoom.seen ? 0.45 : partRoom.stale ? 0.6 : 1
                small: true
                segments: partRoom.part.key === "headset" ? 10 : 5
                level: partRoom.seen ? partRoom.pod.level : 0
                known: partRoom.seen
                charging: partRoom.seen && !partRoom.pod.stale && partRoom.pod.charging === true
                tone: partRoom.tone
                foreground: card.foreground
                clock: card.clock
                live: card.live
                delay: 120 + partRoom.delay
              }

              // Which part, and what it is doing or where it went.
              Item {
                width: parent.width
                implicitHeight: Math.max(partName.implicitHeight, partState.implicitHeight)

                Words {
                  id: partName
                  text: partRoom.part.label
                  color: card.foreground
                  fontFamily: card.fontFamily
                  step: "small"
                }

                Decode {
                  id: partState
                  anchors.right: parent.right
                  width: Math.min(implicitWidth, parent.width - partName.implicitWidth - Style.space(8))
                  horizontalAlignment: Text.AlignRight
                  value: Model.podPartState(partRoom.part.key, partRoom.pod, card.nowSec)
                  delay: 200 + partRoom.delay
                  color: card.dim
                  fontFamily: card.fontFamily
                  step: "small"
                }
              }
            }
          }
        }
      }
    }
  }
}
