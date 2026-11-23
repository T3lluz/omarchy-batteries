import QtQuick
import QtQuick.Window
import qs.Commons
import "Model.js" as Model

// A line of the panel's own text in Monocraft, set so the pixel face stays
// whole: a size that lands its cells on whole device pixels
// (Model.crispTextSize), drawn natively so each line starts on a pixel, and
// two cells of air between wrapped lines, where Monocraft's own spacing
// leaves a descender touching the capitals below. It breaks between words,
// inside a word only when one alone is wider than the line, and keeps the
// pieces of a reading together (Model.keepTogether).
Text {
  id: words

  // The shell's size token it stands for, before it is made sharp.
  property real size: Style.font.bodySmall
  property string family: Style.font.family

  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
  readonly property real cellSize: Model.crispTextSize(size, dpr)
  // One line's height before it wraps, to line a neighbour up with the first.
  readonly property real lineSize: Math.round(cellSize * 4 / 3 * dpr) / dpr

  textFormat: Text.PlainText
  wrapMode: Text.Wrap
  renderType: Text.NativeRendering
  font.family: family
  font.pixelSize: cellSize
  // Fourteen cells a line once it wraps; Monocraft's own is twelve.
  lineHeightMode: lineCount > 1 ? Text.FixedHeight : Text.ProportionalHeight
  lineHeight: lineCount > 1 ? Math.round(cellSize * 14 / 9 * dpr) / dpr : 1
}
