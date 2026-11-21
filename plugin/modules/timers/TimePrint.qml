import QtQuick
import qs.Commons
import "../.." as Island
import "../../ambient" as Ambient

// The same small luminance plate is printed with Ambient's ink shader.
// All geometry follows elapsed time; the plate has no animation clock.
Canvas {
  id: plate
  required property string mode
  required property real fraction
  property int rounds: 4
  onRoundsChanged: redraw()
  required property int step
  required property bool live
  readonly property bool printed: GraphicsInfo.api !== GraphicsInfo.Software
  readonly property int treatment: mode === "timer" ? 1 : mode === "pomodoro" ? 2 : 3
  readonly property color ground: Island.Design.surface
  readonly property color pigment: Island.Design.accent
  readonly property int units: Math.round(120 * Math.min(1,Math.max(0,fraction)))
  Accessible.ignored: true
  layer.enabled: printed && live
  layer.effect: Ambient.InkEffect {
    fromMode: plate.treatment
    cellScale: Math.max(.48,plate.width/170)
    paper: plate.ground; ink: plate.pigment; highlight: Island.Design.text
  }
  function redraw() { if (live && visible) requestPaint() }
  onUnitsChanged: redraw()
  onModeChanged: redraw()
  onStepChanged: redraw()
  onLiveChanged: redraw()
  onVisibleChanged: redraw()
  onWidthChanged: redraw()
  onHeightChanged: redraw()
  onGroundChanged: redraw()
  onPigmentChanged: redraw()
  onPrintedChanged: redraw()
  onPaint: {
    if (!live || width<=0 || height<=0) return
    var ctx = getContext("2d")
    ctx.reset()
    ctx.scale(width/100,height/100)
    var base = printed ? "#000000" : ground
    var bright = printed ? "#ffffff" : pigment
    var mid = printed ? "#555555" : Qt.tint(ground,Qt.rgba(pigment.r,pigment.g,pigment.b,.55))
    var faint = printed ? "#202020" : Qt.tint(ground,Qt.rgba(pigment.r,pigment.g,pigment.b,.23))
    ctx.fillStyle=base; ctx.fillRect(0,0,100,100)
    var f=units/120
    ctx.lineCap="round"; ctx.lineJoin="round"
    function line(points, color, weight, fill) {
      ctx.beginPath()
      ctx.moveTo(points[0],points[1])
      for (var j=2;j<points.length;j+=2) ctx.lineTo(points[j],points[j+1])
      if (fill) {ctx.closePath(); ctx.fillStyle=color; ctx.fill()}
      else {ctx.strokeStyle=color; ctx.lineWidth=weight; ctx.stroke()}
    }
    function arc(r, a, b, color, weight) {
      ctx.beginPath(); ctx.arc(50,50,r,a,b)
      ctx.strokeStyle=color; ctx.lineWidth=weight; ctx.stroke()
    }
    var tau=2*Math.PI, top=-Math.PI/2
    if (mode === "timer") {
      // Similar triangles make printed sand area proportional to time left.
      var upper=27*Math.sqrt(1-f), lower=26*(1-Math.sqrt(1-f))
      line([50,49,50-upper,49-upper,50+upper,49-upper],bright,0,true)
      line([23,79,77,79,77-lower,79-lower,23+lower,79-lower],mid,0,true)
      line([19,17,81,17],bright,4); line([19,83,81,83],bright,4)
      line([22,22,47,49,47,52,22,78],mid,2)
      line([78,22,53,49,53,52,78,78],mid,2)
      if (units>0 && units<120) line([50,52,50,78-lower],mid,1.5)
    } else if (mode === "pomodoro") {
      var round=Math.floor(step/2), onBreak=(step%2)===1
      ctx.lineCap="butt"
      for (var i=0;i<rounds;i++) {
        var start=top+i*tau/rounds+.055, end=start+tau/rounds-.11
        arc(33,start,end,i<round || (i===round && onBreak) ? bright : faint,14)
        if (i===round && !onBreak && f>0) arc(33,start,start+(end-start)*f,bright,14)
      }
      arc(18,0,tau,mid,3)
      if (onBreak && f>0) arc(18,top,top+tau*f,bright,5)
    } else {
      arc(39,0,tau,mid,2)
      for (var k=0;k<12;k++) {
        var a=top+k*tau/12, span=k%3===0 ? 8 : 4
        line([50+35*Math.cos(a),50+35*Math.sin(a),50+(35-span)*Math.cos(a),50+(35-span)*Math.sin(a)],mid,2.5)
      }
      var angle=top+tau*f
      line([50-6*Math.cos(angle),50-6*Math.sin(angle),50+31*Math.cos(angle),50+31*Math.sin(angle)],bright,4)
      arc(3,0,tau,bright,4)
    }
  }
}
