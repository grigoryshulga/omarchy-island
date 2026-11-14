import QtQuick
import QtQuick.Layouts
import qs.Commons

// A module heading is the navigation target; action buttons stay separate.
FeedbackButton {
  id:root
  property string title:""
  property string detail:""
  focusable:true
  compact:true
  horizontalPadding:0
  tooltipText:title
  Accessible.name:title
  borderSpec:Border.none()
  color:hot ? Design.hover : "transparent"
  Rectangle {
    objectName:"sectionFocusUnderline"
    anchors.left:parent.left;anchors.bottom:parent.bottom
    width:Math.min(titleLabel.paintedWidth,titleLabel.width)
    height:Math.max(1,Style.space(1));color:Design.focusRing
    visible:root.activeFocus
  }
  implicitWidth:heading.implicitWidth
  implicitHeight:Math.max(Design.compactControlHeight,heading.implicitHeight)
  RowLayout {
    id:heading
    anchors.fill:parent
    spacing:Design.gap.small
    PlainText {id:titleLabel;Layout.fillWidth:true;text:root.title;color:root.activeFocus ? Design.accent : Design.text;typeRole:"section";elide:Text.ElideRight}
    PlainText {text:root.detail;typeRole:"caption";color:Design.secondaryText;visible:text!==""}
  }
}
