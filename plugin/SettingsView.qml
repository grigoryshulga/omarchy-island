import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import "SettingsModel.js" as Settings

Item {
  id:root
  required property var strings
  property var settings:({})
  property var feedback:null
  property bool active:true
  property int category:0
  property bool ownsKeys:false
  signal settingRequested(string key,var value)
  function focusContent() { if(tabs.itemAt(category)) tabs.itemAt(category).forceActiveFocus() }
  function revealTab(item) {
    var at=item.mapToItem(tabRow,0,0),x=tabViewport.contentX
    if(at.x<x) x=at.x
    else if(at.x+item.width>x+tabViewport.width) x=at.x+item.width-tabViewport.width
    tabViewport.contentX=Math.max(0,Math.min(Math.max(0,tabViewport.contentWidth-tabViewport.width),x))
  }
  function closeEditors() {
    for(var i=0;i<groups.count;i++) groups.itemAt(i).closeEditors()
    ownsKeys=false
  }
  function updateOwnsKeys() {
    var open=false
    for(var i=0;i<groups.count;i++) open=open || groups.itemAt(i).hasOpenEditor()
    ownsKeys=open
  }
  onVisibleChanged: if(!visible) closeEditors()
  onCategoryChanged: {closeEditors();viewport.contentY=0}
  Flickable {
    id:tabViewport
    objectName:"settingsTabs"
    width:parent.width;height:tabRow.implicitHeight
    contentWidth:tabRow.implicitWidth;contentHeight:height
    flickableDirection:Flickable.HorizontalFlick
    boundsBehavior:Flickable.StopAtBounds
    clip:true
    // One row at every scale; keyboard focus reveals tabs on narrow panels.
    Row {
      id:tabRow
      spacing:Design.gap.micro
      layoutDirection:Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
      Repeater {
        id:tabs
        model:Settings.sections
        TabButton {
          required property var modelData
          required property int index
          objectName:"settingsTab-"+modelData.id
          label:root.strings.t("settings.tab."+modelData.id)
          Accessible.name:label
          tabActive:root.category===index
          fontSize:Design.type.label
          radius:Design.controlRadius
          focusable:true
          feedback:root.feedback
          onActiveFocusChanged:if(activeFocus) root.revealTab(this)
          onClicked:{root.category=index;root.revealTab(this)}
        }
      }
    }
  }
  Flickable {
    id:viewport
    objectName:"settingsViewport"
    anchors.left:parent.left;anchors.right:parent.right
    anchors.top:tabViewport.bottom;anchors.bottom:parent.bottom
    anchors.topMargin:Design.gap.section
    contentWidth:width;contentHeight:body.implicitHeight
    clip:true;boundsBehavior:Flickable.StopAtBounds
    Controls.ScrollBar.vertical:Controls.ScrollBar {policy:Controls.ScrollBar.AsNeeded}
    Column {
      id:body
      width:viewport.width
      spacing:Design.gap.section
      Repeater {
        id:groups
        model:Settings.sections[root.category].groups
        Column {
          id:group
          required property var modelData
          width:body.width-Design.gap.small
          x:Commons.I18n.rightToLeft ? Design.gap.small : 0
          spacing:Design.gap.small
          function closeEditors() {for(var i=0;i<rows.count;i++) rows.itemAt(i).editor.close()}
          function hasOpenEditor() {for(var i=0;i<rows.count;i++) if(rows.itemAt(i).editor.popupOpen) return true;return false}
          SectionHeading {width:parent.width;title:root.strings.t("settings.group."+group.modelData.id)}
          PlainText {
            width:parent.width
            visible:!!group.modelData.description
            text:visible ? root.strings.t("settings.description."+group.modelData.id) : ""
            typeRole:"caption";color:Design.secondaryText
            wrapMode:Text.Wrap
          }
          Repeater {
            id:rows
            model:group.modelData.rows
            SettingsRow {
              required property var modelData
              width:group.width
              spec:modelData
              strings:root.strings;settings:root.settings;active:root.active
              onSettingRequested:(key,value)=>root.settingRequested(key,value)
              onPopupChanged:root.updateOwnsKeys()
            }
          }
        }
      }
    }
  }
}
