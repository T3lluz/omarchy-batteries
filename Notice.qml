import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A banner above the sections, as in ROG Deck: an icon, a line of text and
// an optional button. `tone` is "accent" or "urgent".
BorderSurface {
  id: notice

  property string icon: ""
  property string text: ""
  property string tone: "accent"
  property string actionLabel: ""
  property bool busy: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property string fontFamily: Style.font.family

  signal actioned()

  readonly property color toneColor: tone === "urgent" ? urgent : accent

  width: parent ? parent.width : implicitWidth
  radius: Style.cornerRadius
  color: Qt.rgba(toneColor.r, toneColor.g, toneColor.b, 0.12)
  borderSpec: Border.flat(Qt.rgba(toneColor.r, toneColor.g, toneColor.b, 0.45), Math.max(1, Style.normalBorderWidth))
  implicitHeight: Math.max(label.implicitHeight, actionButton.visible ? actionButton.implicitHeight : 0) + Style.space(14)

  Item {
    id: iconBox
    anchors.left: parent.left
    anchors.leftMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(22)
    height: Style.font.title

    Icon {
      anchors.centerIn: parent
      name: notice.icon || "battery"
      size: Style.font.title
      color: notice.toneColor
    }
  }

  Text {
    id: label
    anchors.left: iconBox.right
    anchors.leftMargin: Style.space(10)
    anchors.right: actionButton.visible ? actionButton.left : parent.right
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    maximumLineCount: 4
    elide: Text.ElideRight
    text: notice.text
    color: notice.foreground
    font.family: notice.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Button {
    id: actionButton
    anchors.right: parent.right
    anchors.rightMargin: Style.space(6)
    anchors.verticalCenter: parent.verticalCenter
    visible: notice.actionLabel !== ""
    enabled: !notice.busy
    text: notice.actionLabel
    fontSize: Style.font.bodySmall
    foreground: notice.foreground
    fontFamily: notice.fontFamily
    bordered: true
    onClicked: notice.actioned()
  }
}
