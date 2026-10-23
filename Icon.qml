import QtQuick
import QtQuick.Shapes
import "Icons.js" as Icons

// A Tabler outline icon from Icons.js, stroked in `color`. Drawn rather than
// typed, so it follows the theme and never depends on the Nerd Font build.
Item {
  id: root
  property string name: "battery"
  property color color: "white"
  property real size: 16
  // Tabler's 2px stroke on its 24px grid, scaled with the icon.
  property real weight: 2

  implicitWidth: size
  implicitHeight: size

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: Math.max(1, root.weight * root.size / 24)
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      scale: Qt.size(root.size / 24, root.size / 24)

      PathSvg { path: Icons.paths[root.name] || Icons.paths["battery"] }
    }
  }
}
