import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons as Commons
import "Security.js" as Security
import "ReminderModel.js" as Model

ColumnLayout {
  id:root
  required property var strings
  property var reminders:null
  property bool editing:false
  property string selectedKey:""
  spacing:Design.gap.small
  RowLayout {
    Layout.fillWidth:true
    SectionHeading {Layout.fillWidth:true;title:root.strings.t("reminders.title");detail:root.reminders && root.reminders.count ? Commons.I18n.formatNumber(root.reminders.count) : ""}
    FeedbackButton {objectName:"reminderAdd";text:root.strings.t("reminders.add");compact:true;focusable:true;onClicked:{root.editing=!root.editing;if(root.editing) minutes.forceActiveFocus()}}
    FeedbackButton {objectName:"reminderClear";visible:root.reminders && root.reminders.count>0;text:root.strings.t("reminders.clear");compact:true;focusable:true;enabled:!!root.reminders && !root.reminders.busy;onClicked:root.reminders.clear()}
  }
  ColumnLayout {
    Layout.fillWidth:true;visible:root.editing;spacing:Design.gap.small
    RowLayout {
      Layout.fillWidth:true
      DesignTextField {id:minutes;objectName:"reminderMinutes";Layout.preferredWidth:Design.fieldHeight*2;placeholderText:root.strings.t("reminders.minutes");validator:IntValidator {bottom:1;top:2147483647} maximumLength:10;Accessible.name:placeholderText;onAccepted:message.forceActiveFocus()}
      DesignTextField {id:message;objectName:"reminderMessage";Layout.fillWidth:true;Layout.minimumWidth:0;placeholderText:root.strings.t("reminders.message");maximumLength:4096;Accessible.name:placeholderText;onAccepted:if(save.enabled) save.clicked()}
    }
    RowLayout {
      Layout.fillWidth:true
      PlainText {Layout.fillWidth:true;typeRole:"caption";color:Design.secondaryText;text:root.strings.t("reminders.relative");wrapMode:Text.Wrap}
      FeedbackButton {id:save;objectName:"reminderSave";text:root.strings.t("reminders.save");variant:"primary";focusable:true;enabled:!!root.reminders && !root.reminders.busy && Security.reminderArgs(minutes.text,message.text).length>0;onClicked:root.reminders.create(minutes.text,message.text)}
    }
  }
  Connections {target:root.reminders;ignoreUnknownSignals:true;function onCreated(){root.editing=false;minutes.text="";message.text=""}}
  Controls.ScrollView {
    id:reminderScroll
    Layout.fillWidth:true
    implicitHeight:Math.min(list.implicitHeight,Design.fieldHeight*3)
    visible:!!root.reminders && root.reminders.count>0
    clip:true;contentWidth:availableWidth
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Column {
      id:list;width:reminderScroll.availableWidth;spacing:Design.gap.small
      Repeater {
        model:root.reminders ? root.reminders.rows : []
        Surface {
          id:reminderRow
          required property var modelData
          readonly property bool selected:Model.dayKey(modelData.at)===root.selectedKey
          width:list.width;implicitHeight:row.implicitHeight+Design.gap.medium*2
          color:selected ? Design.selection : Design.surface
          RowLayout {
            id:row;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:Design.gap.medium;spacing:Design.gap.medium
            ColumnLayout {
              Layout.fillWidth:true;Layout.minimumWidth:0;spacing:Design.gap.tight
              PlainText {Layout.fillWidth:true;text:modelData.label;typeRole:"title";wrapMode:Text.Wrap;color:reminderRow.selected ? Design.selectedText : Design.text}
              PlainText {text:new Date(modelData.at*1000).toLocaleString(Qt.locale(Commons.I18n.formatLocale),"d MMM HH:mm");typeRole:"caption";color:reminderRow.selected ? Design.selectedSecondaryText : Design.secondaryText}
            }
            PlainText {text:Model.remaining(modelData.at,root.reminders.now,Commons.I18n.formatNumber);typeRole:"caption";color:reminderRow.selected ? Design.selectedSecondaryText : Design.secondaryText}
          }
        }
      }
    }
  }
  PlainText {visible:!!root.reminders && root.reminders.count===0 && !root.editing;Layout.fillWidth:true;text:root.strings.t("reminders.empty");typeRole:"caption";color:Design.secondaryText}
  PlainText {visible:!!root.reminders && root.reminders.error!=="";Layout.fillWidth:true;text:root.reminders && root.reminders.error ? root.strings.t(root.reminders.error) : "";color:Design.danger;typeRole:"caption";wrapMode:Text.Wrap}
}
