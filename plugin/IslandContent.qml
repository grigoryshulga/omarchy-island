import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ModuleCatalog.mjs" as Catalog
import "SettingsModel.mjs" as Settings
import "OverviewModel.mjs" as Overview
import "Model.js" as Model

Item {
  id: root
  required property var service
  required property var strings
  property var bar: null
  property var settings:({})
  property var externalFeedback: null
  readonly property bool musicHovered: {
    for(var i=0;i<moduleSections.count;i++) {var slot=moduleSections.itemAt(i);if(slot && slot.visible && slot.item && slot.item.interactionHovered) return true}
    return false
  }
  property bool overviewActive: true
  property bool expanded: false
  property bool radialBraille: true
  property bool hovering: false
  property string alertKind: ""
  property var weather: null
  readonly property var summaryWeather:weather || (service && ("weather" in service) ? service.weather : null)
  property date currentDate:new Date()
  function focusSummary(target) {(target==="calendarOpen" ? dateButton : weatherButton).forceActiveFocus()}
  Timer {interval:60000;repeat:true;running:root.visible && root.overviewActive && (root.expanded || root.hovering);onTriggered:root.currentDate=new Date()}
  onOverviewActiveChanged:{if(overviewActive) currentDate=new Date();else overviewDrag.cancel()}
  property bool compactNotifications: !expanded && !hovering && alertKind==="notification"
  signal settingRequested(string key,var value)
  signal expandRequested()
  signal calendarRequested()
  signal weatherRequested()
  signal closeRequested()
  property string detailPage: ""
  property var moduleDefinitions:Catalog.ordered("overview").filter(function(entry){return !!entry.overview})
  property bool configuring:false
  property bool settingsOpen:false
  onConfiguringChanged:if(!configuring) settingsOpen=false
  readonly property var overviewLayout:Overview.layout(moduleDefinitions,Preferences.get("overviewLayout"))
  function syncSections() {Model.syncKeys(sectionOrder,overviewLayout.map(function(row){return row.id}))}
  onOverviewLayoutChanged:syncSections()
  Component.onCompleted:syncSections()
  ListModel {id:sectionOrder}
  function configure(returnTarget) {
    if(!expanded || configuring) return
    returnFocus=returnTarget || detailNavigation.focused
    if(!detailOpen) summaryScrollY=overviewScroll.contentItem.contentY
    detailPage=""
    configuring=true
    overviewScroll.contentItem.contentY=0
    Qt.callLater(function(){detailNavigation.first(body)})
  }
  function changeLayout(id,patch,step) {settingRequested("overviewLayout",Overview.update(moduleDefinitions,Preferences.get("overviewLayout"),id,patch,step))}
  readonly property var detailDefinition:moduleDefinitions.find(function(entry){return entry.id===root.detailPage}) || null
  property real pageHeight: Style.space(520)
  property real maximumOverviewHeight:Style.space(640)
  readonly property bool detailOpen: detailPage!==""
  readonly property var detailItem: {
    for(var i=0;i<moduleSections.count;i++) {var slot=moduleSections.itemAt(i);if(slot && slot.modelData.id===detailPage) return slot.item}
    return null
  }
  readonly property bool navigationHidden:settingsOpen || (!!detailItem && detailItem.navigationHidden)
  readonly property bool ownsKeys:settingsOpen ? customizationSettings.ownsKeys : !!detailItem && detailItem.ownsKeys
  property var returnFocus: null
  property real summaryScrollY: 0
  KeyboardNavigation {id:detailNavigation;scope:root}
  function openDetails(page) {
    if(!expanded) {expandRequested();return}
    returnFocus=detailNavigation.focused
    summaryScrollY=overviewScroll.contentItem.contentY
    detailPage=page
    overviewScroll.contentItem.contentY=0
    Qt.callLater(function(){detailNavigation.first(body)})
  }
  function restoreSummary() {
    Qt.callLater(function(){
      overviewScroll.contentItem.contentY=summaryScrollY
      if(returnFocus && returnFocus.visible) detailNavigation.focusItem(returnFocus)
    })
  }
  function back() {
    if(overviewDrag.dragging) {overviewDrag.cancel();return true}
    if(settingsOpen) {
      settingsOpen=false
      Qt.callLater(function(){detailNavigation.focusItem(customizationSettingsButton)})
      return true
    }
    if(configuring) {configuring=false;restoreSummary();return true}
    if(!detailOpen) return false
    if(detailItem && detailItem.back()) return true
    detailPage=""
    restoreSummary()
    return true
  }
  onExpandedChanged:{currentDate=new Date();if(!expanded) {detailPage="";configuring=false}}
  onHoveringChanged:if(hovering) currentDate=new Date()
  readonly property var t3:service && service.t3 ? service.t3 : null
  readonly property var notificationIcon: {
    for(var i=0;i<moduleSections.count;i++) {var slot=moduleSections.itemAt(i);if(slot && slot.visible && slot.item && slot.item.toastIcon) return slot.item.toastIcon}
    return null
  }
  readonly property var toastIcon:alertKind==="t3" ? t3Toast.statusIcon : notificationIcon
  implicitHeight:expanded ? (detailOpen || configuring ? pageHeight : Math.min(maximumOverviewHeight,body.implicitHeight)) : body.implicitHeight
  MouseArea { anchors.fill: parent; acceptedButtons:Qt.LeftButton | Qt.RightButton; onClicked: mouse => {if(mouse.button===Qt.RightButton) {root.closeRequested();return}if(root.externalFeedback) root.externalFeedback.pulseFrom(root,Qt.point(mouse.x,mouse.y));if(!root.expanded) root.expandRequested()} }
  OverviewDrag {
    id:overviewDrag;objectName:"overviewDragController"
    anchors.fill:parent;z:100
    editing:root.configuring && !root.settingsOpen;entries:moduleSections;content:body;viewport:overviewScroll.contentItem
    onMoved:(key,beforeKey)=>{
      root.settingRequested("overviewLayout",Overview.move(root.moduleDefinitions,Preferences.get("overviewLayout"),key,beforeKey))
      Qt.callLater(function(){for(var i=0;i<moduleSections.count;i++) {var frame=moduleSections.itemAt(i);if(frame.entryKey===key) {detailNavigation.focusItem(frame.handleItem);break}}})
    }
  }
  Controls.ScrollView {
    id:overviewScroll
    objectName:"overviewScroll"
    visible:!root.settingsOpen
    width:parent.width
    height:root.expanded ? root.height : Math.min(root.height,root.implicitHeight)
    clip:true;contentWidth:availableWidth
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Controls.ScrollBar.vertical:Controls.ScrollBar {
      objectName:"overviewScrollBar"
      policy:Controls.ScrollBar.AlwaysOff
    }
  ColumnLayout {
    id: body
    width: overviewScroll.availableWidth
    spacing:root.configuring ? Design.gap.medium : root.compactNotifications ? Design.gap.tight : Design.gap.section
  RowLayout {
    objectName:"overviewHeader"
    visible:(root.expanded || root.hovering) && !root.detailOpen && !root.configuring
    Layout.fillWidth:true;spacing:Design.gap.small
    FeedbackButton {
      id:dateButton;objectName:"calendarOpen"
      Layout.fillWidth:true;Layout.minimumWidth:0
      text:root.currentDate.toLocaleDateString(Qt.locale(Commons.I18n.formatLocale),"ddd, d MMMM")
      fontSize:Design.type.title;leftAlign:true;horizontalPadding:0
      focusable:root.expanded && Settings.get(root.settings,"calendarEnabled")
      enabled:focusable;opacity:1
      tooltipText:root.strings.t("calendar.open")
      feedback:root.externalFeedback
      onClicked:root.calendarRequested()
    }
    WeatherChip {
      id:weatherButton;objectName:"weatherOpen"
      visible:Settings.get(root.settings,"weatherEnabled") && !!root.summaryWeather && root.summaryWeather.allowed
      weather:root.summaryWeather;strings:root.strings;feedback:root.externalFeedback
      enabled:root.expanded;focusable:enabled;opacity:1
      onClicked:root.weatherRequested()
    }
    FeedbackButton {
      id:customizeButton;objectName:"overviewCustomize"
      visible:root.expanded;iconText:"󰒓";compact:true;focusable:true
      tooltipText:root.strings.t("overview.customize");feedback:root.externalFeedback
      onClicked:root.configure(customizeButton)
    }
  }
  RowLayout {
    visible:root.detailPage!=="" && !(root.detailPage==="controls" && root.detailItem && root.detailItem.inPanel)
    Layout.fillWidth:true
    SectionHeading {Layout.fillWidth:true;title:root.detailDefinition ? (root.detailDefinition.title || root.strings.t(root.detailDefinition.titleKey)) : root.strings.t("notifications.active")}
    FeedbackButton {objectName:"overviewBack";implicitWidth:Design.compactControlHeight;implicitHeight:Design.compactControlHeight;horizontalPadding:0;verticalPadding:0;iconSize:Style.font.iconLarge;iconText:Commons.I18n.rightToLeft ? "󰁔" : "󰁍";tooltipText:root.strings.t("overview.back");compact:true;focusable:true;feedback:root.externalFeedback;onClicked:root.back()}
    FeedbackButton {objectName:"controlCustomize";visible:root.detailPage==="controls";iconText:"󰒓";tooltipText:root.strings.t("controls.customize");selected:root.detailItem && root.detailItem.editing || false;focusable:true;compact:true;feedback:root.externalFeedback;onClicked:if(root.detailItem) root.detailItem.configure()}
    FeedbackButton {objectName:"controlAddMenu";visible:root.detailPage==="controls" && root.detailItem && root.detailItem.editing || false;iconText:"+";tooltipText:root.strings.t("controls.plugins");selected:root.detailItem && root.detailItem.adding || false;focusable:true;compact:true;feedback:root.externalFeedback;onClicked:if(root.detailItem) root.detailItem.showAdd()}
  }
  RowLayout {
    visible:root.expanded && root.configuring
    Layout.fillWidth:true
    SectionHeading {Layout.fillWidth:true;title:root.strings.t("overview.customize")}
    FeedbackButton {
      id:customizationSettingsButton;objectName:"overviewSettings"
      text:root.strings.t("overview.settings")
      focusable:true;compact:true;feedback:root.externalFeedback
      onClicked:{root.settingsOpen=true;Qt.callLater(function(){customizationSettings.focusContent()})}
    }
    FeedbackButton {
      objectName:"overviewDone";text:root.strings.t("overview.done")
      focusable:true;compact:true;feedback:root.externalFeedback
      onClicked:root.back()
    }
  }
  T3SessionCard {
    id:t3Toast
    objectName:"t3ActivityToast"
    Layout.fillWidth:true
    visible:root.alertKind==="t3" && !root.expanded && !root.hovering && !!root.service && !!root.service.latestT3
    compactToast:true
    color:"transparent"
    row:root.service && root.service.latestT3 ? root.service.latestT3 : ({id:"",title:"",project:"",status:"idle",requestId:"",request:null,summary:""})
    bridge:root.t3;strings:root.strings;active:visible && root.visible
    feedback:root.externalFeedback
    onExpandRequested:root.expandRequested()
  }
  Repeater {
    id:moduleSections
    model:sectionOrder
    OverviewEditFrame {
      id:moduleFrame
      required property int index
      readonly property var modelData:definition
      readonly property var item:moduleSection.item
      definition:root.moduleDefinitions.find(function(entry){return entry.id===entryKey})
      config:root.overviewLayout.find(function(row){return row.id===entryKey})
      strings:root.strings;feedback:root.externalFeedback
      controller:overviewDrag;editing:root.configuring
      viewItem:moduleSection;available:moduleSection.available
      Layout.fillWidth:true
      visible:root.configuring || (moduleSection.available && (!(root.expanded || root.hovering) || config.visible || root.detailPage===entryKey) && (!root.detailOpen || root.detailPage===entryKey))
      onChanged:patch=>root.changeLayout(entryKey,patch,0)
      onStepped:delta=>{root.changeLayout(entryKey,{},delta);Qt.callLater(function(){detailNavigation.focusItem(moduleFrame.handleItem)})}
      ModuleSlot {
        id:moduleSection
        parent:moduleFrame.contentItem;width:parent.width
        enabled:!root.configuring
        viewSource:moduleFrame.definition.overview || ""
        backend:root.service && root.service.modules ? root.service.modules[moduleFrame.entryKey] || null : null
        visible:available && (!(root.expanded || root.hovering) || moduleFrame.config.visible || root.detailPage===moduleFrame.entryKey) && (!root.detailOpen || root.detailPage===moduleFrame.entryKey)
        presentation:QtObject {
          readonly property var service:root.service
          readonly property var settings:root.settings
          readonly property var strings:root.strings
          readonly property var feedback:root.externalFeedback
          readonly property var bar:root.bar
          readonly property bool hovering:root.hovering
          readonly property string alertKind:root.alertKind
          readonly property var alert:root.service && root.service.latest ? root.service.latest : null
          readonly property bool radialBraille:root.radialBraille
          readonly property bool expanded:root.expanded
          readonly property string size:(root.expanded || root.hovering) && moduleFrame.config ? moduleFrame.config.size : "standard"
          readonly property bool detail:root.detailPage===moduleFrame.entryKey
          readonly property bool active:root.overviewActive && root.visible && !root.settingsOpen && moduleSection.visible
          readonly property real pageHeight:root.height
        }
        readonly property bool moduleEnabled:!!backend && ("allowed" in backend ? backend.allowed : true)
        onModuleEnabledChanged:if(!moduleEnabled && root.detailPage===moduleFrame.entryKey) root.back()
        onDetailsRequested:root.detailPage===moduleFrame.entryKey ? root.back() : root.openDetails(moduleFrame.entryKey)
        onCloseRequested:root.closeRequested()
        onExpandRequested:root.expandRequested()
        onSettingRequested:(key,value)=>root.settingRequested(key,value)
      }
    }
  }
  Item {visible:root.configuring;Layout.fillWidth:true;implicitHeight:Design.gap.small}

  PlainText {Layout.fillWidth:true;visible:!root.compactNotifications && root.service && root.service.error!==undefined && root.service.error!=="";text:root.strings.t("error").arg(root.service && root.service.error ? root.service.error : "");color:Design.danger;wrapMode:Text.Wrap}

  }
  }
  ColumnLayout {
    anchors.fill:parent
    visible:root.settingsOpen
    spacing:Design.gap.small
    RowLayout {
      Layout.fillWidth:true
      FeedbackButton {
        objectName:"customizationSettingsBack"
        iconText:Commons.I18n.rightToLeft ? "󰁔" : "󰁍"
        tooltipText:root.strings.t("overview.backToCustomize")
        compact:true;focusable:true;feedback:root.externalFeedback
        onClicked:root.back()
      }
      SectionHeading {Layout.fillWidth:true;title:root.strings.t("settings.title")}
    }
    SettingsView {
      id:customizationSettings;objectName:"customizationSettings"
      Layout.fillWidth:true;Layout.fillHeight:true
      active:root.overviewActive && root.visible && root.settingsOpen
      settings:root.settings;strings:root.strings
      service:root.service;bar:root.bar
      modules:root.service && root.service.modules ? root.service.modules : ({})
      feedback:root.externalFeedback
      onSettingRequested:(key,value)=>root.settingRequested(key,value)
    }
  }
}
