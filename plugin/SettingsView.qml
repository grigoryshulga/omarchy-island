import QtQuick
import qs.Commons
import qs.Commons as Commons
import "SettingsModel.mjs" as Settings
import "PanelGeometry.js" as Geometry

Item {
  id:root
  required property var strings
  property var settings:({})
  property var service:null
  property var bar:null
  property var modules:({})
  property var feedback:null
  property bool active:true
  property bool windowMode:false
  readonly property var sections:windowMode ? Settings.sections.concat([{id:"overview",groups:[]}]) : Settings.sections
  readonly property bool sidebar:windowMode && width>=Style.space(620)
  readonly property bool overviewSection:sections[category].id==="overview"
  readonly property bool standalone:!!bar && "panelSize" in bar && typeof bar.setPosition === "function"
  property int category:0
  property bool ownsKeys:false
  signal settingRequested(string key,var value)
  function revealFocus(item) {
    var at=item.mapToItem(body,0,0)
    if(at.y<viewport.contentY) viewport.contentY=at.y
    else if(at.y+item.height>viewport.contentY+viewport.height) viewport.contentY=at.y+item.height-viewport.height
  }
  function focusContent() { if(tabs.itemAt(category)) tabs.itemAt(category).forceActiveFocus() }
  function focusGroup(groupId) {
    if(!groupId) return false
    var sectionIndex=sections.findIndex(section=>section.groups.some(group=>group.id===groupId))
    if(sectionIndex<0) return false
    category=sectionIndex
    Qt.callLater(function(){
      root.revealTab(tabs.itemAt(root.category))
      for(var i=0;i<groups.count;i++) {
        var group=groups.itemAt(i)
        if(group.modelData.id===groupId) {
          group.heading.forceActiveFocus(Qt.TabFocusReason)
          viewport.contentY=Math.max(0,Math.min(group.y,viewport.contentHeight-viewport.height))
          break
        }
      }
    })
    return true
  }
  function revealTab(item) {
    if(!item) return
    if(sidebar) {
      var y=item.y
      if(y<tabViewport.contentY) tabViewport.contentY=y
      else if(y+item.height>tabViewport.contentY+tabViewport.height) tabViewport.contentY=y+item.height-tabViewport.height
      return
    }
    var at=item.mapToItem(tabRow,0,0),x=tabViewport.contentX
    if(at.x<x) x=at.x
    else if(at.x+item.width>x+tabViewport.width) x=at.x+item.width-tabViewport.width
    tabViewport.contentX=Math.max(0,Math.min(Math.max(0,tabViewport.contentWidth-tabViewport.width),x))
  }
  function dismissEditor() {
    if(layoutEditor.item && (layoutEditor.item.dragActive || layoutEditor.item.reorderMenuOpen)) return layoutEditor.item.back()
    if(!ownsKeys) return false
    closeEditors()
    focusContent()
    return true
  }
  function closeEditors() {
    for(var i=0;i<groups.count;i++) groups.itemAt(i).closeEditors()
    if(clockEditor.item) clockEditor.item.closeEditors()
    if(positionEditor.item) positionEditor.item.editor.close()
    ownsKeys=false
  }
  function updateOwnsKeys() {
    var open=(!!clockEditor.item && clockEditor.item.ownsKeys)
      || (!!positionEditor.item && positionEditor.item.editor.popupOpen)
    for(var i=0;i<groups.count;i++) open=open || groups.itemAt(i).hasOpenEditor()
    ownsKeys=open
  }
  onVisibleChanged: if(!visible) closeEditors()
  onCategoryChanged: {closeEditors();viewport.contentY=0}
  FontMetrics {id:navMetrics;font.family:Design.fontFamily;font.pixelSize:Design.type.label}
  Rectangle {
    visible:root.sidebar;anchors.fill:tabViewport
    color:Design.surface;radius:Design.cardRadius
  }
  Flickable {
    id:tabViewport
    objectName:"settingsTabs"
    LayoutMirroring.enabled:root.windowMode && Commons.I18n.rightToLeft
    onWidthChanged:Qt.callLater(function(){root.revealTab(tabs.itemAt(root.category))})
    width:root.sidebar ? Math.max(Style.space(182),Math.min(root.width/3,navMetrics.advanceWidth(root.strings.t("settings.tab.overview"))+Design.gap.spacious)) : parent.width;height:root.sidebar ? parent.height : tabRow.implicitHeight
    anchors.left:parent.left
    contentWidth:root.sidebar ? width : tabRow.implicitWidth
    contentHeight:root.sidebar ? tabRow.implicitHeight : height
    flickableDirection:root.sidebar ? Flickable.VerticalFlick : Flickable.HorizontalFlick
    boundsBehavior:Flickable.StopAtBounds
    clip:true
    Grid {
      columns:root.sidebar ? 1 : root.sections.length
      id:tabRow
      spacing:Design.gap.micro
      layoutDirection:Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
      Repeater {
        id:tabs
        model:root.sections
        TabButton {
          required property var modelData
          required property int index
          objectName:"settingsTab-"+modelData.id
          width:root.sidebar ? tabViewport.width : implicitWidth
          height:root.sidebar ? Math.max(implicitHeight,Style.space(44)) : implicitHeight
          leftAlign:root.sidebar
          LayoutMirroring.enabled:root.sidebar && Commons.I18n.rightToLeft
          LayoutMirroring.childrenInherit:root.sidebar && Commons.I18n.rightToLeft
          iconText:root.sidebar ? ({general:"󰒓",panel:"󰥔",alerts:"󰂚",modules:"󰘦",overview:"󰕮"})[modelData.id] : ""
          iconSize:Design.type.iconSmall
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
    LayoutMirroring.enabled:root.windowMode && Commons.I18n.rightToLeft
    anchors.left:root.sidebar ? tabViewport.right : parent.left;anchors.right:parent.right
    anchors.leftMargin:root.sidebar ? Design.gap.large : 0
    anchors.top:root.sidebar ? parent.top : tabViewport.bottom;anchors.bottom:parent.bottom
    anchors.topMargin:root.sidebar ? 0 : Design.gap.section
    visible:!root.overviewSection
    contentWidth:width;contentHeight:body.implicitHeight
    clip:true;boundsBehavior:Flickable.StopAtBounds
    Column {
      id:body
      width:viewport.width
      spacing:Design.gap.page
      Loader {
        id:positionEditor
        width:body.width-Design.gap.small
        active:clockEditor.active && root.standalone
        visible:active
        sourceComponent:SettingsRow {
          spec:({key:"panelPosition",type:"choice"})
          strings:root.strings
          choiceValue:root.bar.position
          choiceValues:Geometry.positions
          onSettingRequested:(key,value)=>root.bar.setPosition(value)
          onPopupChanged:root.updateOwnsKeys()
        }
        onItemChanged:root.updateOwnsKeys()
      }
      Loader {
        id:clockEditor
        width:body.width-Design.gap.small
        active:root.visible && root.active && root.sections[root.category].id==="panel"
        visible:active
        sourceComponent:ClockLayoutEditor {
          scrollViewport:viewport
          settings:root.settings;service:root.service;bar:root.bar;strings:root.strings;active:root.active
          onSettingRequested:(key,value)=>root.settingRequested(key,value)
          onRevealFocus:item=>root.revealFocus(item)
          onOwnsKeysChanged:root.updateOwnsKeys()
        }
        onItemChanged:root.updateOwnsKeys()
      }
      Repeater {
        id:groups
        model:root.sections[root.category].groups.filter(group=>!root.standalone || group.id!=="notifications")
        Column {
          id:group
          required property var modelData
          width:body.width-Design.gap.small
          x:Commons.I18n.rightToLeft ? Design.gap.small : 0
          spacing:Design.gap.small
          function closeEditors() {for(var i=0;i<rows.count;i++) rows.itemAt(i).editor.close()}
          function hasOpenEditor() {for(var i=0;i<rows.count;i++) if(rows.itemAt(i).editor.popupOpen) return true;return false}
          readonly property alias heading:sectionHeading
          PlainText {id:sectionHeading;objectName:"settingsHeading-"+group.modelData.id;width:parent.width;text:root.strings.t("settings.group."+group.modelData.id);typeRole:"settingsHeading";wrapMode:Text.Wrap;Accessible.role:Accessible.Heading}
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
          ModuleSlot {
            width:group.width
            active:root.active
            viewSource:group.modelData.view || ""
            backend:root.modules[group.modelData.moduleId] || null
            presentation:QtObject {
              readonly property var strings:root.strings
              readonly property var feedback:root.feedback
              readonly property bool active:root.active
              function revealFocus(item) {root.revealFocus(item)}
            }
            visible:!!item && item.available
            height:visible ? item.implicitHeight : 0
            onSettingRequested:(key,value)=>root.settingRequested(key,value)
          }
        }
      }
    }
  }
  Loader {
    id:layoutEditor
    anchors.fill:viewport
    active:root.active && root.overviewSection
    onActiveChanged:if(active) setSource(Qt.resolvedUrl("IslandContent.qml"),{
      strings:Qt.binding(()=>root.strings),service:Qt.binding(()=>root.service),settings:Qt.binding(()=>root.settings),
      bar:Qt.binding(()=>root.bar),expanded:true,configuring:true,pageHeight:Qt.binding(()=>layoutEditor.height)
    })
    Connections {
      target:layoutEditor.item
      function onSettingRequested(key,value){root.settingRequested(key,value)}
    }
  }
}
