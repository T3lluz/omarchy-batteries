import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A small reading card, as in ROG Deck: icon and caption, a big value, and
// a note or a level bar underneath.
BorderSurface {
  id: tile

  property string icon: ""
  property string caption: ""
  property string value: "—"
  property string note: ""
  // A level bar in place of the note, when set.
  property var level: null
  property bool showLevel: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color iconColor: foreground
  property color valueColor: foreground
  property color levelColor: foreground
  property string fontFamily: Style.font.family

  radius: Style.cornerRadius
  color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.04)
  borderSpec: Border.controlSpec("normal", foreground, accent)
  implicitHeight: content.implicitHeight + Style.space(18)

  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    spacing: Style.space(2)

    Row {
      spacing: Style.space(6)

      Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: tile.icon !== ""
        name: tile.icon || "battery"
        size: Style.font.caption
        color: tile.iconColor
        opacity: tile.iconColor === tile.foreground ? 0.6 : 1
      }

      Text {
        textFormat: Text.PlainText
        text: tile.caption
        color: tile.foreground
        opacity: 0.6
        font.family: tile.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: tile.value
      color: tile.valueColor
      elide: Text.ElideRight
      font.family: tile.fontFamily
      font.pixelSize: Style.font.heading
      font.bold: true
      Behavior on color { ColorAnimation { duration: 300 } }
    }

    // Always takes its line, so tiles in a row keep one height.
    Item {
      width: parent.width
      height: noteText.implicitHeight

      Text {
        id: noteText
        visible: !tile.showLevel
        width: parent.width
        textFormat: Text.PlainText
        text: tile.note || " "
        color: tile.foreground
        opacity: 0.55
        elide: Text.ElideRight
        font.family: tile.fontFamily
        font.pixelSize: Style.font.caption
      }

      LevelBar {
        visible: tile.showLevel
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        level: tile.level || 0
        fill: tile.levelColor
        track: Qt.rgba(tile.foreground.r, tile.foreground.g, tile.foreground.b, 0.12)
      }
    }
  }
}
