import QtQuick
import qs.Commons
import qs.Commons as Commons

FeedbackButton {
  id:root
  property string label:""
  property bool tabActive:false
  implicitHeight:Style.space(30)
  PlainText {
    objectName:"tabLabel"
    anchors.centerIn:parent
    width:Math.max(0,parent.width-Style.space(12))
    text:root.label
    horizontalAlignment:Text.AlignHCenter
    font.pixelSize:root.fontSize
    font.bold:root.tabActive
    color:root.tabActive ? Commons.Color.accent : Commons.Color.foreground
  }
}
