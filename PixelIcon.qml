import QtQuick
import QtQuick.Window
import qs.Commons
import "Pixels.js" as Pixels
import "Motion.js" as Motion

// A pixel icon from Pixels.js, drawn as rectangles on whole device pixels so
// it stays sharp at any scale. The icon comes out as close to `size` as the
// grid allows: the 24-unit grid where a unit gets whole device pixels, the
// same grid halved (12 cells) where it would not. On a 1.25 scale a 14 px
// request draws 12 device pixels; a 20 px one draws 24.
// Never scaled: a fractional scale only ever picks the nearest sharp size.
//
// It acts out what it is (Motion.js): the parts that move are drawn apart
// from the rest and step in whole cells, so the art never smears. `play`
// going up plays the act once, after `delay` ms; `loop` repeats it on the
// shared clock while it is true.
Item {
  id: icon

  property string name: ""
  property real size: 16
  property color color: "white"
  // Device pixels per cell of the halved grid, to match other pixel art
  // (PixelText) stroke for stroke; 0 picks it from `size`.
  property int unit: 0
  // What it acts out, its own name unless told otherwise.
  property string act: name
  property int play: 0
  property int delay: 0
  property bool loop: false
  // Acts when it turns into another icon (a mark that changes).
  property bool playOnChange: false

  readonly property var art: Pixels.icons[name] || null
  // The window's ratio, not Screen's: at a 1.25 scale Screen says 2.
  readonly property real dpr: Window.window && Window.window.devicePixelRatio > 0 ? Window.window.devicePixelRatio : 1
  // Device pixels across, in twelfths: odd counts take the halved grid. Its
  // strokes are this many device pixels thick either way.
  readonly property int twelfths: unit > 0 ? unit : Math.max(1, Math.round(size * dpr / 12))
  readonly property bool fine: twelfths % 2 === 0
  readonly property real cell: (fine ? twelfths / 2 : twelfths) / dpr
  readonly property var rects: art ? (fine ? art.g24 : art.g12) : []
  readonly property var parts: art && art.parts ? art.parts : []
  // A cell of the 12 grid, which the acts move in, in logical pixels.
  readonly property real step: twelfths / dpr

  readonly property bool canAct: !Style.reduceMotion && Motion.has(act) && Motion.iconOf(act) === name
  property real actMs: -1
  property real loopMs: -1
  // Only while someone can see it: a closed panel stops its loops.
  readonly property bool looping: loop && canAct && visible && !!Window.window && Window.window.visible
  readonly property int frame: Motion.frameAt(act, actMs >= 0 ? actMs : looping ? Motion.loopTime(act, loopMs) : -1)
  readonly property var pose: Motion.pose(act, frame)

  implicitWidth: twelfths * 12 / dpr
  implicitHeight: implicitWidth

  function start() {
    if (!canAct || run.running) return
    run.start()
  }

  onPlayChanged: start()
  onNameChanged: if (playOnChange) start()

  SequentialAnimation {
    id: run
    PauseAnimation { duration: Math.max(0, icon.delay) }
    NumberAnimation {
      target: icon
      property: "actMs"
      from: 0
      to: Motion.length(icon.act)
      duration: Motion.length(icon.act)
    }
    ScriptAction { script: icon.actMs = -1 }
  }

  // The shared clock is the wall clock, so every loop is in step. One timer
  // sleeps until the frame next changes (Motion.loopWait), so a loop costs a
  // wake-up a frame, not one every time the window draws.
  function tick() {
    if (!looping) { loopTimer.stop(); loopMs = -1; return }
    var now = Date.now()
    loopMs = now
    loopTimer.interval = Math.max(1, Motion.loopWait(act, now))
    loopTimer.restart()
  }

  onLoopingChanged: tick()
  Component.onCompleted: { tick(); snap() }

  Timer {
    id: loopTimer
    repeat: false
    onTriggered: icon.tick()
  }

  // How far the cells move to start on a whole device pixel, checked before
  // each frame the window draws (it draws only when something changed). A
  // layout that lands the icon between two pixels would otherwise smear
  // every edge, worst at 1.25. ROG Deck's.
  property real snapX: 0
  property real snapY: 0

  function snap() {
    if (!visible) return
    var p = icon.mapToItem(null, 0, 0)
    var dx = Math.round(p.x * dpr) / dpr - p.x
    var dy = Math.round(p.y * dpr) / dpr - p.y
    if (Math.abs(dx - snapX) > 0.001) snapX = dx
    if (Math.abs(dy - snapY) > 0.001) snapY = dy
  }

  Connections {
    target: icon.Window.window
    ignoreUnknownSignals: true
    function onAfterAnimating() { icon.snap() }
  }

  Item {
    id: body
    x: icon.snapX
    y: icon.snapY
    width: icon.implicitWidth
    height: icon.implicitHeight
    rotation: (icon.pose.turn || 0) * 90

    Repeater {
      model: icon.rects

      Rectangle {
        required property var modelData
        x: modelData[0] * icon.cell
        y: modelData[1] * icon.cell
        width: modelData[2] * icon.cell
        height: modelData[3] * icon.cell
        color: icon.color
        antialiasing: false
      }
    }

    Repeater {
      model: icon.parts

      Item {
        id: part
        required property var modelData
        readonly property var at: Motion.partAt(icon.pose, modelData.id, modelData.extra === true)
        visible: at.on
        x: at.x * icon.step
        y: at.y * icon.step

        Repeater {
          model: icon.fine ? part.modelData.g24 : part.modelData.g12

          Rectangle {
            required property var modelData
            x: modelData[0] * icon.cell
            y: modelData[1] * icon.cell
            width: modelData[2] * icon.cell
            height: modelData[3] * icon.cell
            color: icon.color
            antialiasing: false
          }
        }
      }
    }
  }
}
