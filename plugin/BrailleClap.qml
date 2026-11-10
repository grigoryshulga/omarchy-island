import QtQuick
import qs.Commons
import qs.Commons as Commons

ShaderEffect {
  id: root
  property bool active: true
  property vector2d size: Qt.vector2d(width,height)
  property real phase: 0
  readonly property real motionPhase: Style.reduceMotion ? 0 : phase
  property color accent: Commons.Color.accent
  property var source: atlas
  vertexShader: Qt.resolvedUrl("shaders/clap.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/clap.frag.qsb")
  Image {
    id: atlas
    source: Qt.resolvedUrl("assets/clap-atlas.png")
    visible: false
    smooth: true
  }
  NumberAnimation on phase {
    running: root.visible && root.active && !Style.reduceMotion
    from: 0; to: 1; duration: 960; loops: Animation.Infinite
  }
}
