import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "BatteryGaugeModel.js" as Model

Item {
  id:root
  objectName:"batteryGauge"
  property real fraction:0
  property bool charging:false
  property bool active:false
  // Urgency uses the same semantic role as every other Island warning.
  readonly property color lowChargeColor:Design.danger
  readonly property color accent:fraction<0.20 ? lowChargeColor : Design.accent
  readonly property bool animating:active && visible && charging && fraction<1 && !Preferences.reduceMotion
  property real pulse:1
  implicitHeight:Style.space(10)
  onAnimatingChanged:if(!animating) pulse=1

  SequentialAnimation on pulse {
    running:root.animating
    loops:Animation.Infinite
    NumberAnimation {from:1;to:0.45;duration:Preferences.duration(800);easing.type:Easing.InOutSine}
    NumberAnimation {from:0.45;to:1;duration:Preferences.duration(800);easing.type:Easing.InOutSine}
  }
  RowLayout {
    anchors.fill:parent
    spacing:Design.gap.tight
    layoutDirection:Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
    Repeater {
      model:20
      Rectangle {
        id:segment
        required property int index
        readonly property real fill:Model.segmentFill(root.fraction,index,20)
        objectName:"batterySegment-"+index
        Layout.fillWidth:true
        Layout.fillHeight:true
        radius:Math.min(Style.cornerRadius,Style.space(2))
        color:Qt.rgba(root.accent.r,root.accent.g,root.accent.b,0.12)
        Rectangle {
          objectName:"batterySegmentFill"
          anchors.top:parent.top
          anchors.bottom:parent.bottom
          x:Commons.I18n.rightToLeft ? parent.width-width : 0
          width:parent.width*segment.fill
          radius:parent.radius
          color:root.accent
          opacity:root.charging && segment.index===Model.leadingSegment(root.fraction,20) ? root.pulse : 1
        }
      }
    }
  }
}
