import QtQuick
import qs.Commons as Commons

// Applied only during a crossfade. Sample the live text/gauge into the same
// three-pixel dot field, then recover the original at either endpoint.
ShaderEffect {
  property var source
  property vector2d size: Qt.vector2d(width,height)
  property real amount: 0
  property color accent: Commons.Color.accent
  vertexShader: Qt.resolvedUrl("shaders/dissolve.vert.qsb")
  fragmentShader: Qt.resolvedUrl("shaders/dissolve.frag.qsb")
}
