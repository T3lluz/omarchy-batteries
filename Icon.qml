import QtQuick
import QtQuick.Shapes
import "Icons.js" as Icons
import "Marks.js" as Marks

// A Tabler outline icon from Icons.js, stroked in `color`. Drawn rather than
// typed, so it follows the theme and never depends on the Nerd Font build.
// Marks.js adds filled marks such as the JBL lettering, drawn solid in the
// same colour. With `solid`, the icon is drawn from Tabler's filled version
// where there is one.
Item {
  id: root
  property string name: "battery"
  property color color: "white"
  property real size: 16
  // Tabler's 2px stroke on its 24px grid, scaled with the icon.
  property real weight: 2
  // Draw across the item's full width rather than at `size`; marks always do.
  property bool fullWidth: false
  property bool solid: false

  readonly property string mark: Marks.fills[name] || ""
  readonly property string solidPath: solid ? Icons.filled[name] || "" : ""
  readonly property string fill: mark || solidPath

  implicitWidth: size
  implicitHeight: size

  Shape {
    id: shape
    // A mark is a wordmark, much wider than tall, so it takes the full width
    // it is given (a section header's icon box) and centres on the line.
    readonly property real side: root.mark || root.fullWidth ? root.width : root.size
    y: root.mark || root.fullWidth ? (root.height - side) / 2 : 0
    width: side
    height: side
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.fill ? root.color : "transparent"
      // Odd-even, or the counters of the B fill in. Solid icons fill
      // non-zero, as their SVGs do.
      fillRule: root.mark ? ShapePath.OddEvenFill : ShapePath.WindingFill
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
