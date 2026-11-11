import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "T3Model.js" as T3

ColumnLayout {
  id:root
  required property var question
  required property var strings
  property var feedback:null
  property var selected:[]
  property bool customOpen:false
  property bool showSubmit:false
  property bool submitEnabled:false
  property bool submitting:false
  property string requestKey:""
  signal submitRequested()
  onRequestKeyChanged:{selected=[];custom.text="";customOpen=false}
  readonly property var answer:T3.answer(question,selected,custom.text)
  readonly property bool valid:T3.valid(question,answer)
  spacing:Design.gap.medium
  PlainText {Layout.fillWidth:true;text:root.question.text;wrapMode:Text.Wrap;typeRole:"body";font.weight:Font.Medium}
  GridLayout {
    id:choices
    objectName:"t3Options-"+root.question.id
    Layout.fillWidth:true
    columns:root.width>=Style.space(380) && root.question.options.length>1 ? 2 : 1
    columnSpacing:Design.gap.medium;rowSpacing:Design.gap.small
    Repeater {
      model:root.question.options
      T3Option {
        required property var modelData
        required property int index
        objectName:"t3Option-"+root.question.id+"-"+index
        Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumWidth:0
        Layout.columnSpan:index===root.question.options.length-1 && root.question.options.length%2 ? choices.columns : 1
        Layout.preferredWidth:1
        option:modelData;multiSelect:root.question.multiSelect
        selected:root.selected.indexOf(modelData.value)>=0 && (root.question.multiSelect || !custom.text.trim())
        feedback:root.feedback
        onClicked:{root.selected=T3.toggle(root.selected,modelData.value,root.question.multiSelect);if(!root.question.multiSelect) {custom.text="";root.customOpen=false}}
      }
    }
  }
  RowLayout {
    objectName:"t3AnswerActions-"+root.question.id
    Layout.fillWidth:true
    visible:root.question.allowCustomAnswer || root.showSubmit
    spacing:Design.gap.medium
    FeedbackButton {
      objectName:"t3Custom-"+root.question.id
      visible:root.question.allowCustomAnswer && root.question.options.length>0 && !root.customOpen
      text:root.strings.t("t3.custom");iconText:"+"
      fontSize:Design.type.label
      horizontalPadding:Design.gap.tight;verticalPadding:Design.gap.small
      focusable:true;feedback:root.feedback
      onClicked:{root.customOpen=true;custom.forceActiveFocus()}
    }
    DesignTextField {
      id:custom
      objectName:"t3Answer-"+root.question.id
      Layout.fillWidth:true;Layout.minimumWidth:0
      visible:root.question.allowCustomAnswer && (root.customOpen || !root.question.options.length)
      activeFocusOnTab:true;maximumLength:4096
      placeholderText:root.strings.t("t3.answer")
      onTextEdited:if(!root.question.multiSelect && text.trim()) root.selected=[]
    }
    Item {Layout.fillWidth:true;visible:!custom.visible}
    FeedbackButton {
      objectName:root.showSubmit ? "t3Submit" : ""
      visible:root.showSubmit
      text:root.strings.t(root.submitting ? "t3.response.sending" : "t3.send")
      fontSize:Design.type.label;verticalPadding:Design.gap.small
      focusable:true;variant:"primary";feedback:root.feedback
      enabled:root.submitEnabled
      onClicked:root.submitRequested()
    }
  }
}
