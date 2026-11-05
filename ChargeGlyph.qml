import QtQuick
import QtQuick.Effects
import "Model.js" as Model

// A device drawn in the panel. While it charges a soft dark band rises through
// it every few seconds, the way the bar's icons show charging.
Item {
  id: root

  // Draws the device; sized to fill this item.
  property Component glyph: null
  property bool charging: false
  // 0 to 1: how far the band has risen through the drawing.
  property real flow: 0

  Loader {
    id: art
    width: root.width
    height: root.height
    sourceComponent: root.glyph
  }

  // While charging, the drawing is shown only through the effect below.
  // Hidden by its texture rather than `visible: false`, which would stop the
  // AirPods outline's own layer from rendering.
  ShaderEffectSource {
    id: artTexture
    visible: false
    sourceItem: art
    hideSource: root.charging
    live: root.charging
    smooth: true
  }

  // Opaque except for the band, so the drawing stays at full brightness between
  // sweeps. The mask goes through a texture too, or moving the band would not
  // repaint the panel.
  Item {
    id: mask
    width: root.width
    height: root.height
    clip: true

    // Rises from below the drawing to above it, one band per cycle.
    Rectangle {
      id: sweep
      readonly property real band: root.height * 1.5
      y: -(root.height + band) * root.flow
      width: parent.width
      height: root.height * 2 + band
      // `at` runs across the band, 0 to 1. A big drawing shows a straight fade's
      // corners as hard lines at the band's ends, so these stops follow a curve.
      function place(at) { return (root.height + band * at) / height }
      function tint(at) { return Qt.rgba(1, 1, 1, Model.chargeBandAlpha(at)) }
      gradient: Gradient {
        GradientStop { position: sweep.place(0); color: sweep.tint(0) }
        GradientStop { position: sweep.place(0.125); color: sweep.tint(0.125) }
        GradientStop { position: sweep.place(0.25); color: sweep.tint(0.25) }
        GradientStop { position: sweep.place(0.375); color: sweep.tint(0.375) }
        GradientStop { position: sweep.place(0.5); color: sweep.tint(0.5) }
        GradientStop { position: sweep.place(0.625); color: sweep.tint(0.625) }
        GradientStop { position: sweep.place(0.75); color: sweep.tint(0.75) }
        GradientStop { position: sweep.place(0.875); color: sweep.tint(0.875) }
        GradientStop { position: sweep.place(1); color: sweep.tint(1) }
      }
    }
  }

  ShaderEffectSource {
    id: maskTexture
    visible: false
    sourceItem: mask
    hideSource: true
    live: root.charging
    smooth: true
  }

  MultiEffect {
    visible: root.charging
    anchors.fill: parent
    source: artTexture
    maskEnabled: true
    maskSource: maskTexture
    // A threshold of 0.5 spread by 1 passes the mask's alpha through as is.
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }

  // Faster steps than the bar's, because the drawing is bigger, its band travels
  // further and the panel is only open for a moment. See Model.chargeStep. A
  // closed panel's window is hidden while this item still counts as visible, so
  // check the window too.
  Timer {
    repeat: true
    triggeredOnStart: true
    running: root.charging && root.visible && root.Window.visibility !== Window.Hidden
    onTriggered: {
      const step = Model.chargeStep(Date.now(), 33)
      root.flow = step.flow
      interval = step.wait
    }
  }
}
