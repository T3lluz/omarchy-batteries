import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Section title in Omarchy's panel style (bold small caps, dimmed) with an
// icon in front and a reading on the right. The same header as ROG Deck's
// and Sonus's, with a drawn Tabler icon in place of a Nerd Font glyph.
Item {
  id: header

  property string icon: ""
  property string title: ""
  property string detail: ""
  property color detailColor: Qt.darker(foreground, 1.15)
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(titleText.implicitHeight, detailText.implicitHeight, Style.font.body)

  Item {
    id: iconBox
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    visible: header.icon !== ""
    width: visible ? Style.space(20) : 0
    height: Style.font.body

    Icon {
      anchors.centerIn: parent
      name: header.icon || "battery"
      size: Style.font.body
      color: Qt.darker(header.foreground, 1.4)
    }
  }

  PanelSectionHeader {
    id: titleText
    anchors.left: iconBox.right
    anchors.leftMargin: iconBox.visible ? Style.space(4) : 0
    anchors.right: detailText.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    text: header.title
    elide: Text.ElideRight
    foreground: header.foreground
    fontFamily: header.fontFamily
  }

  Text {
    id: detailText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, header.width * 0.6)
    visible: header.detail !== ""
    textFormat: Text.PlainText
    text: header.detail
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
    color: header.detailColor
    font.family: header.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
