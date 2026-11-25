import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model

// The icon in every part of the panel kit. The kit hands it a Nerd Font
// glyph, `icon` being the character (Model.GLYPHS names the ones this plugin
// uses). Where the glyph has a pixel icon (Model.PIXEL_GLYPHS) that is drawn
// instead, so the kit's icons match the rooms'; anything else is typed. The
// bar draws Tabler icons (Icon.qml).
//
// The pixel icon acts out what it is (Motion.js) without the kit asking:
// when it comes into view, top to bottom down the page; when it turns into
// another icon; and when the tile or row it sits in is switched (the kit's
// `checked`). The warning mark loops while it is shown: in the kit it only
// ever stands for something that needs you.
Item {
  id: glyph

  property string icon: ""
  property real size: Style.font.body
  property color color: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property int play: 0
  property bool playOnChange: false

  // The notice it sits in is busy (an update under way, the password
  // prompt up): the refresh arrows turn in quarters until it is done, since a
  // smooth spin would smear pixel art.
  readonly property bool busy: !!parent && parent.busy === true
  readonly property string pixel: busy ? "reload" : Model.pixelFor(icon)
  property int cues: 0

  implicitWidth: size
  implicitHeight: size

  function cue() {
    // Down the page: an icon lower down follows a little later.
    var y = glyph.mapToItem(null, 0, 0).y
    pixelIcon.delay = Math.max(0, Math.min(360, Math.round(y * 0.6)))
    cues++
  }

  onVisibleChanged: if (visible && pixel !== "") cue()

  // The kit's tiles and rows say when they are switched.
  Connections {
    target: glyph.parent
    ignoreUnknownSignals: true
    function onCheckedChanged() { pixelIcon.delay = 0; glyph.cues++ }
  }

  PixelIcon {
    id: pixelIcon
    visible: glyph.pixel !== ""
    anchors.centerIn: parent
    name: glyph.pixel
    size: glyph.size
    color: glyph.color
    play: glyph.play + glyph.cues
    playOnChange: glyph.playOnChange
    act: glyph.busy ? "reload-busy" : glyph.pixel
    loop: glyph.busy || glyph.pixel === "warning-diamond"
  }

  Text {
    visible: glyph.pixel === ""
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: glyph.icon
    color: glyph.color
    // The typed glyphs are Nerd Font icons, which only the shell's font has;
    // the panel's Monocraft would leave them to a random fallback.
    font.family: Style.font.family
    font.pixelSize: glyph.size
  }
}
