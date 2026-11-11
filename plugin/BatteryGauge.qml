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
  // Keep low charge visibly red even in themes whose urgent role is monochrome.
  readonly property color lowChargeColor:Qt.hsla(0,Math.max(0.65,Commons.Color.urgent.hslSaturation),Math.max(0.55,Math.min(0.7,Commons.Color.urgent.hslLightness)),1)
  readonly property color accent:fraction<0.20 ? lowChargeColor : Commons.Color.accent
  readonly property bool animating:active && visible && charging && fraction<1 && !Style.reduceMotion
  property real pulse:1
  implicitHeight:Style.space(10)
  onAnimatingChanged:if(!animating) pulse=1

  SequentialAnimation on pulse {
    running:root.animating
    loops:Animation.Infinite
    NumberAnimation {from:1;to:0.45;duration:Style.duration(800);easing.type:Easing.InOutSine}
    NumberAnimation {from:0.45;to:1;duration:Style.duration(800);easing.type:Easing.InOutSine}
  }
  RowLayout {
    anchors.fill:parent
    spacing:Style.space(3)
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
