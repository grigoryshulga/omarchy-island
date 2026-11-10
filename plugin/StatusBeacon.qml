import QtQuick
import qs.Commons

Item {
  id:root
  property color tint:"#f7768e"
  property real waveWidth:Style.space(160)
  implicitWidth:Style.space(9)
  implicitHeight:Style.space(18)
  ToastWaves {
    anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter
    width:root.waveWidth;height:root.height
    active:root.visible
    accent:root.tint
    origin:Qt.vector2d(root.width/2,height/2)
    cornerRadius:0
    spacing:Style.space(65)
    bandWidth:Style.space(12)
    speed:Style.space(32)
  }
  Rectangle {anchors.centerIn:parent;width:parent.width;height:width;radius:width/2;color:root.tint}
}
