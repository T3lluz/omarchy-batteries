import QtQuick
import qs.Commons
import qs.Commons as Commons

// The icon in every part of the panel kit: a Nerd Font glyph, `icon` being
// the character, the same set Omarchy's own panels type. Model.GLYPHS names
// the ones this plugin uses. The bar draws Tabler icons instead (Icon.qml).
Item {
  id: glyph

  property string icon: ""
  property real size: Style.font.body
  property color color: Commons.Color.foreground
  property string fontFamily: Style.font.family

  implicitWidth: size
  implicitHeight: size

  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: glyph.icon
    color: glyph.color
    font.family: glyph.fontFamily
    font.pixelSize: glyph.size
  }
}
