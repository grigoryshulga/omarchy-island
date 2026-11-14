import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons


Column {
  id:root
  required property var backend
  required property var strings
  property var feedback:null
  property string tab:"limits"
  property bool editing: false
  property bool adding: false
  property string selectedProvider: ""
  function configure() {
    editing = !editing
    adding = false
    selectedProvider = ""
    tab = "limits"
  }
  function showAdd() { adding = !adding; selectedProvider = ""; tab = "limits" }
  function back() {
    if (limitsList.cancelDrag()) return true
    if (adding || selectedProvider) { var id = selectedProvider; adding = false; selectedProvider = ""; Qt.callLater(function() { limitsList.focusProvider(id) }); return true }
    if (editing) { editing = false; return true }
    return false
  }
  onEditingChanged: if (!editing) { adding = false; selectedProvider = "" }
  property real availableHeight: 500
  signal settingRequested(string key,var value)
  spacing:Design.gap.small
  onVisibleChanged: { if (visible && backend) backend.loadCatalog(); if (!visible) editing = false }
  RowLayout {
    id: navigation
    width:parent.width;spacing:Design.gap.micro
    Repeater {
      model:["limits","usage"]
      TabButton {required property string modelData;Layout.fillWidth:true;label:root.strings.t("limits.tab."+modelData);tabActive:root.tab===modelData;focusable:true;feedback:root.feedback;onClicked:root.tab=modelData}
    }
    FeedbackButton {text:"󰑐";tooltipText:root.strings.t("limits.refresh");compact:true;focusable:true;enabled:root.backend && !root.backend.busy;onClicked:root.backend.refresh()}
  }
  PlainText {
    id: status
    objectName:"limitsCenterStatus"
    visible:!!root.backend && (root.backend.busy || root.backend.error!=="")
    width:parent.width;typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap
    text:root.strings.t(root.backend && root.backend.busy ? "limits.loading" : "limits.error")
  }
  // Limits use the Overview viewport; Usage bounds its own scroll below its filters.
  Column {
    id:content
    objectName:"limitsCenterContent"
    width:parent.width;spacing:Design.gap.small
    AgentLimitsList {
      id: limitsList
      visible: root.tab === "limits" && !root.adding && !root.selectedProvider
      editing: root.editing
      onEditProvider: id => root.selectedProvider = id
      width: parent.width
      backend: root.backend
      strings: root.strings
      feedback: root.feedback
      onSettingRequested: (key, value) => root.settingRequested(key, value)
    }
    AgentUsage {
      visible: root.tab === "usage"
      width: parent.width
      availableHeight: Math.max(180, root.availableHeight - navigation.height - root.spacing - (status.visible ? status.height + root.spacing : 0))
      backend: root.backend; strings: root.strings; feedback: root.feedback
    }
    AgentLimitsProviders {
      visible: root.editing && (root.adding || root.selectedProvider !== "")
      width: parent.width
      backend: root.backend; strings: root.strings; feedback: root.feedback
      embedded: true
      adding: root.adding
      providerId: root.selectedProvider
      onProviderChosen: id => { root.adding = false; root.selectedProvider = id }
    }
  }
}
