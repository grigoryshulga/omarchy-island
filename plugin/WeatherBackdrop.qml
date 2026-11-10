import QtQuick
import qs.Commons

ShaderEffect {
  id: root
  property real solarHour: 12
  property bool animated: true
  property vector2d size: Qt.vector2d(width,height)
  property real phase: 0
  vertexShader: Qt.resolvedUrl("shaders/weather-backdrop.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/weather-backdrop.frag.qsb")
  NumberAnimation on phase {
    running: root.visible && root.animated && !Style.reduceMotion
    from: 0; to: 7200; duration: 7200000; loops: Animation.Infinite
  }
}
