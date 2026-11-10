import QtQuick
import qs.Commons

Item {
  id:root
  property color tint:"#f7768e"
  property real waveWidth:Style.space(160)
  implicitWidth:Style.space(7)
  implicitHeight:Style.space(18)
  ToastWaves {
    anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter
    width:root.waveWidth;height:root.height
    active:root.visible
    accent:root.tint
    intensity:Qt.vector2d(1.45,0.08)
    origin:Qt.vector2d(root.width/2,height/2)
    cornerRadius:0
    fadeMargins:Qt.vector2d(Math.min(width*0.15,Style.space(32)),height*0.48)
    spacing:Style.space(100)
    bandWidth:Style.space(22)
    speed:Style.space(20)
  }
  Rectangle {anchors.centerIn:parent;width:parent.width;height:width;radius:width/2;color:root.tint}
}
