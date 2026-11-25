import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// One battery in the hover card: tinted in its room's colour, as in the
// panel, with its pixel icon, name, the mark in a column of its own, a small
// battery of cells and the level in the pixel type. Its own file so the
// offscreen harness can draw it: a popup's content cannot be grabbed.
Rectangle {
  id: row
  // An entry of Model.hoverRows, and where it is in the card.
  property var entry: ({})
  property int order: 0
  property color foreground: "white"
  property string fontFamily: Style.font.family
  // The theme's colour for a tone name (the card's toneOf).
  property var toneOf: function(name) { return foreground }
  property int lowThreshold: 20
  property int unit: 2
  // Goes up each time the card shows, so the icons act; a row after the other.
  property int shows: 0
  // As wide as it needs to be for its name and note on one line: the
  // name and every fixed column beside it.
  readonly property real need: icon.x + icon.width + Style.space(6) + name.implicitWidth + Style.space(6)
    + markSlot.width + Style.space(5) + cells.width + Style.space(8) + level.width + Style.space(6)
  readonly property color tone: !entry.stale && Model.isLow(entry, row.lowThreshold) ? Commons.Color.urgent : row.toneOf(entry.tone)
  readonly property string mark: Model.markIcon(entry, row.lowThreshold)

  height: Math.max(name.implicitHeight, Style.space(14)) + Style.space(6) * 2
  radius: Style.cornerRadius
  color: Qt.rgba(tone.r, tone.g, tone.b, 0.08)
  opacity: entry.stale ? 0.6 : 1

  PixelIcon {
    id: icon
    x: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    name: row.entry.icon
    size: Style.font.body
    play: row.shows
    delay: row.order * 70
    color: row.tone
  }

  Words {
    id: name
    anchors.left: icon.right
    anchors.leftMargin: Style.space(6)
    anchors.right: markSlot.left
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    text: Model.keepTogether(row.entry.name + (row.entry.note ? "  " + row.entry.note : ""))
    color: row.foreground
    fontFamily: row.fontFamily
    step: "body"
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
      play: row.shows
      delay: row.order * 70
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
    level: Model.hasLevel(row.entry.level) ? row.entry.level : 0
    known: Model.hasLevel(row.entry.level)
    tone: row.tone
    foreground: row.foreground
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
      text: Model.percent(row.entry.level)
      unit: row.unit
      color: Model.hasLevel(row.entry.level) ? row.foreground : Qt.tint(row.foreground, Qt.rgba(Commons.Color.tooltip.background.r, Commons.Color.tooltip.background.g, Commons.Color.tooltip.background.b, 0.4))
    }
  }
}
