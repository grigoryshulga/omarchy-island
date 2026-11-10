import QtQuick
import qs.Commons
import qs.Commons as Commons

Canvas {
  id:root
  property bool active:true
  property real phase:0
  property color accent:Commons.Color.accent
  implicitHeight:Style.space(8)
  onWidthChanged:requestPaint()
  onHeightChanged:requestPaint()
  onPhaseChanged:requestPaint()
  onActiveChanged:requestPaint()
  onAccentChanged:requestPaint()
  NumberAnimation on phase {
    from:0;to:1;duration:Style.duration(1600);loops:Animation.Infinite
    running:root.active && root.visible && !Style.reduceMotion
  }
  onPaint: {
    var ctx=getContext("2d"),pitch=Style.space(3),band=0.25
    ctx.clearRect(0,0,width,height)
    ctx.fillStyle=accent
    // Unknown total: move a braille segment rather than imply a percentage.
    var position=Style.reduceMotion ? 0.4 : phase*(1+band)-band
    for(var x=pitch/2;x<width;x+=pitch) {
      var lit=!active || (x/width>=position && x/width<=position+band)
      ctx.globalAlpha=lit ? 0.95 : 0.18
      for(var y=height/8;y<height;y+=height/4) {
        ctx.beginPath();ctx.arc(x,y,Style.space(lit ? 0.85 : 0.5),0,Math.PI*2);ctx.fill()
      }
    }
  }
}
