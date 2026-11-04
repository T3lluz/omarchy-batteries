import QtQuick
import QtQuick.Effects
import "Model.js" as Model

// A bar item's device icon. While it is on a charger, the icon dims and a soft
// bright band rises through it every few seconds, like charge flowing in from
// the cable. That includes full or held at a limit, so a connected charger
// always shows, on the device itself rather than as an extra glyph.
Item {
  id: root
  // A name from Icons.js, or "airpods" for the drawn AirPods outline.
  property string name: "battery"
  property string variant: "buds"
  property real size: 16
  property color color: "white"
  property bool powered: false
  // 0 to 1: how far the band has risen, from below the icon to above it.
  property real flow: 0

  implicitWidth: size
  implicitHeight: size

  Item {
    anchors.fill: parent
    opacity: root.powered ? 0.5 : 1
    // Flattened first, or the strokes' overlaps at the corners show brighter
    // than the rest once the icon dims.
    layer.enabled: root.powered
    layer.smooth: true

    Glyph { name: root.name; variant: root.variant; size: root.size; color: root.color }
  }

  // The bright copy, shown only where the mask lets it through. It and the
  // mask are hidden by their textures rather than `visible: false`: hidden
  // items stop the AirPods outline's own layer from rendering, and moving
  // the mask would not repaint the bar.
  Glyph {
    id: bright
    name: root.name
    variant: root.variant
    size: root.size
    color: root.color
  }

  ShaderEffectSource {
    id: brightTexture
    visible: false
    sourceItem: bright
    hideSource: true
    live: root.powered
    smooth: true
  }

  // A gradient rather than a clip: a clip cuts on whole pixels and steps, the
  // gradient moves by fractions of one, and its soft edges hide the steps.
  Item {
    id: mask
    width: root.size
    height: root.size
    clip: true

    Rectangle {
      readonly property real travel: root.size + height
      y: root.size - travel * root.flow
      width: parent.width
      height: root.size
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
    live: root.powered
    smooth: true
  }

  MultiEffect {
    visible: root.powered
    anchors.fill: parent
    source: brightTexture
    maskEnabled: true
    maskSource: maskTexture
    // A threshold of 0.5 spread by 1 ramps from alpha 0 to 1: the mask's
    // alpha passes through as it is, so the band edges stay soft.
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1
  }

  // Inline components cannot see `root`, so the glyph takes what it draws.
  component Glyph: Item {
    id: glyph
    property string name
    property string variant
    property real size
    property color color
    width: size
    height: size

    Icon {
      visible: glyph.name !== "airpods"
      name: glyph.name
      size: glyph.size
      color: glyph.color
    }

    AirPodsIcon {
      visible: glyph.name === "airpods"
      iconSize: glyph.size
      variant: glyph.variant
      color: glyph.color
    }
  }

  // Each step repaints the whole bar on every monitor, so the band moves about
  // once per screen pixel (12.5 steps a second) and not at all between sweeps.
  // See Model.chargeStep.
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
