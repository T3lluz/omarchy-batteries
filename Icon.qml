import QtQuick
import QtQuick.Shapes
import "Icons.js" as Icons
import "Marks.js" as Marks

// A Tabler outline icon from Icons.js, stroked in `color`. Drawn rather than
// typed, so it follows the theme and never depends on the Nerd Font build.
// Marks.js adds filled marks such as the JBL lettering, drawn solid in the
// same colour.
Item {
  id: root
  property string name: "battery"
  property color color: "white"
  property real size: 16
  // Tabler's 2px stroke on its 24px grid, scaled with the icon.
  property real weight: 2
  // Draw across the item's full width rather than at `size`; marks always do.
  property bool fullWidth: false

  readonly property string fill: Marks.fills[name] || ""

  implicitWidth: size
  implicitHeight: size

  Shape {
    id: shape
    // A mark is a wordmark, much wider than tall, so it takes the full width
    // it is given (a section header's icon box) and centres on the line.
    readonly property real side: root.fill || root.fullWidth ? root.width : root.size
    y: root.fill || root.fullWidth ? (root.height - side) / 2 : 0
    width: side
    height: side
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.fill ? root.color : "transparent"
      // Odd-even, or the counters of the B fill in.
      fillRule: ShapePath.OddEvenFill
      strokeColor: root.fill ? "transparent" : root.color
      // Negative turns the stroke off; zero would still draw a hairline.
      strokeWidth: root.fill ? -1 : Math.max(1, root.weight * shape.side / 24)
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      scale: Qt.size(shape.side / 24, shape.side / 24)

      PathSvg { path: root.fill || Icons.paths[root.name] || Icons.paths["battery"] }
    }
  }
}
