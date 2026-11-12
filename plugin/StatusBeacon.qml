import QtQuick
import qs.Commons

Item {
  id:root
  property color tint:Design.barDanger
  property bool bidirectional:false
  property real waveOffset:0
  property string glyph:""
  property real waveWidth:Style.space(160)
  implicitWidth:glyph ? Style.space(16) : Style.space(7)
  implicitHeight:Style.space(18)
  ToastWaves {
    x:root.bidirectional ? root.waveOffset : 0
    anchors.verticalCenter:parent.verticalCenter
    width:root.waveWidth;height:root.height
    active:root.visible && root.waveWidth>0 && Preferences.get("panelAnimation")
    accent:root.tint
    intensity:root.bidirectional ? Qt.vector2d(0.85,0.85) : Qt.vector2d(1.45,0.08)
    origin:Qt.vector2d(root.width/2-x,height/2)
    cornerRadius:0
    fadeMargins:Qt.vector2d(Math.min(width*0.15,Style.space(32)),height*0.48)
    spacing:Style.space(100)
    bandWidth:Style.space(22)
    speed:Style.space(20)
  }
  PlainText {anchors.centerIn:parent;visible:root.glyph!=="";text:root.glyph;color:root.tint;font.pixelSize:Math.round(Style.font.icon*0.85)}
  Rectangle {visible:root.glyph==="";anchors.centerIn:parent;width:parent.width;height:width;radius:width/2;color:root.tint}
}
