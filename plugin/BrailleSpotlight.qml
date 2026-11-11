import QtQuick
import qs.Commons
import qs.Commons as Commons
import "SpotlightModel.js" as Spotlight
import "SpotlightTrail.js" as Trail

ShaderEffect {
  id: root
  property bool active: false
  property bool adaptive: true
  property Item surfaceRoot: null
  readonly property var hoveredSurface: active && surfaceRoot ? Spotlight.pick(surfaceRoot,root,pointer) : null
  readonly property var nearbySurfaces: active && surfaceRoot ? Spotlight.neighbors(surfaceRoot,root,pointer,spotRadius*0.75) : []
  function neighborRect(index) {
    if (index >= nearbySurfaces.length) return Qt.vector4d(0,0,0,0)
    var rect = nearbySurfaces[index].rect
    return Qt.vector4d(rect.x,rect.y,rect.width,rect.height)
  }
  readonly property vector4d neighbor0: neighborRect(0)
  readonly property vector4d neighbor1: neighborRect(1)
  readonly property vector4d neighbor2: neighborRect(2)
  readonly property vector4d neighbor3: neighborRect(3)
  readonly property vector4d neighborRadii: Qt.vector4d(
    nearbySurfaces.length>0 ? nearbySurfaces[0].radius : 0,
    nearbySurfaces.length>1 ? nearbySurfaces[1].radius : 0,
    nearbySurfaces.length>2 ? nearbySurfaces[2].radius : 0,
    nearbySurfaces.length>3 ? nearbySurfaces[3].radius : 0)
  readonly property real focused: hoveredSurface ? 1 : 0
  readonly property vector4d focusRect: {
    if (!hoveredSurface) return Qt.vector4d(0,0,width,height)
    var at=hoveredSurface.mapToItem(root,0,0)
    return Qt.vector4d(at.x,at.y,hoveredSurface.width,hoveredSurface.height)
  }
  readonly property real focusRadius: hoveredSurface ? Spotlight.radius(hoveredSurface) : cornerRadius
  property var trailSamples: []
  property point lastTrailPoint: Qt.point(0,0)
  property real trailTime: 0
  readonly property bool trailPending: trailSamples.length>0 || Math.abs(pointer.x-lastTrailPoint.x)>=1 || Math.abs(pointer.y-lastTrailPoint.y)>=1
  function clearTrail() { trailSamples=[];lastTrailPoint=pointer }
  function trailSample(index) {
    if(index>=trailSamples.length || Preferences.reduceMotion) return Qt.vector4d(0,0,0,0)
    var sample=trailSamples[index]
    return Qt.vector4d(sample.x,sample.y,Trail.weight(trailTime-sample.time),0)
  }
  readonly property vector4d trail0: trailSample(0)
  readonly property vector4d trail1: trailSample(1)
  readonly property vector4d trail2: trailSample(2)
  readonly property vector4d trail3: trailSample(3)
  readonly property vector4d trail4: trailSample(4)
  readonly property vector4d trail5: trailSample(5)
  readonly property vector4d trail6: trailSample(6)
  readonly property vector4d trail7: trailSample(7)
  readonly property vector4d trail8: trailSample(8)
  readonly property vector4d trail9: trailSample(9)
  readonly property vector4d trail10: trailSample(10)
  readonly property vector4d trail11: trailSample(11)
  property vector4d edgeImpact: Qt.vector4d(0,0,0,0)
  property real edgeProgress: 1
  readonly property real edgeEnabled: focused && active && !Preferences.reduceMotion ? 1 : 0
  function clearEdge() {edgeBurst.stop();edgeProgress=1}
  function collide(previous, point) {
    if(!hoveredSurface || Preferences.reduceMotion) return
    var rect={x:focusRect.x,y:focusRect.y,width:focusRect.z,height:focusRect.w}
    var hit=Spotlight.collision(previous,point,rect,focusRadius,spotRadius*0.32)
    if(!hit) return
    edgeImpact=Qt.vector4d(hit.x,hit.y,hit.nx,hit.ny)
    edgeBurst.restart()
  }
  NumberAnimation {id:edgeBurst;target:root;property:"edgeProgress";from:0;to:1;duration:Preferences.duration(800);easing.type:Easing.Linear}
  onActiveChanged: {clearTrail();clearEdge()}
  onHoveredSurfaceChanged: {clearTrail();clearEdge()}
  Connections {
    target: Preferences
    function onReduceMotionChanged() {root.clearTrail();root.clearEdge()}
  }
  Timer {
    objectName:"spotlightTrailClock"
    interval:32;repeat:true
    running:root.active && root.visible && !Preferences.reduceMotion && root.trailPending
    onTriggered: {
      var now=Date.now()
      root.collide(root.lastTrailPoint,root.pointer)
      root.trailTime=now
      root.trailSamples=Trail.advance(root.trailSamples,root.lastTrailPoint,root.pointer,now)
      root.lastTrailPoint=root.pointer
    }
  }
  property url artworkUrl: ""
  property var source: cover
  property real artworkStrength: 1
  property real artworkMix: artworkUrl.toString()!=="" && cover.status===Image.Ready ? artworkStrength : 0
  property point pointer: Qt.point(width/2,height/2)
  property point rippleOrigin: Qt.point(width/2,height/2)
  property real shown: active ? 1 : 0
  property vector2d size: Qt.vector2d(width,height)
  property vector2d center: Qt.vector2d(pointer.x,pointer.y)
  property vector2d rippleCenter: Qt.vector2d(rippleOrigin.x,rippleOrigin.y)
  property real phase: 0
  property real spotRadius: Style.space(80)
  property real cornerRadius: Style.cornerRadius
  property color accent: Commons.Color.accent
  property real profile: adaptive ? 1 : 0
  property real intensity: 1
  property real hoverOpacity: shown*intensity
  Behavior on intensity {NumberAnimation {duration:Preferences.duration(140);easing.type:Easing.OutCubic}}
  property real rippleProgress: 1
  readonly property bool rippling: rippleProgress < 0.24
  visible: shown > 0 || rippling
  vertexShader: Qt.resolvedUrl("shaders/spotlight.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/spotlight.frag.qsb")
  Image {
    id: cover
    anchors.fill: parent
    source: root.artworkUrl.toString()!=="" ? root.artworkUrl : Qt.resolvedUrl("assets/dot-field.svg")
    sourceSize: Qt.size(240,240)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    visible: false
    layer.enabled: true
  }
  Behavior on artworkMix { NumberAnimation { duration: Preferences.duration(180); easing.type: Easing.OutCubic } }
  function pulse(point) {
    if (Preferences.reduceMotion) return
    rippleOrigin=point
    rippleProgress=0
    wave.restart()
  }
  Behavior on shown { NumberAnimation { duration: Preferences.duration(root.active ? 160 : 120); easing.type: Easing.OutCubic } }
  NumberAnimation on phase { running: root.visible && !Preferences.reduceMotion; from: 0; to: 1200; duration: 1200000; loops: Animation.Infinite }
  // A time cursor lets travel and brightness ease independently in the shader.
  NumberAnimation { id: wave; target: root; property: "rippleProgress"; from: 0; to: 1; duration: Preferences.duration(1560); easing.type: Easing.Linear }
}
