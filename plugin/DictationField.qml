import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Dictation.js" as Model

Item {
  id:root
  property var history:Model.empty()
  property bool processing:false
  property bool active:false
  property real morph:processing ? 1 : 0
  property real phase:0
  Behavior on morph {NumberAnimation {duration:Preferences.duration(320);easing.type:Easing.InOutCubic}}
  NumberAnimation on phase {
    running:root.active && root.processing && !Preferences.reduceMotion
    from:0;to:86400;duration:86400000;loops:Animation.Infinite
  }
  // Each column is a tiny shader: the same three-pixel pitch as our gauges
  // and dissolve, with a quiet dot floor and brighter speech-shaped ink.
  Row {
    anchors.fill:parent
    Repeater {
      model:48
      Item {
        required property int index
        width:root.width/48;height:root.height
        readonly property real amplitude:Preferences.reduceMotion ? 0.35 : Math.min(1,Math.sqrt(root.history[index] || 0)*2.4)
        ShaderEffect {
          anchors.fill:parent
          visible:GraphicsInfo.api!==GraphicsInfo.Software
          property vector2d size:Qt.vector2d(width,height)
          property real amplitude:parent.amplitude
          property real morph:root.morph
          property real phase:root.phase
          property real column:parent.index/47
          property color accent:Commons.Color.accent
          vertexShader:Qt.resolvedUrl("shaders/dictation.vert.qsb")
          fragmentShader:Qt.resolvedUrl("shaders/dictation.frag.qsb")
        }
        // The software renderer cannot execute ShaderEffect.
        Rectangle {
          visible:GraphicsInfo.api===GraphicsInfo.Software
          anchors.centerIn:parent
          width:Math.max(1,parent.width-2)
          height:Math.max(2,parent.height*parent.amplitude*(1-root.morph))
          radius:width/2;color:Commons.Color.accent
        }
      }
    }
  }
}
