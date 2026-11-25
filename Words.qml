import QtQuick

// A line of the panel's and hover card's own text: MonoText (every font
// pixel on whole device pixels, in a step, never bold) that wraps. It breaks
// between words, and inside a word only when one alone is wider than the
// line. Readings go through Model.keepTogether before they get here, so a
// line never breaks inside "2h 00m" or before a "·".
MonoText {
  textFormat: Text.PlainText
  wrapMode: Text.Wrap
}
