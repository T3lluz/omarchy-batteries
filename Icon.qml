import QtQuick
import QtQuick.Shapes
import "Icons.js" as Icons
import "Marks.js" as Marks

// A Tabler outline icon from Icons.js, stroked in `color`: the bar's icons, drawn
// rather than typed so they never depend on the Nerd Font build. Marks.js adds
// filled marks such as the JBL lettering, drawn solid in the same colour.
Item {
  id: root
  property string name: "battery"
  property color color: "white"
  property real size: 16
  // Tabler's 2px stroke on its 24px grid, scaled with the icon.
  property real weight: 2

  readonly property string mark: Marks.fills[name] || ""

  implicitWidth: size
  implicitHeight: size

  Shape {
    id: shape
    // A mark is a wordmark, much wider than tall, so it takes the full width
    // it is given and centres on the line.
    readonly property real side: root.mark ? root.width : root.size
    y: root.mark ? (root.height - side) / 2 : 0
    width: side
    height: side
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.mark ? root.color : "transparent"
      // Odd-even, or the counters of the B fill in.
      fillRule: ShapePath.OddEvenFill
      strokeColor: root.mark ? "transparent" : root.color
      // Negative turns the stroke off; zero would still draw a hairline.
      strokeWidth: root.mark ? -1 : Math.max(1, root.weight * shape.side / 24)
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      scale: Qt.size(shape.side / 24, shape.side / 24)

      PathSvg { path: root.mark || Icons.paths[root.name] || Icons.paths["battery"] }
    }
  }
}
