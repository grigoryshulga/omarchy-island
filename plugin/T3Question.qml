import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T3Model.js" as T3

ColumnLayout {
  id:root
  required property var question
  required property var strings
  property var feedback:null
  property var selected:[]
  property string requestKey:""
  onRequestKeyChanged:{selected=[];custom.text=""}
  readonly property var answer:T3.answer(question,selected,custom.text)
  readonly property bool valid:T3.valid(question,answer)
  spacing:Style.space(6)
  PlainText {Layout.fillWidth:true;text:root.question.text;wrapMode:Text.Wrap;font.pixelSize:Style.font.bodySmall}
  Repeater {
    model:root.question.options
    ColumnLayout {
      required property var modelData
      required property int index
      Layout.fillWidth:true
      spacing:Style.space(2)
      FeedbackButton {
        objectName:"t3Option-"+root.question.id+"-"+index
        Layout.fillWidth:true
        text:modelData.label;tooltipText:modelData.label
        leftAlign:true;bordered:true;focusable:true
        selected:root.selected.indexOf(modelData.value)>=0 && (root.question.multiSelect || !custom.text.trim())
        feedback:root.feedback
        onClicked:{root.selected=T3.toggle(root.selected,modelData.value,root.question.multiSelect);if(!root.question.multiSelect) custom.text=""}
      }
      PlainText {Layout.fillWidth:true;visible:text!=="";text:modelData.description;wrapMode:Text.Wrap;color:Commons.Color.muted;font.pixelSize:Style.font.caption}
    }
  }
  TextField {
    id:custom
    objectName:"t3Answer-"+root.question.id
    Layout.fillWidth:true
    visible:root.question.allowCustomAnswer
    activeFocusOnTab:true;maximumLength:4096
    placeholderText:root.strings.t(root.question.options.length ? "t3.customAnswer" : "t3.answer")
    onTextEdited:if(!root.question.multiSelect && text.trim()) root.selected=[]
  }
}
