import QtQuick
import qs.Commons
import qs.Commons as Commons

// The laptop's charge over the last hours: a filled line on a 0 to 100%
// scale, in the accent colour where it was charging. Gaps (the laptop asleep
// or off) break the line instead of drawing a ramp across them.
Item {
  id: root

  // [[unixSeconds, level, charging], ...] oldest first (Model.parseHistory).
  property var samples: []
  property real hours: 12
  property real nowSec: Date.now() / 1000
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent

  implicitHeight: Style.space(44)

  onSamplesChanged: { nowSec = Date.now() / 1000; chart.requestPaint() }
  onWidthChanged: chart.requestPaint()
  onForegroundChanged: chart.requestPaint()
  onAccentChanged: chart.requestPaint()

  Canvas {
    id: chart
    anchors.fill: parent
    antialiasing: true

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width, h = height
      ctx.fillStyle = Util.alpha(root.foreground, 0.035)
      ctx.fillRect(0, 0, w, h)

      // Guides at 20%, 50% and 80%.
      ctx.strokeStyle = Util.alpha(root.foreground, 0.08)
      ctx.lineWidth = 1
      var guides = [20, 50, 80]
      for (var g = 0; g < guides.length; g++) {
        var gy = Math.round(yFor(guides[g])) + 0.5
        ctx.beginPath(); ctx.moveTo(0, gy); ctx.lineTo(w, gy); ctx.stroke()
      }

      var from = root.nowSec - root.hours * 3600
      var list = (root.samples || []).filter(function(s) { return s[0] >= from })
      if (list.length < 2) return

      function xFor(t) { return Math.max(0, Math.min(w, (t - from) / (root.hours * 3600) * w)) }
      function yFor(level) { return h - 1 - Math.max(0, Math.min(100, level)) / 100 * (h - 3) }

      // Runs of samples no more than 15 minutes apart.
      var runs = [], run = [list[0]]
      for (var i = 1; i < list.length; i++) {
        if (list[i][0] - list[i - 1][0] > 900) { runs.push(run); run = [] }
        run.push(list[i])
      }
      runs.push(run)

      for (var r = 0; r < runs.length; r++) {
        var pts = runs[r]
        if (pts.length < 2) continue
        // Area under the line, then the line, one segment at a time so a
        // charging stretch takes the accent colour.
        ctx.beginPath()
        ctx.moveTo(xFor(pts[0][0]), h)
        for (var p = 0; p < pts.length; p++) ctx.lineTo(xFor(pts[p][0]), yFor(pts[p][1]))
        ctx.lineTo(xFor(pts[pts.length - 1][0]), h)
        ctx.closePath()
        var grad = ctx.createLinearGradient(0, 0, 0, h)
        grad.addColorStop(0, Util.alpha(root.foreground, 0.16))
        grad.addColorStop(1, Util.alpha(root.foreground, 0.01))
        ctx.fillStyle = grad
        ctx.fill()

        ctx.lineWidth = Math.max(1, Style.space(1.5))
        ctx.lineCap = "round"
        for (var q = 1; q < pts.length; q++) {
          ctx.beginPath()
          ctx.moveTo(xFor(pts[q - 1][0]), yFor(pts[q - 1][1]))
          ctx.lineTo(xFor(pts[q][0]), yFor(pts[q][1]))
          ctx.strokeStyle = pts[q][2] ? root.accent : root.foreground
          ctx.stroke()
        }
      }
    }
  }

  // Redraws as time moves the window along, without waiting for a sample.
  Timer {
    interval: 60000
    repeat: true
    running: root.visible
    onTriggered: { root.nowSec = Date.now() / 1000; chart.requestPaint() }
  }
}
