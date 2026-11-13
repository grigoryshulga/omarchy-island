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
  BrailleProgress {
    objectName:"batteryBrailleProgress"
    anchors.fill:parent
    value:root.fraction
    accent:root.accent
    phase:root.pulse
    charging:root.animating ? 1 : 0
    mirrored:Commons.I18n.rightToLeft
  }
}
