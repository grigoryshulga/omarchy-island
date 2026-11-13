import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import "sdk" 1.0 as UI
import "Security.js" as Security

ColumnLayout {
  id:root
  required property var strings
  required property var subscriptions
  spacing:Design.gap.medium
  function focusEditor() {name.forceActiveFocus()}
  RowLayout {
    Layout.fillWidth:true
    SectionHeading {Layout.fillWidth:true;title:root.strings.t("ics.sourceList");detail:Commons.I18n.formatNumber((root.subscriptions ? root.subscriptions.sources.length : 0))+" / "+Commons.I18n.formatNumber(6)}
    T3Spinner {visible:(!!root.subscriptions && root.subscriptions.busy);active:visible}
    FeedbackButton {objectName:"calendarRefresh";text:root.strings.t("ics.refresh");focusable:true;enabled:!(!!root.subscriptions && root.subscriptions.busy) && (!!root.subscriptions && root.subscriptions.hasEnabled);onClicked:root.subscriptions.refresh(true)}
  }
  UI.DataState {
    Layout.fillWidth:true
    visible:(!root.subscriptions || !root.subscriptions.sources.length) && !(root.subscriptions && root.subscriptions.error)
    kind:root.subscriptions && root.subscriptions.busy ? "loading" : "empty"
    title:root.strings.t(kind==="loading" ? "ics.sourcesLoading" : "ics.sourcesEmpty")
    description:root.strings.t("ics.explanation")
  }
  Repeater {
    model:root.subscriptions ? root.subscriptions.sources : []
    UI.ListRow {
      id:sourceRow
      required property var modelData
      Layout.fillWidth:true
      title:modelData.name
      statusKind:modelData.error ? "error" : "neutral"
      statusText:!modelData.enabled ? root.strings.t("ics.disabled") : modelData.error ? root.strings.t("ics.error."+modelData.error)+(modelData.fetchedAt ? " · "+root.strings.t("ics.cached") : "") : modelData.fetchedAt ? root.strings.t("ics.updated").arg(new Date(modelData.fetchedAt*1000).toLocaleString(Qt.locale(Commons.I18n.formatLocale),"d MMM HH:mm")) : root.strings.t("ics.pending")
      actions: [
        FeedbackButton {objectName:"calendarSourceToggle-"+sourceRow.modelData.id;text:root.strings.t(sourceRow.modelData.enabled ? "ics.disable" : "ics.enable");compact:true;focusable:true;enabled:!(!!root.subscriptions && root.subscriptions.busy);onClicked:root.subscriptions.toggle(sourceRow.modelData.id,!sourceRow.modelData.enabled)},
        FeedbackButton {objectName:"calendarSourceRemove-"+sourceRow.modelData.id;iconText:"󰅖";tooltipText:root.strings.t("ics.remove");compact:true;focusable:true;enabled:!(!!root.subscriptions && root.subscriptions.busy);onClicked:root.subscriptions.remove(sourceRow.modelData.id)}
      ]
    }
  }
  ColumnLayout {
    Layout.fillWidth:true;spacing:Design.gap.small
    visible:(root.subscriptions ? root.subscriptions.sources.length : 0)<6
    UI.FormField {
      id:nameField;Layout.fillWidth:true;label:root.strings.t("ics.name")
      DesignTextField {id:name;objectName:"calendarSourceName";Layout.fillWidth:true;Accessible.name:nameField.label;maximumLength:128;onAccepted:url.forceActiveFocus()}
    }
    UI.FormField {
      id:urlField;objectName:"calendarUrlField";Layout.fillWidth:true
      label:root.strings.t("ics.url");hint:root.strings.t("ics.private")
      error:url.text.trim() && !Security.calendarUrl(url.text.trim()) ? root.strings.t("ics.error.url") : ""
      DesignTextField {id:url;objectName:"calendarSourceUrl";Layout.fillWidth:true;Accessible.name:urlField.label;Accessible.description:urlField.message;invalid:!!urlField.error;maximumLength:4096;echoMode:TextInput.PasswordEchoOnEdit;onAccepted:if(add.enabled) add.clicked()}
    }
    RowLayout {
      Layout.fillWidth:true
      Item {Layout.fillWidth:true}
      FeedbackButton {id:add;objectName:"calendarSourceAdd";text:root.strings.t("ics.add");variant:"primary";focusable:true;enabled:!(!!root.subscriptions && root.subscriptions.busy) && !!name.text.trim() && !!Security.calendarUrl(url.text.trim());onClicked:root.subscriptions.add(name.text.trim(),url.text.trim())}
    }
  }
  UI.DataState {
    visible:!!root.subscriptions && !!root.subscriptions.error;Layout.fillWidth:true;kind:"error"
    title:root.subscriptions && root.subscriptions.error ? root.strings.t("ics.error."+root.subscriptions.error) : ""
    actionText:root.subscriptions && root.subscriptions.hasEnabled ? root.strings.t("ics.refresh") : ""
    actionEnabled:!!root.subscriptions && !root.subscriptions.busy
    onActionRequested:root.subscriptions.refresh(true)
  }
  Connections {target:root.subscriptions;function onSaved(){name.text="";url.text=""}}
}
