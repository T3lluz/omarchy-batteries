import QtQuick
import qs.Commons
import qs.Commons as Commons

// A level bar: a track, a fill, and an optional marker (the charge limit).
Rectangle {
  id: levelBar

  property real level: 0
  property color fill: Commons.Color.foreground
  property color track: Qt.rgba(fill.r, fill.g, fill.b, 0.12)
  property color markerColor: Qt.darker(Commons.Color.foreground, 1.55)
  property real marker: 0

  height: Math.max(4, Style.space(5))
  radius: height / 2
  color: track

  Rectangle {
    width: Math.max(levelBar.level > 0 ? parent.height : 0, parent.width * Math.max(0, Math.min(100, levelBar.level || 0)) / 100)
    height: parent.height
    radius: parent.radius
    color: levelBar.fill
    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
  }

  Rectangle {
    visible: levelBar.marker > 0 && levelBar.marker < 100
    x: levelBar.width * levelBar.marker / 100 - width / 2
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(2, Style.space(2))
    height: parent.height + Style.space(6)
    radius: width / 2
    color: levelBar.markerColor
  }
}
