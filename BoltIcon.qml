import QtQuick
import QtQuick.Shapes

// The charging bolt, drawn rather than typed so it never depends on which
// glyphs the theme's Nerd Font build carries.
Item {
  id: root
  property color color: "white"

  implicitWidth: Math.round(implicitHeight * 0.62)
  implicitHeight: 12

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: root.color
      scale: Qt.size(root.width / 10, root.height / 16)

      startX: 6.5; startY: 0
      PathLine { x: 0.5; y: 9.2 }
      PathLine { x: 4.6; y: 9.2 }
      PathLine { x: 3.5; y: 16 }
      PathLine { x: 9.5; y: 6.4 }
      PathLine { x: 5.4; y: 6.4 }
      PathLine { x: 6.5; y: 0 }
    }
  }
}
