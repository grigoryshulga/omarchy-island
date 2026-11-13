import QtQuick
import QtQuick.Layouts
import "sdk" 1.0 as UI
import qs.Commons

Column {
  id:root
  required property var backend
  required property var strings
  property var feedback:null
  property string editingId:""
  property string secretDraft:""
  readonly property bool secretDraftValid:/^[A-Za-z_][A-Za-z0-9_.-]{0,99}$/.test(secretDraft)
  property string regionDraft:"global"
  spacing:Design.gap.small
  PlainText {width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText;text:root.strings.t("limits.provider.description")}
  Repeater {
    model:root.backend ? root.backend.catalog : []
    Surface {
      id:card
      required property var modelData
      required property int index
      width:root.width;implicitHeight:body.implicitHeight+2*Design.gap.large
      ColumnLayout {
        id:body;x:Design.gap.large;y:Design.gap.large;width:parent.width-2*Design.gap.large;spacing:Design.gap.small
        PlainText {Layout.fillWidth:true;typeRole:"title";text:card.modelData.name;elide:Text.ElideRight}
        PlainText {Layout.fillWidth:true;typeRole:"caption";wrapMode:Text.Wrap;color:Design.secondaryText;text:root.strings.t("limits.provider.connect."+card.modelData.id)}
        RowLayout {
          Layout.fillWidth:true
          FeedbackButton {
            Layout.fillWidth:true
            text:root.strings.t(card.modelData.enabled ? "limits.provider.disable" : "limits.provider.enable")
            selected:card.modelData.enabled;focusable:true;compact:true;enabled:root.backend && !root.backend.busy
            onClicked:root.backend.change(card.modelData.id,card.modelData.enabled ? "disable" : "enable","","global")
          }
          FeedbackButton {
            objectName:"agentProviderConnect-"+card.modelData.id;text:"󰒓";tooltipText:root.strings.t("limits.provider.connection");focusable:true;compact:true
            visible:!!card.modelData.secretName;enabled:root.backend && !root.backend.busy
            onClicked:{root.editingId=card.modelData.id;root.secretDraft=card.modelData.secretName;root.regionDraft=card.modelData.region}
          }
          FeedbackButton {text:"↑";tooltipText:root.strings.t("limits.moveUp");focusable:true;compact:true;enabled:card.index>0 && root.backend && !root.backend.busy;onClicked:root.backend.change(card.modelData.id,"up","","global")}
          FeedbackButton {text:"↓";tooltipText:root.strings.t("limits.moveDown");focusable:true;compact:true;enabled:root.backend && card.index<root.backend.catalog.length-1 && !root.backend.busy;onClicked:root.backend.change(card.modelData.id,"down","","global")}
        }
        ColumnLayout {
          visible:root.editingId===card.modelData.id
          Layout.fillWidth:true;spacing:Design.gap.small
          UI.FormField {
            id:secretField;objectName:"agentSecretField-"+card.modelData.id;Layout.fillWidth:true
            label:root.strings.t("limits.provider.secretLabel");hint:root.strings.t("limits.provider.secretHelp")
            error:root.secretDraft && !root.secretDraftValid ? root.strings.t("limits.provider.secretInvalid") : ""
            DesignTextField {objectName:"agentSecret-"+card.modelData.id;Layout.fillWidth:true;maximumLength:100;Accessible.name:secretField.label;Accessible.description:secretField.message;invalid:!!secretField.error;text:root.secretDraft;enabled:root.backend && !root.backend.busy;onTextEdited:root.secretDraft=text}
          }
          RowLayout {
            Layout.fillWidth:true
            visible:["zai","moonshot","kimi-code","minimax"].indexOf(card.modelData.id)>=0
            FeedbackButton {Layout.fillWidth:true;text:root.strings.t("limits.provider.global");selected:root.regionDraft==="global";focusable:true;onClicked:root.regionDraft="global"}
            FeedbackButton {Layout.fillWidth:true;text:root.strings.t("limits.provider.china");selected:root.regionDraft==="cn";focusable:true;onClicked:root.regionDraft="cn"}
          }
          RowLayout {
            Layout.fillWidth:true
            FeedbackButton {objectName:"agentProviderSave-"+card.modelData.id;Layout.fillWidth:true;text:root.strings.t("limits.provider.save");focusable:true;enabled:root.backend && !root.backend.busy && root.secretDraftValid;onClicked:{root.backend.change(card.modelData.id,"connect",root.secretDraft,root.regionDraft);root.editingId=""}}
            FeedbackButton {text:root.strings.t("limits.provider.cancel");focusable:true;onClicked:root.editingId=""}
          }
        }
      }
    }
  }
}
