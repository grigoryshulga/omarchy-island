import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import "Security.js" as Security

ColumnLayout {
  id:root
  required property var strings
  required property var subscriptions
  spacing:Design.gap.medium
  function focusEditor() {name.forceActiveFocus()}
  RowLayout {
    Layout.fillWidth:true
    SectionHeading {Layout.fillWidth:true;title:root.strings.t("ics.sources");detail:Commons.I18n.formatNumber((root.subscriptions ? root.subscriptions.sources.length : 0))+" / "+Commons.I18n.formatNumber(6)}
    T3Spinner {visible:(!!root.subscriptions && root.subscriptions.busy);active:visible}
    FeedbackButton {objectName:"calendarRefresh";text:root.strings.t("ics.refresh");focusable:true;enabled:!(!!root.subscriptions && root.subscriptions.busy) && (!!root.subscriptions && root.subscriptions.hasEnabled);onClicked:root.subscriptions.refresh(true)}
  }
  PlainText {Layout.fillWidth:true;text:root.strings.t("ics.explanation");typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap}
  Repeater {
    model:root.subscriptions ? root.subscriptions.sources : []
    Surface {
      required property var modelData
      Layout.fillWidth:true
      implicitHeight:sourceRow.implicitHeight+Design.gap.medium*2
      RowLayout {
        id:sourceRow;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:Design.gap.medium;spacing:Design.gap.small
        ColumnLayout {
          Layout.fillWidth:true;Layout.minimumWidth:0;spacing:Design.gap.tight
          PlainText {Layout.fillWidth:true;text:modelData.name;typeRole:"title";wrapMode:Text.Wrap}
          PlainText {
            Layout.fillWidth:true;wrapMode:Text.Wrap;typeRole:"caption";color:modelData.error ? Design.danger : Design.secondaryText
            text:!modelData.enabled ? root.strings.t("ics.disabled") : modelData.error ? root.strings.t("ics.error."+modelData.error)+(modelData.fetchedAt ? " · "+root.strings.t("ics.cached") : "") : modelData.fetchedAt ? root.strings.t("ics.updated").arg(new Date(modelData.fetchedAt*1000).toLocaleString(Qt.locale(Commons.I18n.formatLocale),"d MMM HH:mm")) : root.strings.t("ics.pending")
          }
        }
        FeedbackButton {objectName:"calendarSourceToggle-"+modelData.id;text:root.strings.t(modelData.enabled ? "ics.disable" : "ics.enable");compact:true;focusable:true;enabled:!(!!root.subscriptions && root.subscriptions.busy);onClicked:root.subscriptions.toggle(modelData.id,!modelData.enabled)}
        FeedbackButton {objectName:"calendarSourceRemove-"+modelData.id;iconText:"󰅖";tooltipText:root.strings.t("ics.remove");compact:true;focusable:true;enabled:!(!!root.subscriptions && root.subscriptions.busy);onClicked:root.subscriptions.remove(modelData.id)}
      }
    }
  }
  ColumnLayout {
    Layout.fillWidth:true;spacing:Design.gap.small
    visible:(root.subscriptions ? root.subscriptions.sources.length : 0)<6
    DesignTextField {id:name;objectName:"calendarSourceName";Layout.fillWidth:true;placeholderText:root.strings.t("ics.name");Accessible.name:placeholderText;maximumLength:128;onAccepted:url.forceActiveFocus()}
    DesignTextField {id:url;objectName:"calendarSourceUrl";Layout.fillWidth:true;placeholderText:root.strings.t("ics.url");Accessible.name:placeholderText;maximumLength:4096;echoMode:TextInput.PasswordEchoOnEdit;onAccepted:if(add.enabled) add.clicked()}
    RowLayout {
      Layout.fillWidth:true
      PlainText {Layout.fillWidth:true;text:root.strings.t("ics.private");wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText}
      FeedbackButton {id:add;objectName:"calendarSourceAdd";text:root.strings.t("ics.add");variant:"primary";focusable:true;enabled:!(!!root.subscriptions && root.subscriptions.busy) && !!name.text.trim() && !!Security.calendarUrl(url.text.trim());onClicked:root.subscriptions.add(name.text.trim(),url.text.trim())}
    }
  }
  PlainText {visible:!!root.subscriptions && !!root.subscriptions.error;Layout.fillWidth:true;text:root.subscriptions && root.subscriptions.error ? root.strings.t("ics.error."+root.subscriptions.error) : "";color:Design.danger;typeRole:"caption";wrapMode:Text.Wrap}
  Connections {target:root.subscriptions;function onSaved(){name.text="";url.text=""}}
}
