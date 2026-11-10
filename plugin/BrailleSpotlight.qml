import QtQuick
import qs.Commons
import qs.Commons as Commons

ShaderEffect {
  id: root
  property bool active: false
  property bool adaptive: true
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
  property real hoverOpacity: shown
  property real rippleProgress: 1
  readonly property bool rippling: rippleProgress < 1
  visible: shown > 0 || rippling
  vertexShader: Qt.resolvedUrl("shaders/spotlight.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/spotlight.frag.qsb")
  function pulse(point) {
    if (Style.reduceMotion) return
    rippleOrigin=point
    rippleProgress=0
    wave.restart()
  }
  Behavior on shown { NumberAnimation { duration: Style.duration(root.active ? 160 : 120); easing.type: Easing.OutCubic } }
  NumberAnimation on phase { running: root.visible && !Style.reduceMotion; from: 0; to: 1200; duration: 1200000; loops: Animation.Infinite }
  // A time cursor lets travel and brightness ease independently in the shader.
  NumberAnimation { id: wave; target: root; property: "rippleProgress"; from: 0; to: 1; duration: Style.duration(520); easing.type: Easing.Linear }
}
