import QtQuick
import QtQuick.Effects
import "Model.js" as Model

// A bar item's device icon, in pixel art. While it is on a charger, a dark
// band rises through it every few seconds and the icon stays at full
// brightness between sweeps. That includes full or held at a limit, so a
// connected charger always shows, on the device itself rather than as an
// extra glyph. The band is pixel art too: hard edged, a whole cell at a time.
Item {
  id: root
  // A name from Pixels.js.
  property string name: "battery-medium"
  // Device pixels per cell of the icon's halved grid (PixelIcon.unit).
  property int unit: 1
  property color color: "white"
  property bool powered: false
  // 0 to 1: how far the band has risen, from below the icon to above it.
  property real flow: 0

  implicitWidth: art.implicitWidth
  implicitHeight: art.implicitHeight

  PixelIcon {
    id: art
    name: root.name
    unit: root.unit
    color: root.color
  }

  // While on a charger the icon shows only through the effect below. Hidden by
  // its texture rather than `visible: false`, which would stop it rendering.
  ShaderEffectSource {
    id: artTexture
    visible: false
    sourceItem: art
    hideSource: root.powered
    live: root.powered
    smooth: false
  }

  // Opaque except for the band, three cells of the icon's halved grid tall.
  // It starts below the icon and ends above it, moving a whole cell at a time,
  // so most steps of the clock change nothing and repaint nothing. The mask
  // is hidden by its texture too, or moving it would not repaint the bar.
  Item {
    id: mask
    width: art.width
    height: art.height
    clip: true

    readonly property real cell: art.width / 12
    readonly property int bandCells: 3

    readonly property real bandY: Math.round((1 - root.flow) * (12 + bandCells) - bandCells) * cell

    // Solid above and below the band, never under it: a see-through band
    // laid over solid white would come out solid.
    Rectangle {
      width: parent.width
      height: Math.max(0, mask.bandY)
      color: "white"
    }

    Rectangle {
      y: mask.bandY
      width: parent.width
      height: mask.cell * mask.bandCells
      color: Qt.rgba(1, 1, 1, Model.CHARGE_BAND_ALPHA)
    }

    Rectangle {
      y: Math.max(0, mask.bandY + mask.cell * mask.bandCells)
      width: parent.width
      height: Math.max(0, parent.height - y)
      color: "white"
    }
  }

  ShaderEffectSource {
    id: maskTexture
    visible: false
    sourceItem: mask
    hideSource: true
    live: root.powered
    smooth: false
  }

  MultiEffect {
    visible: root.powered
    anchors.fill: parent
    source: artTexture
    maskEnabled: true
    maskSource: maskTexture
    // A threshold of 0.5 spread by 1 ramps from alpha 0 to 1: the mask's
    // alpha passes through as it is.
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }

  // Each step repaints the whole bar on every monitor; see Model.chargeStep.
  Timer {
    repeat: true
    triggeredOnStart: true
    running: root.powered && root.visible
    onTriggered: {
      const step = Model.chargeStep(Date.now(), 80)
      root.flow = step.flow
      interval = step.wait
    }
  }
}
