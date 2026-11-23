import QtQuick
import qs.Commons
import "Model.js" as Model

// A room's level in the block face (Model.bigDigits), with a small % and
// the mark beside it, a pixel icon (Model.markIcon): a bolt while charging,
// a plug on a charger, the low battery when low. The mark acts when it
// changes; the bolt strikes and the low cell blinks over and over while the
// panel shows them (Motion.LOOPS). The blocks are laid out on the font's character grid but
// drawn as rectangles, since typed block characters leave hairline seams
// between rows and columns. `value` follows the room's battery while it
// fills in, so the number counts up with it.
Item {
  id: figure

  property var value: null
  property color tone: "white"
  property color foreground: "white"
  property string mark: ""
  readonly property real markSize: Math.round(fontSize * 1.1)
  // The panel is open on it: a looping mark loops.
  property bool live: false
  // Goes up when the room acts, so the mark acts along.
  property int play: 0
  property int delay: 0
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.bodySmall

  readonly property bool known: Model.hasLevel(value)
  readonly property var rows: Model.bigDigits(known ? String(Math.round(value)) : "--")
  readonly property int cols: rows[0].length
  readonly property real cellW: grid.implicitWidth / 10
  readonly property real cellH: Math.round(metrics.height * 0.9)
  readonly property real digitsWidth: Math.round(cols * cellW)
  // Every block of every row, as [col, row, "full" | "top" | "bottom"].
  readonly property var blocks: {
    var out = []
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        var ch = rows[r].charAt(c)
        if (ch === "█") out.push([c, r, "full"])
        else if (ch === "▀") out.push([c, r, "top"])
        else if (ch === "▄") out.push([c, r, "bottom"])
      }
    }
    return out
  }

  implicitWidth: digitsWidth + Style.space(3) + side.implicitWidth
  // The face sits two and a half rows tall: nothing hangs below the bottom bar.
  implicitHeight: Math.round(cellH * 2.5)

  FontMetrics {
    id: metrics
    font.family: figure.fontFamily
    font.pixelSize: figure.fontSize
  }

  // The width of the font's own characters, measured as drawn.
  Text {
    id: grid
    visible: false
    text: "0000000000"
    font.family: figure.fontFamily
    font.pixelSize: figure.fontSize
  }

  Repeater {
    model: figure.blocks

    Rectangle {
      required property var modelData
      readonly property real from: modelData[1] * figure.cellH + (modelData[2] === "bottom" ? figure.cellH / 2 : 0)
      x: Math.round(modelData[0] * figure.cellW)
      y: Math.round(from)
      width: Math.round((modelData[0] + 1) * figure.cellW) - x
      height: Math.round(from + (modelData[2] === "full" ? figure.cellH : figure.cellH / 2)) - y
      color: figure.known ? figure.tone : Qt.darker(figure.foreground, 1.5)
    }
  }

  Column {
    id: side
    x: figure.digitsWidth + Style.space(3)
    height: figure.implicitHeight

    Item {
      width: Math.max(pct.implicitWidth, figure.markSize)
      height: figure.implicitHeight - pct.implicitHeight
      visible: figure.mark !== ""

      PixelIcon {
        anchors.centerIn: parent
        name: figure.mark
        size: figure.markSize
        color: figure.tone
        play: figure.play
        delay: figure.delay
        playOnChange: true
        loop: figure.live
      }
    }

    Item { width: 1; height: figure.mark !== "" ? 0 : figure.implicitHeight - pct.implicitHeight }

    PixelText {
      id: pct
      visible: figure.known
      text: "%"
      size: Style.font.caption * 0.75
      color: Qt.darker(figure.foreground, 1.5)
    }
  }
}
