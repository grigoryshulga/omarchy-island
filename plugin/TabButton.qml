import QtQuick
import qs.Commons
import qs.Commons as Commons

FeedbackButton {
  id:root
  property string label:""
  property bool tabActive:false
  // Flow uses the button's natural width; the inherited Button.text is empty
  // because this component paints its own label.
  implicitWidth:Math.ceil(tabLabel.implicitWidth)+Style.space(24)
  implicitHeight:Design.controlHeight
  selected:tabActive
  PlainText {
    id:tabLabel
    objectName:"tabLabel"
    anchors.centerIn:parent
    width:Math.max(0,parent.width-Style.space(12))
    text:root.label
    horizontalAlignment:Text.AlignHCenter
    font.pixelSize:root.fontSize
    font.weight:root.tabActive ? Font.DemiBold : Font.Medium
    color:root.tabActive ? Design.selectedText : Design.text
  }
}
