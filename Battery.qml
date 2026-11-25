import QtQuick
import qs.Commons
import "Model.js" as Model

// A level drawn as a battery: an outlined body, split into cells
// (Model.batteryCells), each filled to the full height of the body. It
// fills in from empty when the panel opens, a pulse of charge runs up to the
// front while it charges and the cell charging now breathes. The pointer
// presses the cells under it down a little, and `press` sends a ripple out
// from a point, as Weave's pad does.
Item {
  id: battery

  property real level: 0
  property bool known: true
  property bool charging: false
  // A charge limit, drawn as a tick across the body.
  property real marker: 0
  property int segments: 10
  property color tone: "white"
  property color foreground: "white"
  // The panel's clock, in ms, and whether things may move at all.
  property real clock: 0
  property bool live: false
  // How long after the panel opens this one starts filling, so the panel
  // fills from the top down.
  property int delay: 0
  // Small batteries (the AirPods' cells, the panel's mark) draw a thinner body.
  property bool small: false
  // The terminal nub. A battery stretched across a room reads better
  // without one; the panel's small mark keeps it.
  property bool nub: false

  // What is drawn: the level while it fills in, else the level.
  property real shown: 0
  property var dent: null
  property var ripples: []

  readonly property real line: Math.max(1, Style.space(1))
  readonly property real inset: small ? Math.max(1, Style.space(1)) : Math.max(2, Style.space(2))
  readonly property real gap: small ? Math.max(1, Style.space(1)) : Math.max(2, Style.space(2))
  readonly property real nubWidth: nub ? Math.max(2, Style.space(small ? 2 : 3)) : 0

  implicitHeight: small ? Style.space(11) : Style.space(18)

  readonly property var cells: Model.batteryCells({
    segments: segments,
    level: known ? shown : 0,
    t: clock,
    charging: charging && live && !Style.reduceMotion,
    dent: dent,
    ripples: ripples.map(function(r) { return { x: r.x, age: battery.clock - r.at } })
  })

  // Old ripples go once they have run out.
  onClockChanged: if (ripples.length) {
    var left = ripples.filter(function(r) { return battery.clock - r.at < Model.BATTERY.RIPPLE_MS })
    if (left.length !== ripples.length) ripples = left
  }

  function enter() {
    fillIn.stop()
    settle.stop()
    if (Style.reduceMotion || !known) { shown = known ? level : 0; return }
    shown = 0
    fillTo.to = level
    fillIn.start()
  }

  // A point in the battery's own coordinates. Only near the body presses.
  function hover(x, y) {
    if (x < 0 || x > body.width || y < -height * 0.6 || y > height * 1.6) { dent = null; return }
    dent = x / body.width
  }

  function press(x, y) {
    if (Style.reduceMotion) return
    var next = ripples.slice(-3)
    next.push({ x: Math.max(0, Math.min(1, x / body.width)), at: clock })
    ripples = next
  }

  onLiveChanged: if (live) enter()
  Component.onCompleted: { if (live) enter(); else shown = known ? level : 0 }

  // Slides to the level as it is now. The animation's end is set before it
  // starts: bound to `level`, it would start toward the old level, since this
  // runs before the binding catches up.
  function slide() {
    settle.stop()
    settle.to = level
    settle.start()
  }

  onLevelChanged: {
    if (fillIn.running) return
    if (Style.reduceMotion || !live) { shown = level; return }
    slide()
  }

  SequentialAnimation {
    id: fillIn
    PauseAnimation { duration: Style.duration(battery.delay) }
    NumberAnimation { id: fillTo; target: battery; property: "shown"; duration: Style.duration(680); easing.type: Easing.OutCubic }
    // The level may have moved on while it filled in.
    ScriptAction { script: if (battery.shown !== battery.level) battery.slide() }
  }

  NumberAnimation {
    id: settle
    target: battery
    property: "shown"
    duration: Style.duration(420)
    easing.type: Easing.OutCubic
  }

  Rectangle {
    id: body
    width: parent.width - (battery.nub ? battery.nubWidth + battery.line : 0)
    height: parent.height
    color: "transparent"
    radius: Style.cornerRadius > 0 ? Math.min(Style.cornerRadius, 3) : 0
    border.width: battery.line
    border.color: Qt.rgba(battery.tone.r, battery.tone.g, battery.tone.b, battery.known ? 0.6 : 0.3)

    Row {
      id: cellRow
      x: battery.line + battery.inset
      y: battery.line + battery.inset
      width: body.width - x * 2
      height: body.height - y * 2
      spacing: battery.gap

      readonly property real cellWidth: (width - spacing * (battery.segments - 1)) / battery.segments

      Repeater {
        model: battery.segments

        Item {
          id: cell
          required property int index
          readonly property var c: battery.cells[index] || ({ fill: 0, glow: 0, press: 0, next: 0 })

          width: cellRow.cellWidth
          height: cellRow.height
          // A cell gives under the pointer, as Weave's tiles do.
          scale: 1 - cell.c.press * 0.14

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(battery.tone.r, battery.tone.g, battery.tone.b, 0.12)
          }

          Rectangle {
            width: parent.width * cell.c.fill
            height: parent.height
            color: battery.tone
          }

          // The cell charging now: its empty part breathes.
          Rectangle {
            visible: cell.c.next > 0
            x: parent.width * cell.c.fill
            width: parent.width - x
            height: parent.height
            color: Qt.rgba(battery.tone.r, battery.tone.g, battery.tone.b, 0.12 + 0.4 * cell.c.next)
          }

          Rectangle {
            visible: cell.c.glow > 0.01
            anchors.fill: parent
            color: Qt.rgba(battery.foreground.r, battery.foreground.g, battery.foreground.b, cell.c.glow * 0.55)
          }
        }
      }
    }
  }

  Rectangle {
    visible: battery.nub
    x: body.width + battery.line
    width: battery.nubWidth
    height: Math.round(parent.height * 0.44)
    anchors.verticalCenter: parent.verticalCenter
    color: Qt.rgba(battery.tone.r, battery.tone.g, battery.tone.b, battery.known ? 0.6 : 0.3)
  }

  // A charge limit: a tick through the body, poking out above and below.
  Rectangle {
    visible: battery.marker > 0 && battery.marker < 100
    x: Math.round(cellRow.x + cellRow.width * battery.marker / 100)
    y: -Math.max(2, Style.space(3))
    width: battery.line
    height: parent.height - y * 2
    color: battery.foreground
    opacity: 0.55
  }
}
