import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A half-width on/off tile, as in ROG Deck's bar picker: icon, label and a
// switch, the whole tile one click target. Filled while on. Two of these sit
// side by side.
CursorSurface {
  id: tile

  property string icon: ""
  property string label: ""
  property string hint: ""
  property bool checked: false
  property string fontFamily: Style.font.family

  signal toggled()

  hasCursor: mouse.containsMouse
  current: checked
  bordered: true
  implicitHeight: Math.max(labelText.implicitHeight, toggle.implicitHeight) + Style.space(16)

  Item {
    id: iconBox
    anchors.left: parent.left
    anchors.leftMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(20)
    height: Style.font.body

    Icon {
      anchors.centerIn: parent
      name: tile.icon || "battery"
      size: Style.font.body
      color: tile.foreground
      opacity: tile.checked ? 1 : 0.6
    }
  }

  Text {
    id: labelText
    anchors.left: iconBox.right
    anchors.leftMargin: Style.space(8)
    anchors.right: toggle.left
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: tile.label
    color: tile.foreground
    opacity: tile.checked ? 1 : 0.8
    elide: Text.ElideRight
    font.family: tile.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  ToggleSwitch {
    id: toggle
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    trackHeight: Math.max(16, Math.round(Style.spacing.controlHeight * 0.45))
    checked: tile.checked
    interactive: false
    foreground: tile.foreground
    accent: tile.accent
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.toggled()
  }

  PanelToolTip {
    visible: mouse.containsMouse && tile.hint !== ""
    text: tile.hint
    fontFamily: tile.fontFamily
  }
}
