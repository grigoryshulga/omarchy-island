import QtQuick
import qs.Commons

// Shared dot field for progress displays and interactive slider tracks.
ShaderEffect {
  id: root
  property real value: 0
  property color accent: Design.accent
  property bool mirrored: LayoutMirroring.enabled
  // Internal charging-wave inputs; static consumers start no animation.
  property real phase: 1
  property real charging: 0
  readonly property vector2d size: Qt.vector2d(width, height)
  readonly property real amount: Math.max(0, Math.min(1, value))
  implicitWidth: Style.space(200)
  implicitHeight: Style.space(10)
  transform: Scale { origin.x: root.width / 2; xScale: root.mirrored ? -1 : 1 }
  vertexShader: Qt.resolvedUrl("shaders/battery-gauge.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/battery-gauge.frag.qsb")
}
