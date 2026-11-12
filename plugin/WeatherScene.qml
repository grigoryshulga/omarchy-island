import QtQuick
import qs.Commons

ShaderEffect {
  id: root
  property real condition: 0
  property bool isDay: true
  property bool animated: true
  property vector2d size: Qt.vector2d(width,height)
  property real phase: 0
  property real night: isDay ? 0 : 1
  property color accent: Design.accent
  property color foreground: Design.text
  property color muted: Design.secondaryText
  vertexShader: Qt.resolvedUrl("shaders/weather.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/weather.frag.qsb")
  NumberAnimation on phase {
    running: root.visible && root.animated && !Preferences.reduceMotion
    from: 0; to: 7200; duration: 7200000; loops: Animation.Infinite
  }
}
