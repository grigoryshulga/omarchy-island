import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

FeedbackButton {
  id:root
  required property string label
  property string description: ""
  property bool multiSelect:false
  readonly property color textColor:selected ? Design.selectedText : Design.text
  text:"";focusable:true
  variant:"soft"
  bordered:selected
  horizontalPadding:Design.gap.medium;verticalPadding:Design.gap.medium
  implicitWidth:Style.space(160)
  implicitHeight:Math.max(Design.optionHeight,content.implicitHeight+2*verticalPadding)
  Accessible.name:label
  Accessible.description:description
  Accessible.role:multiSelect ? Accessible.CheckBox : Accessible.RadioButton
  Accessible.checked:selected
  RowLayout {
    id:content
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.leftMargin:root.horizontalPadding;anchors.rightMargin:root.horizontalPadding
    anchors.topMargin:root.verticalPadding
    spacing:Design.gap.medium
    PlainText {
      Layout.alignment:Qt.AlignTop
      text:root.multiSelect ? (root.selected ? "☑" : "☐") : (root.selected ? "●" : "○")
      color:root.selected ? root.textColor : Design.secondaryText;typeRole:"caption"
    }
    ColumnLayout {
      Layout.fillWidth:true;Layout.minimumWidth:0;spacing:Design.gap.small
      PlainText {
        objectName:"choiceLabel"
        Layout.fillWidth:true;Layout.minimumWidth:0
        text:root.label;wrapMode:Text.Wrap;elide:Text.ElideNone
        typeRole:"body";font.weight:root.selected ? Font.DemiBold : Font.Medium
        color:root.textColor
      }
      PlainText {
        objectName:"choiceDescription"
        Layout.fillWidth:true;Layout.minimumWidth:0
        visible:text!=="";text:root.description
        wrapMode:Text.Wrap;elide:Text.ElideNone;typeRole:"caption";color:root.selected ? Design.selectedSecondaryText : Design.secondaryText
      }
    }
  }
}
