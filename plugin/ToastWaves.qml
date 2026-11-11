import QtQuick
import qs.Commons
import qs.Commons as Commons

ShaderEffect {
  id: root
  property bool active: false
  property vector2d size: Qt.vector2d(width,height)
  property real phase: 0
  property vector2d intensity: Qt.vector2d(1.0,0.35)
  property vector2d fadeMargins: Qt.vector2d(Style.space(24),Style.space(10))
  property vector2d origin: Qt.vector2d(-18,height/2)
  property real spacing: Style.space(90)
  property real bandWidth: Style.space(21)
  property real speed: Style.space(55)
  property real cornerRadius: Style.cornerRadius
  property color accent: Commons.Color.accent
  visible: active
  vertexShader: Qt.resolvedUrl("shaders/toast-waves.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/toast-waves.frag.qsb")
  NumberAnimation on phase {
    running: root.visible && !Preferences.reduceMotion
    from: 0; to: 7200; duration: 7200000; loops: Animation.Infinite
  }
}
