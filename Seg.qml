import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Equal-width row of options, pick one; ROG Deck's. `options` is
// [{ value, label, hint? }]; `picked(value)` fires only for a different one.
Row {
  id: seg

  property var options: []
  property var value
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  signal picked(var value)

  width: parent ? parent.width : implicitWidth
  spacing: Style.space(6)

  readonly property real cellWidth: options.length > 0
    ? (width - spacing * (options.length - 1)) / options.length : 0

  Repeater {
    model: seg.options

    Button {
      required property var modelData
      width: seg.cellWidth
      text: modelData.label
      tooltipText: modelData.hint || ""
      fontSize: Style.font.bodySmall
      foreground: seg.foreground
      fontFamily: seg.fontFamily
      bordered: true
      active: seg.value === modelData.value
      onClicked: if (seg.value !== modelData.value) seg.picked(modelData.value)
    }
  }
}
