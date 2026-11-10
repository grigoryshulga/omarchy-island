import QtQuick
import qs.Commons
import qs.Commons as Commons

ShaderEffect {
  id: root
  property real condition: 0
  property bool isDay: true
  property bool animated: true
  property vector2d size: Qt.vector2d(width,height)
  property real phase: 0
  property real night: isDay ? 0 : 1
  property color accent: Commons.Color.accent
  property color foreground: Commons.Color.foreground
  property color muted: Commons.Color.muted
  vertexShader: Qt.resolvedUrl("shaders/weather.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/weather.frag.qsb")
  NumberAnimation on phase {
    running: root.visible && root.animated && !Style.reduceMotion
    from: 0; to: 7200; duration: 7200000; loops: Animation.Infinite
  }
}
