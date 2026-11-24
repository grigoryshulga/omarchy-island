import QtQuick
import qs.Commons
import qs.Commons as Commons

ShaderEffect {
  id: root
  property bool active: false
  property vector2d size: Qt.vector2d(width,height)
  property real pulseProgress: 0
  readonly property real phase: (spacing*0.5 + width*0.55*pulseProgress)/Math.max(1,speed)
  property vector2d intensity: Qt.vector2d(1.0,0.35)
  property vector2d fadeMargins: Qt.vector2d(Style.space(24),Style.space(10))
  property vector2d origin: Qt.vector2d(-18,height/2)
  property real spacing: Math.max(Style.space(120),2*width)
  property real bandWidth: Style.space(21)
  property real speed: Style.space(55)
  property real cornerRadius: Style.cornerRadius
  property color accent: Commons.Color.accent
  visible: active && pulse.running && !Preferences.reduceMotion
  opacity: Math.sin(Math.PI*pulseProgress)
  vertexShader: Qt.resolvedUrl("shaders/toast-waves.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/toast-waves.frag.qsb")
  function play() {
    if (active && duration>0) pulse.restart()
  }
  readonly property int duration:Preferences.panelDuration(440)
  onActiveChanged:if (active) play(); else pulse.stop()
  onDurationChanged:if(duration===0) pulse.stop()
  NumberAnimation {
    id:pulse
    target:root
    property:"pulseProgress"
    from:0
    to:1
    duration:root.duration
    easing.type:Easing.OutCubic
  }
}
