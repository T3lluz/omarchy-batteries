import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// What opens when the pointer rests on the bar item, in place of the shell's
// plain tooltip: the panel's look in a line per battery (Model.hoverRows), a
// tinted row with its pixel icon, name, a small battery of cells and the
// level in the pixel type. Placed and framed the way the shell places and
// frames its own tooltip, so it opens where one would.
PopupWindow {
  id: card

  property Item target: null
  property var bar: null
  property bool shown: false
  property var rows: []
  // The panel's room colours (Model.roomToneHex) and the bar's figures' unit.
  property var palette: ({})
  property int lowThreshold: 20
  property int unit: 2
  property string fontFamily: Style.font.family

  readonly property color foreground: Commons.Color.tooltip.text
  readonly property real gap: 6
  readonly property var barWindow: target ? target.QsWindow.window : null

  visible: shown && !!target && rows.length > 0
  color: "transparent"
  implicitWidth: Math.ceil(frame.implicitWidth)
  implicitHeight: Math.ceil(frame.implicitHeight)

  // A fresh surface maps at a whole-number scale before it learns the
  // output's fractional one; stay clear until it matches the bar, as the
  // shell's tooltip does.
  readonly property bool scaleReady: visible && !!barWindow && Math.round(devicePixelRatio * 120) === Math.round(barWindow.devicePixelRatio * 120)
  property bool revealed: false
  // Each time the card shows, its icons act once, a row after the other.
  property int shows: 0
  onRevealedChanged: if (revealed) shows++
  onVisibleChanged: if (!visible) revealed = false
  onScaleReadyChanged: if (scaleReady) Qt.callLater(function() { if (card.scaleReady) card.revealed = true })

  function toneOf(name) {
    return Qt.color(Model.roomToneHex(name, palette, String(foreground)))
  }

  anchor {
    id: cardAnchor
    window: card.barWindow
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (!card.target || !card.barWindow) return
      var t = card.target
      var x = t.width / 2 - card.implicitWidth / 2
      var y = t.height + card.gap
      var edge = card.bar ? card.bar.position : "top"
      if (edge === "bottom") y = -card.implicitHeight - card.gap
      else if (edge === "left") { x = t.width + card.gap; y = t.height / 2 - card.implicitHeight / 2 }
      else if (edge === "right") { x = -card.implicitWidth - card.gap; y = t.height / 2 - card.implicitHeight / 2 }
      var point = card.barWindow.contentItem.mapFromItem(t, x, y)
      cardAnchor.rect.x = Math.round(point.x)
      cardAnchor.rect.y = Math.round(point.y)
    }
  }

  BorderSurface {
    id: frame
    opacity: card.revealed ? 1 : 0
    // Wide enough for every row on one line, within reason: a name longer
    // than that wraps.
    implicitWidth: Math.min(Style.space(380), Math.max(Style.space(280), Math.ceil(widest) + Style.space(8) * 2))
    readonly property real widest: {
      var w = 0
      for (var i = 0; i < rowRepeater.count; i++) {
        var r = rowRepeater.itemAt(i)
        if (r) w = Math.max(w, r.need)
      }
      return w
    }
    implicitHeight: list.implicitHeight + Style.space(8) * 2
    color: Commons.Color.tooltip.background
    borderSpec: Border.surfaceSpec("tooltip", "border", Commons.Color.tooltip.border, 1)
    radius: Style.cornerRadius

    Column {
      id: list
      x: Style.space(8)
      y: Style.space(8)
      width: parent.width - x * 2
      spacing: Style.space(3)

      Repeater {
        id: rowRepeater
        model: card.rows

        HoverRow {
          required property var modelData
          required property int index
          entry: modelData
          order: index
          width: list.width
          foreground: card.foreground
          fontFamily: card.fontFamily
          toneOf: card.toneOf
          lowThreshold: card.lowThreshold
          unit: card.unit
          shows: card.shows
        }
      }

      // What the other buttons do; a click opens the panel.
      Words {
        x: Style.space(6)
        width: parent.width - x * 2
        topPadding: Style.space(2)
        text: Model.HOVER_HINT
        color: Qt.tint(card.foreground, Qt.rgba(Commons.Color.tooltip.background.r, Commons.Color.tooltip.background.g, Commons.Color.tooltip.background.b, 0.4))
        fontFamily: card.fontFamily
        step: "small"
      }
    }
  }
}
