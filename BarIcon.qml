import QtQuick
import QtQuick.Effects

// A bar item's device icon. While it charges, the icon dims and soft bright
// bands rise through it, one after another, like charge flowing in from the
// cable. Charging shows on the device itself rather than as an extra glyph.
Item {
  id: root
  // A name from Icons.js, or "airpods" for the drawn AirPods outline.
  property string name: "battery"
  property string variant: "buds"
  property real size: 16
  property color color: "white"
  property bool charging: false
  // 0 to 1: how far the bands have risen through one icon height.
  property real flow: 0

  implicitWidth: size
  implicitHeight: size

  Item {
    anchors.fill: parent
    opacity: root.charging ? 0.5 : 1
    // Flattened first, or the strokes' overlaps at the corners show brighter
    // than the rest once the icon dims.
    layer.enabled: root.charging
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
    live: root.charging
    smooth: true
  }

  // Two soft bands one icon height apart, on a strip twice the icon's height
  // that slides up by exactly one height per cycle, so the loop has no seam.
  // A gradient rather than a clip: a clip cuts on whole pixels and steps,
  // the gradient moves by fractions of one.
  Item {
    id: mask
    width: root.size
    height: root.size
    clip: true

    Rectangle {
      y: -root.size * root.flow
      width: parent.width
      height: root.size * 2
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.05; color: "transparent" }
        GradientStop { position: 0.2; color: "white" }
        GradientStop { position: 0.3; color: "white" }
        GradientStop { position: 0.45; color: "transparent" }
        GradientStop { position: 0.55; color: "transparent" }
        GradientStop { position: 0.7; color: "white" }
        GradientStop { position: 0.8; color: "white" }
        GradientStop { position: 0.95; color: "transparent" }
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

  // Unrounded, so the bands move every frame at the screen's refresh rate.
  NumberAnimation on flow {
    running: root.charging && root.visible
    from: 0
    to: 1
    duration: 2400
    loops: Animation.Infinite
  }
}
