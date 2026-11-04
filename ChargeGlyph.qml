import QtQuick
import QtQuick.Effects
import "Model.js" as Model

// A device drawn in the panel. While it charges it dims and a soft band rises
// through it every few seconds, the way the bar's icons show charging.
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

  // Dim everywhere, bright where the band is. The mask goes through a
  // texture too, or moving the band would not repaint the panel.
  Item {
    id: mask
    width: root.width
    height: root.height
    clip: true

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(1, 1, 1, 0.5)
    }

    // Rises from below the drawing to above it, one band per cycle.
    Rectangle {
      readonly property real travel: root.height + height
      y: root.height - travel * root.flow
      width: parent.width
      height: Math.max(root.height * 0.5, 8)
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: "white" }
        GradientStop { position: 1.0; color: "transparent" }
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

  // Faster steps than the bar's, because the drawing is bigger and the panel is
  // only open for a moment. See Model.chargeStep. A closed panel's window is
  // hidden while this item still counts as visible, so check the window too.
  Timer {
    repeat: true
    triggeredOnStart: true
    running: root.charging && root.visible && root.Window.visibility !== Window.Hidden
    onTriggered: {
      const step = Model.chargeStep(Date.now(), 50)
      root.flow = step.flow
      interval = step.wait
    }
  }
}
