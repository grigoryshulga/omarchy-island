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
  Timer {
    interval: Math.max(1,60000 - root.currentDate.getSeconds()*1000 - root.currentDate.getMilliseconds())
    repeat:true; running:root.visible && root.overviewActive && (root.expanded || root.hovering)
    onTriggered:root.currentDate=new Date()
  }
  onVisibleChanged:if(visible) currentDate=new Date()
  onOverviewActiveChanged:{if(overviewActive) currentDate=new Date();else overviewDrag.cancel()}
  property bool compactNotifications: !expanded && !hovering && alertKind==="notification"
  signal settingRequested(string key,var value)
  signal expandRequested()
  signal calendarRequested()
  signal weatherRequested()
  signal closeRequested()
  property string detailPage: ""
  property var moduleDefinitions:Catalog.ordered("overview").filter(function(entry){return !!entry.overview})
  readonly property bool dragActive:overviewDrag.dragging
  readonly property bool reorderMenuOpen:overviewDrag.actionsKey!==""
  property bool configuring:false
  function openSettings(groupId) {
    closeRequested()
    IslandSettingsWindow.present(root,groupId)
  }
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
    Qt.callLater(function(){detailNavigation.first(detailHeader.visible ? detailHeader : body)})
  }
  function changeLayout(id,patch,step) {settingRequested("overviewLayout",Overview.update(moduleDefinitions,Preferences.get("overviewLayout"),id,patch,step))}
  readonly property var detailDefinition:Catalog.definition(detailPage)
  property real pageHeight: Style.space(520)
  property real maximumOverviewHeight:Style.space(640)
  readonly property bool detailOpen: detailPage!==""
  readonly property var detailItem: {
    if (detailDefinition && detailDefinition.detail) return headerDetail.item
    for(var i=0;i<moduleSections.count;i++) {var slot=moduleSections.itemAt(i);if(slot && slot.modelData.id===detailPage) return slot.item}
    return null
  }
  readonly property bool navigationHidden:!!detailItem && detailItem.navigationHidden
  readonly property bool ownsKeys:!!detailItem && detailItem.ownsKeys
  property var returnFocus: null
  property real summaryScrollY: 0
  KeyboardNavigation {id:detailNavigation;scope:root}
  property var activityTarget: null
  onDetailPageChanged:activityTarget=null
  function openDetails(page,target) {
    if(!expanded) {
      expandRequested()
      Qt.callLater(function(){if(root.expanded) root.openDetails(page,target)})
      return
    }
    returnFocus=page==="timers" ? timeButton : detailNavigation.focused
    summaryScrollY=overviewScroll.contentItem.contentY
    detailPage=page
    if (detailDefinition && detailDefinition.detail) headerDetail.definition=detailDefinition
    activityTarget=target || null
    overviewScroll.contentItem.contentY=0
    Qt.callLater(function(){
      if (root.detailPage!==page) return
      if (target && (!root.detailItem || !root.detailItem.available)) {
        root.back()
        return
      }
      if ((target || (root.detailDefinition && root.detailDefinition.detail)) && root.detailItem && typeof root.detailItem.focusActivity==="function" && root.detailItem.focusActivity(detailNavigation)) return
      detailNavigation.first(detailHeader.visible ? detailHeader : body)
    })
  }
  function restoreSummary() {
    Qt.callLater(function(){
      overviewScroll.contentItem.contentY=summaryScrollY
      if(returnFocus && returnFocus.visible) detailNavigation.focusItem(returnFocus)
    })
  }
  function back() {
    if(overviewDrag.dragging) {overviewDrag.cancel();return true}
    if(overviewDrag.actionsKey) {
      var frame=moduleSections.itemAt(root.overviewLayout.findIndex(function(row){return row.id===overviewDrag.actionsKey}))
      overviewDrag.actionsKey=""
      if(frame) detailNavigation.focusItem(frame.handleItem)
      return true
    }
    if(configuring) {configuring=false;restoreSummary();return true}
    if(!detailOpen) return false
    if(detailItem && detailItem.back()) {
      if (detailPage === "agentLimits" && !detailItem.editing)
        Qt.callLater(function() { detailNavigation.focusItem(limitsEditButton) })
      return true
    }
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
  readonly property var toastIcon:alertKind==="t3" ? t3Toast.statusIcon : alertKind==="herdr" ? herdrToast.statusIcon : notificationIcon
  implicitHeight: {
    if (!expanded) return body.implicitHeight
    if (configuring) return pageHeight
    if (!detailOpen) return Math.min(maximumOverviewHeight,body.implicitHeight)
    return detailPage==="t3" || (detailDefinition && detailDefinition.detail)
        ? Math.min(maximumOverviewHeight,overviewScroll.y+body.implicitHeight) : pageHeight
  }
  MouseArea { anchors.fill: parent; acceptedButtons:Qt.LeftButton | Qt.RightButton; onClicked: mouse => {if(mouse.button===Qt.RightButton) {root.closeRequested();return}if(root.externalFeedback) root.externalFeedback.pulseFrom(root,Qt.point(mouse.x,mouse.y));if(!root.expanded) root.expandRequested()} }
  OverviewDrag {
    id:overviewDrag;objectName:"overviewDragController"
    anchors.fill:parent;z:100
    editing:root.configuring;entries:moduleSections;content:body;viewport:overviewScroll.contentItem
    onMoved:(key,beforeKey)=>{
      root.settingRequested("overviewLayout",Overview.move(root.moduleDefinitions,Preferences.get("overviewLayout"),key,beforeKey))
      Qt.callLater(function(){for(var i=0;i<moduleSections.count;i++) {var frame=moduleSections.itemAt(i);if(frame.entryKey===key) {detailNavigation.focusItem(frame.handleItem);break}}})
    }
  }
  RowLayout {
    id: detailHeader
    visible:root.detailPage!=="" && !(root.detailPage==="controls" && root.detailItem && root.detailItem.inPanel)
    width: parent.width
    NavigationBackButton {
      objectName:"overviewBack"
      strings:root.strings
      feedback:root.externalFeedback
      onClicked:root.back()
    }
    SectionHeading {Layout.fillWidth:true;title:root.detailDefinition ? (root.detailDefinition.title || root.strings.t(root.detailDefinition.titleKey)) : root.strings.t("notifications.active")}
    FeedbackButton {
      objectName: "limitsAddProvider"
      visible: root.detailPage === "agentLimits" && !!root.detailItem && root.detailItem.editing
      iconSize:fontSize;iconText: "+"; tooltipText: root.strings.t("limits.addProvider")
      compact: true; focusable: true; feedback: root.externalFeedback
      onClicked: root.detailItem.showAdd()
    }
    FeedbackButton {
      id: limitsEditButton
      objectName: "limitsEdit"
      visible: root.detailPage === "agentLimits"
      text: root.strings.t(root.detailItem && root.detailItem.editing ? "limits.finishPins" : "limits.edit")
      selected: !!(root.detailItem && root.detailItem.editing)
      compact: true; focusable: true; feedback: root.externalFeedback
      onClicked: root.detailItem.configure()
    }
    FeedbackButton {objectName:"controlCustomize";visible:root.detailPage==="controls";iconText:"󰒓";tooltipText:root.strings.t("controls.customize");selected:root.detailItem && root.detailItem.editing || false;focusable:true;compact:true;feedback:root.externalFeedback;onClicked:if(root.detailItem) root.detailItem.configure()}
    FeedbackButton {objectName:"controlAddMenu";visible:root.detailPage==="controls" && root.detailItem && root.detailItem.editing || false;iconText:"+";tooltipText:root.strings.t("controls.plugins");selected:root.detailItem && root.detailItem.adding || false;focusable:true;compact:true;feedback:root.externalFeedback;onClicked:if(root.detailItem) root.detailItem.showAdd()}
  }
  Controls.ScrollView {
    id:overviewScroll
    objectName:"overviewScroll"
    width:parent.width
    y: detailHeader.visible ? detailHeader.height + Design.gap.small : 0
    height:Math.max(0,(root.expanded ? root.height : Math.min(root.height,root.implicitHeight)) - y)
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
    Layout.fillWidth:true;spacing:Design.gap.tight
    component HeaderButton: FeedbackButton {
      horizontalPadding:Design.gap.small
      Layout.alignment:Qt.AlignBaseline
      fontSize:Design.type.title
    }
    HeaderButton {
      id:timeButton; objectName:"timersOpen"
      text:root.currentDate.toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),Locale.ShortFormat)
      compact:true
      enabled:!!root.service && !!root.service.modules && !!root.service.modules.timers
      focusable:root.expanded; opacity:1
      foreground:Design.accent
      tooltipText:root.strings.t("timers.open")
      Accessible.name:text + " · " + tooltipText
      feedback:root.externalFeedback
      onClicked:root.openDetails("timers")
    }
    HeaderButton {
      id:dateButton;objectName:"calendarOpen"
      Layout.fillWidth:true;Layout.minimumWidth:0;Layout.maximumWidth:implicitWidth
      text:root.currentDate.toLocaleDateString(Qt.locale(Commons.I18n.formatLocale),"ddd, d MMMM")
      leftAlign:true
      focusable:root.expanded && Settings.get(root.settings,"calendarEnabled")
      enabled:focusable;opacity:1
      tooltipText:root.strings.t("calendar.open")
      feedback:root.externalFeedback
      onClicked:root.calendarRequested()
    }
    Item {Layout.fillWidth:true; Layout.preferredWidth:0}
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
      tooltipText:root.strings.t("overview.settings");feedback:root.externalFeedback
      onClicked:root.openSettings()
    }
  }
  ModuleSlot {
    id:headerDetail
    property var definition:null
    viewSource:definition ? definition.detail : ""
    onCloseRequested:root.back()
    Layout.fillWidth:true
    visible:!!root.detailDefinition && !!root.detailDefinition.detail
    backend:root.service && root.service.modules && definition ? root.service.modules[definition.id] || null : null
    presentation:QtObject {
      readonly property var bar:root.bar
      readonly property real pageHeight:Math.max(1,root.maximumOverviewHeight-overviewScroll.y)
      readonly property var strings:root.strings
      readonly property var feedback:root.externalFeedback
      readonly property var activityTarget:root.activityTarget
      readonly property bool active:root.overviewActive && root.visible && headerDetail.visible && root.expanded
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
    onExpandRequested:root.openDetails("t3",{sessionId:row.id})
  }
  HerdrSessionCard {
    id:herdrToast
    active:visible && root.visible
    feedback:root.externalFeedback
    onExpandRequested:root.expandRequested()
    objectName:"herdrActivityToast"
    Layout.fillWidth:true
    visible:root.alertKind==="herdr" && !root.expanded && !root.hovering && !!root.service && !!root.service.latestHerdr
    color:"transparent"
    row:root.service && root.service.latestHerdr ? root.service.latestHerdr : ({title:"",source:"",pane:"",status:"idle"})
    strings:root.strings
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
      canMoveUp:index>0
      canMoveDown:index+1<moduleSections.count
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
          readonly property var activityTarget:detail ? root.activityTarget : null
          readonly property bool detail:root.detailPage===moduleFrame.entryKey
          readonly property bool active:root.overviewActive && root.visible && moduleSection.visible
          readonly property real pageHeight:detail && moduleFrame.entryKey==="t3"
              ? Math.max(1,Math.min(root.maximumOverviewHeight,root.pageHeight)-overviewScroll.y) : overviewScroll.height
        }
        readonly property bool moduleEnabled:!!backend && ("allowed" in backend ? backend.allowed : true)
        onAvailableChanged:if(!available && root.activityTarget && root.detailPage===moduleFrame.entryKey) Qt.callLater(function(){
          if(!moduleSection.available && root.activityTarget && root.detailPage===moduleFrame.entryKey) root.back()
        })
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
}
