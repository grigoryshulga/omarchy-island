import QtQuick
import qs.Commons
import "../.." as Island

Canvas {
  id: field
  required property string mode
  required property real fraction
  required property real seconds
  required property bool onBreak
  required property bool live
  readonly property color ink: Island.Design.accent
  readonly property int pitch: Math.max(2,Style.space(4))
  readonly property int rows: 8
  implicitHeight: rows * pitch
  Accessible.ignored: true

  function redraw() { if (live && visible) requestPaint() }
  onSecondsChanged: redraw()
  onFractionChanged: redraw()
  onModeChanged: redraw()
  onOnBreakChanged: redraw()
  onLiveChanged: redraw()
  onVisibleChanged: redraw()
  onInkChanged: redraw()
  onPitchChanged: redraw()
  onWidthChanged: redraw()
  onHeightChanged: redraw()

  onPaint: {
    if (!live || !visible || width <= 0 || height <= 0) return
    const ctx = getContext("2d")
    ctx.reset()
    const columns = Math.floor(width / pitch)
    const left = (width - columns * pitch) / 2
    const top = (height - rows * pitch) / 2
    const dot = Math.max(1,Math.round(pitch * 0.6))
    const tau = 2 * Math.PI
    ctx.fillStyle = ink
    for (let column = 0; column < columns; column++) {
      const x = (column + 0.5) / columns
      const px = left + (column + 0.5) * pitch
      let crest = 0
      if (mode === "timer")
        crest = 1.4 + fraction * 5.9 + 1.3 * Math.sin(tau * (1.6 * x - seconds / 4))
      else if (mode === "pomodoro")
        crest = 3.5 + (onBreak ? 1.35 : 2.65) * Math.sin(tau * (x - seconds / (onBreak ? 8 : 5)))
      for (let row = 0; row < rows; row++) {
        let light
        if (mode === "stopwatch") {
          // A slanted front and fading tail sweep the strip once per ten seconds.
          const trail = (1.24 + (seconds % 10) / 10 - x - row * 0.009) % 1
          light = Math.max(0, 1 - trail / 0.22) ** 2
        } else {
          const distance = Math.abs(row - crest)
          light = Math.max(0, 1 - distance / 1.7)
          if (mode === "timer")
            light = Math.max(light, row > crest ? 0.27 : 0) * Math.min(1,(1-fraction)*20)
        }
        ctx.globalAlpha = 0.09 + 0.85 * light
        const py = top + (row + 0.5) * pitch
        ctx.fillRect(Math.round(px - dot/2),Math.round(py - dot/2),dot,dot)
      }
    }
  }
}
