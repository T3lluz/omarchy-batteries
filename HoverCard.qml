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
    implicitWidth: Style.space(280)
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
        model: card.rows

        // One battery: tinted in its room's colour, as in the panel.
        Rectangle {
          id: row
          required property var modelData
          readonly property color tone: !modelData.stale && Model.isLow(modelData, card.lowThreshold) ? Commons.Color.urgent : card.toneOf(modelData.tone)
          readonly property string mark: Model.markIcon(modelData, card.lowThreshold)

          width: list.width
          height: Math.max(name.implicitHeight, Style.space(14)) + Style.space(6) * 2
          radius: Style.cornerRadius
          color: Qt.rgba(tone.r, tone.g, tone.b, 0.08)
          opacity: modelData.stale ? 0.6 : 1

          PixelIcon {
            id: icon
            x: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            name: row.modelData.icon
            size: Style.font.body
            color: row.tone
          }

          Text {
            id: name
            anchors.left: icon.right
            anchors.leftMargin: Style.space(6)
            anchors.right: markSlot.left
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: row.modelData.name + (row.modelData.note ? "  " + row.modelData.note : "")
            color: card.foreground
            font.family: card.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          // The mark (charging, on a charger, low) in a column of its own that
          // is there on every row, empty or not, so the batteries and figures
          // stay in one place.
          Item {
            id: markSlot
            anchors.right: cells.left
            anchors.rightMargin: Style.space(5)
            anchors.verticalCenter: parent.verticalCenter
            width: markIcon.implicitWidth
            height: markIcon.implicitHeight

            PixelIcon {
              id: markIcon
              visible: row.mark !== ""
              name: row.mark || "zap"
              size: Style.font.body
              color: row.tone
            }
          }

          Battery {
            id: cells
            anchors.right: level.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(54)
            implicitHeight: Style.space(9)
            small: true
            segments: 5
            level: Model.hasLevel(row.modelData.level) ? row.modelData.level : 0
            known: Model.hasLevel(row.modelData.level)
            tone: row.tone
            foreground: card.foreground
          }

          // The level, right-aligned in a column as wide as "100%", so the
          // figures line up.
          Item {
            id: level
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Model.pixelText("100%").width * figure.cell
            height: figure.implicitHeight

            PixelText {
              id: figure
              anchors.right: parent.right
              text: Model.percent(row.modelData.level)
              unit: card.unit
              color: Model.hasLevel(row.modelData.level) ? card.foreground : Qt.darker(card.foreground, 1.5)
            }
          }
        }
      }
    }
  }
}
