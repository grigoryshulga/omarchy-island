import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
  id:root
  objectName:"batteryGauge"
  property real fraction:0
  property real warningThreshold:0.20
  property bool charging:false
  property bool active:false
  // Urgency uses the same semantic role as every other Island warning.
  readonly property color lowChargeColor:Design.danger
  readonly property color accent:fraction<warningThreshold ? lowChargeColor : Design.accent
  readonly property bool animating:active && visible && charging && fraction<1 && !Preferences.reduceMotion
  property real pulse:1
  implicitHeight:Style.space(10)
  onAnimatingChanged:if(!animating) pulse=1

  NumberAnimation on pulse {
    running:root.animating
    loops:Animation.Infinite
    from:0;to:1;duration:Preferences.duration(1800)
  }
  ShaderEffect {
    objectName:"batteryBrailleProgress"
    anchors.fill:parent
    property vector2d size:Qt.vector2d(width,height)
    property real amount:Math.max(0,Math.min(1,root.fraction))
    property color accent:root.accent
    property real phase:root.pulse
    property real charging:root.animating ? 1 : 0
    transform:Scale {origin.x:root.width/2; xScale:Commons.I18n.rightToLeft ? -1 : 1}
    vertexShader:Qt.resolvedUrl("shaders/battery-gauge.vert.qsb")
    fragmentShader:Qt.resolvedUrl("shaders/battery-gauge.frag.qsb")
  }
}
