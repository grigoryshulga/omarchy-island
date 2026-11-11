import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
  id:root
  property bool active:true
  property color tint:Design.accent
  readonly property bool animating:active && visible && !Preferences.reduceMotion
  implicitWidth:Style.space(16)
  implicitHeight:implicitWidth
  onAnimatingChanged:if(!animating && wheel) wheel.rotation=0
  Item {
    id:wheel
    objectName:"t3SpinnerWheel"
    anchors.fill:parent
    Repeater {
      model:12
      Rectangle {
        required property int index
        width:Math.max(1,root.width/9);height:root.height/4
        x:(root.width-width)/2;y:0
        radius:width/2;color:root.tint;opacity:0.15+index*0.077
        transform:Rotation {origin.x:root.width/18;origin.y:root.height/2;angle:index*30}
      }
    }
    RotationAnimation on rotation {from:0;to:360;duration:Design.spinnerDuration;loops:Animation.Infinite;running:root.animating}
  }
}
