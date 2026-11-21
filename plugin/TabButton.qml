import QtQuick
import qs.Commons
import qs.Commons as Commons

FeedbackButton {
  id:root
  property string label:""
  property bool tabActive:false
  property real trailingInset:0
  readonly property real leadingInset:iconText ? iconSize+Design.gap.large : 0
  // Flow uses the button's natural width; the inherited Button.text is empty
  // because this component paints its own label.
  implicitWidth:Math.ceil(tabLabel.implicitWidth)+Style.space(24)
  implicitHeight:Design.controlHeight
  Accessible.name: label
  Accessible.role: Accessible.PageTab
  Accessible.selectable: true
  Accessible.selected: tabActive
  selected:tabActive
  PlainText {
    id:tabLabel
    objectName:"tabLabel"
    anchors.centerIn:parent
    anchors.horizontalCenterOffset:(root.leadingInset-root.trailingInset)/2*(Commons.I18n.rightToLeft ? -1 : 1)
    width:Math.max(0,parent.width-Style.space(12)-root.trailingInset-root.leadingInset)
    elide:Text.ElideRight
    text:root.label
    horizontalAlignment:root.leftAlign ? (Commons.I18n.rightToLeft ? Text.AlignRight : Text.AlignLeft) : Text.AlignHCenter
    font.pixelSize:root.fontSize
    font.weight:root.tabActive ? Font.DemiBold : Font.Medium
    color:root.tabActive ? Design.selectedText : Design.text
  }
}
