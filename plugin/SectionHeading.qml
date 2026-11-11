import QtQuick
import QtQuick.Layouts

RowLayout {
  property string title: ""
  property string detail: ""
  spacing: Design.gap.small
  PlainText {text:parent.title;typeRole:"section";Layout.fillWidth:true}
  PlainText {text:parent.detail;typeRole:"caption";color:Design.secondaryText;visible:text!==""}
}
