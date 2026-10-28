import QtQuick
import qs.Commons
import qs.Commons as Commons

// The icon in every part of the panel kit. Batteries draws Tabler icons by
// name (Icon.qml), so devices look the same on every Nerd Font build; the
// other plugins' copies of this file type a Nerd Font glyph. The other kit
// files are the same in all four plugins.
Icon {
  property string icon: ""
  // Unused here; kept so every plugin's Glyph takes the same properties.
  property string fontFamily: Style.font.family

  name: icon || "battery"
  size: Style.font.body
  color: Commons.Color.foreground
}
