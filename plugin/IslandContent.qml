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
  onOverviewActiveChanged:if(overviewActive) currentDate=new Date()
  property bool compactNotifications: !expanded && !hovering && alertKind==="notification"
  signal settingRequested(string key,var value)
  signal expandRequested()
  signal calendarRequested()
  signal weatherRequested()
  signal closeRequested()
  property string detailPage: ""
  property var moduleDefinitions:Catalog.ordered("overview").filter(function(entry){return !!entry.overview})
  property bool configuring:false
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
    Qt.callLater(function(){detailNavigation.first(editor)})
  }
  function changeLayout(id,patch,step) {settingRequested("overviewLayout",Overview.update(moduleDefinitions,Preferences.get("overviewLayout"),id,patch,step))}
  readonly property var detailDefinition:moduleDefinitions.find(function(entry){return entry.id===root.detailPage}) || null
  property real pageHeight: Style.space(520)
  readonly property bool detailOpen: detailPage!==""
  readonly property var detailItem: {
    for(var i=0;i<moduleSections.count;i++) {var slot=moduleSections.itemAt(i);if(slot && slot.modelData.id===detailPage) return slot.item}
    return null
  }
  readonly property bool navigationHidden:!!detailItem && detailItem.navigationHidden
  readonly property bool ownsKeys:!!detailItem && detailItem.ownsKeys
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
  implicitHeight: expanded ? pageHeight : body.implicitHeight
  MouseArea { anchors.fill: parent; acceptedButtons:Qt.LeftButton | Qt.RightButton; onClicked: mouse => {if(mouse.button===Qt.RightButton) {root.closeRequested();return}if(root.externalFeedback) root.externalFeedback.pulseFrom(root,Qt.point(mouse.x,mouse.y));if(!root.expanded) root.expandRequested()} }
  Controls.ScrollView {
    id:overviewScroll
    objectName:"overviewScroll"
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
    spacing: root.compactNotifications ? Design.gap.tight : Design.gap.section
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
      objectName:"overviewDone";text:root.strings.t("overview.done")
      focusable:true;compact:true;feedback:root.externalFeedback
      onClicked:root.back()
    }
  }
  ColumnLayout {
    id:editor
    visible:root.configuring && root.expanded
    Layout.fillWidth:true
    spacing:Design.gap.large
    PlainText {Layout.fillWidth:true;text:root.strings.t("overview.customizeHint");wrapMode:Text.Wrap;color:Design.secondaryText}
    Repeater {
      model:sectionOrder
      ColumnLayout {
        id:editRow
        required property string entryKey
        required property int index
        readonly property var definition:root.moduleDefinitions.find(function(entry){return entry.id===entryKey})
        readonly property var config:root.overviewLayout.find(function(row){return row.id===entryKey})
        Layout.fillWidth:true
        spacing:Design.gap.small
        RowLayout {
          Layout.fillWidth:true
          PlainText {Layout.fillWidth:true;text:editRow.definition.title || root.strings.t(editRow.definition.titleKey);wrapMode:Text.Wrap}
          FeedbackButton {objectName:"overviewVisible-"+editRow.entryKey;text:root.strings.t(editRow.config.visible ? "overview.hide" : "overview.show");selected:editRow.config.visible;focusable:true;compact:true;onClicked:root.changeLayout(editRow.entryKey,{visible:!editRow.config.visible},0)}
          FeedbackButton {objectName:"overviewUp-"+editRow.entryKey;iconText:"↑";tooltipText:root.strings.t("overview.moveUp");enabled:editRow.index>0;focusable:true;compact:true;onClicked:root.changeLayout(editRow.entryKey,{},-1)}
          FeedbackButton {objectName:"overviewDown-"+editRow.entryKey;iconText:"↓";tooltipText:root.strings.t("overview.moveDown");enabled:editRow.index<sectionOrder.count-1;focusable:true;compact:true;onClicked:root.changeLayout(editRow.entryKey,{},1)}
        }
        DesignDropdown {
          objectName:"overviewSize-"+editRow.entryKey
          Layout.fillWidth:true
          visible:Overview.supported(editRow.definition).length>1
          showLabel:false
          value:editRow.config.size
          options:Overview.supported(editRow.definition).map(function(size){return {value:size,label:root.strings.t("overview.size."+size)}})
          onChanged:value=>root.changeLayout(editRow.entryKey,{size:value},0)
        }
      }
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
    ModuleSlot {
      id:moduleSection
      required property string entryKey
      readonly property var modelData:root.moduleDefinitions.find(function(entry){return entry.id===entryKey})
      readonly property var config:root.overviewLayout.find(function(row){return row.id===entryKey})
      Layout.fillWidth:true
      viewSource:modelData.overview || ""
      backend:root.service && root.service.modules ? root.service.modules[modelData.id] || null : null
      visible:available && !root.configuring && (!(root.expanded || root.hovering) || config.visible || root.detailPage===modelData.id) && (!root.detailOpen || root.detailPage===modelData.id)
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
        readonly property string size:(root.expanded || root.hovering) && moduleSection.config ? moduleSection.config.size : "standard"
        readonly property bool detail:root.detailPage===moduleSection.modelData.id
        readonly property bool active:root.overviewActive && root.visible && moduleSection.visible
        readonly property real pageHeight:root.height
      }
      readonly property bool moduleEnabled:!!backend && ("allowed" in backend ? backend.allowed : true)
      onModuleEnabledChanged:if(!moduleEnabled && root.detailPage===modelData.id) root.back()
      onDetailsRequested:root.detailPage===modelData.id ? root.back() : root.openDetails(modelData.id)
      onCloseRequested:root.closeRequested()
      onExpandRequested:root.expandRequested()
      onSettingRequested:(key,value)=>root.settingRequested(key,value)
    }
  }

  PlainText {Layout.fillWidth:true;visible:!root.compactNotifications && root.service && root.service.error!==undefined && root.service.error!=="";text:root.strings.t("error").arg(root.service && root.service.error ? root.service.error : "");color:Design.danger;wrapMode:Text.Wrap}

  }
  }
}
