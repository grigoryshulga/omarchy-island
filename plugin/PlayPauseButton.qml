import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

FeedbackButton {
  id: root
  property bool playing: false
  implicitWidth: Style.space(36)
  implicitHeight: implicitWidth
  readonly property bool rounded: Style.cornerRadius > 0
  radius: rounded ? width/2 : 0
  color: "transparent"
  borderSpec: Border.none()
  focusable: true
  Canvas {
    id: face
    objectName: "playPauseFace"
    anchors.fill: parent
    antialiasing: true
    property bool playing: root.playing
    property bool rounded: root.rounded
    onRoundedChanged: requestPaint()
    property color fill: !root.enabled ? Design.secondaryText : root.hot || root.activeFocus ? Design.accent : Design.text
    onPlayingChanged: requestPaint()
    onFillChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Behavior on fill { ColorAnimation { duration: Preferences.duration(120) } }
    onPaint: {
      var ctx=getContext("2d"), w=width, h=height
      ctx.reset()
      ctx.fillStyle=fill
      if (rounded) {
        ctx.beginPath()
        ctx.arc(w/2,h/2,Math.min(w,h)/2,0,Math.PI*2)
        ctx.fill()
      } else ctx.fillRect(0,0,w,h)
      // Real alpha cutouts keep the artwork visible through the icon.
      ctx.globalCompositeOperation="destination-out"
      if (playing) {
        ctx.fillRect(w*0.32,h*0.28,w*0.12,h*0.44)
        ctx.fillRect(w*0.56,h*0.28,w*0.12,h*0.44)
      } else {
        ctx.beginPath()
        ctx.moveTo(w*0.38,h*0.26)
        ctx.lineTo(w*0.73,h*0.50)
        ctx.lineTo(w*0.38,h*0.74)
        ctx.closePath()
        ctx.fill()
      }
      ctx.globalCompositeOperation="source-over"
    }
  }
}
