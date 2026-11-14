import QtQuick
import qs.Commons
import qs.Commons as Commons

Canvas {
  id:root
  property bool active:true
  property real phase:0
  property color accent:Design.accent
  property color trackColor:Design.progressTrack
  implicitHeight:Style.space(8)
  onWidthChanged:requestPaint()
  onHeightChanged:requestPaint()
  onPhaseChanged:requestPaint()
  onActiveChanged:requestPaint()
  onAccentChanged:requestPaint()
  onTrackColorChanged:requestPaint()
  NumberAnimation on phase {
    from:0;to:1;duration:Preferences.duration(1600);loops:Animation.Infinite
    running:root.active && root.visible && !Preferences.reduceMotion
  }
  onPaint: {
    var ctx=getContext("2d"),pitch=Style.space(3),band=0.25
    ctx.clearRect(0,0,width,height)
    // Unknown total: move a braille segment rather than imply a percentage.
    var position=Preferences.reduceMotion ? 0.4 : phase*(1+band)-band
    for(var x=pitch/2;x<width;x+=pitch) {
      var lit=!active || (x/width>=position && x/width<=position+band)
      for(var y=height/8;y<height;y+=height/4) {
        ctx.fillStyle=trackColor;ctx.globalAlpha=0.32
        ctx.beginPath();ctx.arc(x,y,Style.space(0.72),0,Math.PI*2);ctx.fill()
        if(lit) {
          ctx.fillStyle=accent;ctx.globalAlpha=0.95
          ctx.beginPath();ctx.arc(x,y,Style.space(0.85),0,Math.PI*2);ctx.fill()
        }
      }
    }
  }
}
