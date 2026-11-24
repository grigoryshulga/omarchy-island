import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "ModuleCatalog.mjs" as Catalog
import "ClockLayout.mjs" as ClockLayout
import "SettingsModel.mjs" as Settings
import "NowActivity.mjs" as NowActivity
import "NowPresentation.js" as NowPresentation

GridLayout {
  id:root
  property var elements:[]
  property var service:null
  property var activities:NowActivity.activities(service)
  property var settings:({})
  required property var strings
  property var bar:null
  property bool vertical:false
  property real barSize:26
  property real barHeight:26
  property bool showAlert:false
  property color foreground:Design.barText
  property real waveSpan:0
  property bool editing:false
  property string selectedId:""
  readonly property var indicators:service && ("indicators" in service) ? service.indicators : null
  readonly property var entries:ClockLayout.catalog(Catalog.ordered("indicator"))
  readonly property string tooltips: {
    var tips=[]
    for(var i=0;i<cells.count;i++) {var cell=cells.itemAt(i);if(cell && cell.live) {
      var item=cell.view.item
      var tip=("tooltip" in item) ? item.tooltip : ("tooltipText" in item) ? item.tooltipText : ""
      if(tip || !cell.entry.moduleId) tips.push(tip || title(cell.modelData))
    }}
    return tips.join(" · ")
  }
  signal activate(string mode)
  signal quickAction(string mode)
  signal pageRequested(int index)
  signal detailsRequested(string moduleId)
  signal calendarRequested()
  signal nowRequested(var activity)
  signal nowListRequested()
  signal nowHovered(bool hovered, var activity)
  signal selected(string id)
  signal dropped(string id,var item,real dx,real dy)
  signal revealFocus(var item)
  function preference(key) {return settings.clockLayout!==undefined && settings.clockLayout!==null && ClockLayout.valid(settings.clockLayout) || Settings.get(settings,key)}
  function title(row) {
    var entry=entries.find(function(entry){return entry.id===row.id})
    return row.kind!=="indicator" ? strings.t("clock."+row.kind) : entry ? entry.title || strings.t(entry.titleKey) : row.id
  }
  function positions(target) {
    var result=[]
    for(var i=0;i<cells.count;i++) {var item=cells.itemAt(i),p=item.mapToItem(target,item.width/2,item.height/2);result.push({id:item.modelData.id,x:p.x,y:p.y})}
    return result
  }
  function actionAt(source,point) {
    for (var i=0;i<cells.count;i++) {
      var cell=cells.itemAt(i)
      if (cell && cell.interactive && cell.contains(cell.mapFromItem(source,point))) return cell
    }
    return null
  }
  function focusElement(id) {for(var i=0;i<cells.count;i++) if(cells.itemAt(i).modelData.id===id) cells.itemAt(i).button.forceActiveFocus()}
  columns:vertical ? 1 : -1
  rows:vertical ? -1 : 1
  columnSpacing:Style.space(5);rowSpacing:Style.space(5)
  Repeater {
    id:cells
    model:root.elements
    Item {
      id:cell
      required property var modelData
      readonly property var entry:root.entries.find(function(entry){return entry.id===modelData.id}) || null
      readonly property bool live:!!view.item && !!view.item.available
      readonly property bool hasBarAction: !!entry && !entry.moduleId && modelData.kind === "indicator"
          && modelData.id !== "reminders" && modelData.id !== "now"
      // The native bar intercepts left clicks for drag-to-reorder and forwards
      // them only to registered targets. Each live indicator owns its cell.
      readonly property bool interactive:!root.editing && visible && live && modelData.kind==="indicator"
      property var registeredBar:null
      function syncRegistration() {
        if (!root || !cell) return
        var next=interactive && modelData.id!=="now" && root.bar && root.bar.registerClickTarget ? root.bar : null
        if (next===registeredBar) return
        if (registeredBar) registeredBar.unregisterClickTarget(cell)
        registeredBar=next
        if (next) next.registerClickTarget(cell)
      }
      Component.onCompleted:Qt.callLater(syncRegistration)
      onInteractiveChanged:Qt.callLater(syncRegistration)
      Connections {target:root;function onBarChanged(){Qt.callLater(cell.syncRegistration)}}
      Component.onDestruction:if(registeredBar) registeredBar.unregisterClickTarget(cell)
      function triggerPress(button,point) {
        if (!interactive) return
        if (hasBarAction) {
          if (button===Qt.RightButton) root.quickAction(modelData.id)
          else if (button===Qt.LeftButton) root.activate(modelData.id)
        } else if (button===Qt.LeftButton) {
          if (entry && entry.moduleId) view.item.detailsRequested()
          else if (cell.modelData.id==="now") view.item.openAt(point ? view.item.mapFromItem(cell,point) : null)
          else view.item.clicked()
        }
      }
      readonly property real actionExtent: hasBarAction ? Style.space(24) : 0
      readonly property real cellWidth: Math.max(actionExtent,naturalWidth)
      readonly property real naturalHeight: live ? view.implicitHeight : root.editing ? root.barHeight : 0
      property alias view:view
      property alias button:selection
      visible:root.editing || modelData.kind!=="indicator" || live
      implicitWidth:root.editing ? root.barHeight : root.vertical ? Math.min(root.barSize-(hasBarAction ? 0 : Style.space(4)),cellWidth) : cellWidth
      readonly property real naturalWidth:modelData.kind==="space" ? Style.space(12) : modelData.kind==="separator" ? (root.vertical ? Style.space(16) : Style.space(1)) : live ? view.implicitWidth : root.editing ? placeholder.implicitWidth : 0
      implicitHeight: {
        if (root.editing) return root.barHeight
        if (modelData.kind==="space") return root.vertical ? Style.space(12) : root.barHeight
        if (modelData.kind==="separator") return root.vertical ? Style.space(1) : Style.space(16)
        return root.vertical ? Math.max(actionExtent,naturalHeight) : naturalHeight
      }
      Layout.alignment:Qt.AlignCenter
      z:drag.active ? 10 : 0
      transform:Translate {x:drag.active ? drag.translation.x : 0;y:drag.active ? drag.translation.y : 0}
      Loader {
        id:view
        transform:Translate {
          x:(root.editing || cell.hasBarAction) ? (cell.width-view.width)/2 : 0
          y:(root.editing || cell.hasBarAction) ? (cell.height-view.height)/2 : 0
        }
        enabled:!root.editing
        visible:cell.live && (!root.editing || (implicitWidth<=cell.width && implicitHeight<=cell.height))
        sourceComponent:cell.modelData.kind!=="indicator" ? null : cell.entry && cell.entry.moduleId ? moduleView : ({now:nowView,recording:recordingView,remote:remoteView,reminders:remindersView,update:updateView,microphone:microphoneView,dnd:dndView,nightLight:nightLightView,stayAwake:stayAwakeView})[cell.modelData.id] || null
      }
      IndicatorButton {
        objectName:"indicatorAction-"+cell.modelData.id
        anchors.centerIn:parent
        width:parent.width
        height:root.vertical ? parent.height : root.barHeight
        visible:!root.editing && cell.live && cell.hasBarAction
        focusable:true
        horizontalPadding:0;verticalPadding:0
        tooltipText:visible ? root.strings.t("indicator.action."+cell.modelData.id) : ""
        onClicked:root.activate(cell.modelData.id)
        onRightClicked:root.quickAction(cell.modelData.id)
      }
      PlainText {
        id:placeholder
        anchors.centerIn:parent
        visible:root.editing && cell.modelData.kind==="indicator" && !view.visible
        text:cell.entry ? cell.entry.icon : "◇"
        typeRole:"bar";color:Design.secondaryText
      }
      Rectangle {
        anchors.centerIn:parent
        visible:cell.modelData.kind==="separator"
        width:root.vertical ? Math.min(parent.width,Style.space(16)) : Math.max(1,Style.space(1))
        height:root.vertical ? Math.max(1,Style.space(1)) : Math.min(parent.height,Style.space(16))
        color:root.foreground;opacity:0.35
      }
      FeedbackButton {
        id:selection
        objectName:"clockElement-"+cell.modelData.id
        anchors.fill:parent
        z:-1
        selected:root.selectedId===cell.modelData.id; bordered:selected
        visible:root.editing;focusable:true
        tooltipText:root.title(cell.modelData)
        horizontalPadding:0;verticalPadding:0
        Accessible.name:tooltipText
        onClicked:root.selected(cell.modelData.id)
        onActiveFocusChanged:if(activeFocus) {root.selected(cell.modelData.id);root.revealFocus(this)}
        DragHandler {
          id:drag
          target:null
          onActiveChanged: {
            if(active) root.selected(cell.modelData.id)
            else root.dropped(cell.modelData.id,cell,translation.x,translation.y)
          }
        }
      }
      Component {
        id:moduleView
        ModuleSlot {
          viewSource:cell.entry.view
          backend:root.service && root.service.modules ? root.service.modules[cell.entry.moduleId] || null : null
          presentation:QtObject {
            readonly property var strings:root.strings
            readonly property bool vertical:root.vertical
            readonly property real barSize:root.barSize
            readonly property real barHeight:root.barHeight
            readonly property bool showAlert:root.showAlert
            readonly property var bar:root.bar
          }
          onDetailsRequested:cell.entry.pageIndex!==undefined ? root.pageRequested(cell.entry.pageIndex) : root.detailsRequested(cell.entry.moduleId)
        }
      }
      Component {
        id:nowView
        GridLayout {
          id:nowGroup
          columns:root.vertical ? 1 : 2
          columnSpacing:0
          rowSpacing:0
          readonly property var activity:root.activities[0] || null
          readonly property bool available:!!activity
          readonly property int otherCount:Math.max(0,root.activities.length-1)
          readonly property var description:NowPresentation.describe(activity,root.strings,Commons.I18n.formatNumber)
          LayoutMirroring.enabled: Commons.I18n.rightToLeft
          LayoutMirroring.childrenInherit: true
          function openPrimary() {if (activity && enabled) root.nowRequested(activity)}
          function openAt(point) {
            if (point && more.visible && more.contains(more.mapFromItem(nowGroup,point))) more.clicked()
            else openPrimary()
          }
          readonly property var clickBar:root.bar && root.bar.registerClickTarget ? root.bar : null
          property var registeredBar:null
          function registerButtons() {
            if (registeredBar===clickBar) return
            unregisterButtons()
            registeredBar=clickBar
            if (registeredBar) {registeredBar.registerClickTarget(primary);registeredBar.registerClickTarget(more)}
          }
          function unregisterButtons() {
            if (registeredBar) {registeredBar.unregisterClickTarget(more);registeredBar.unregisterClickTarget(primary)}
          }
          onClickBarChanged:Qt.callLater(registerButtons)
          Component.onCompleted:Qt.callLater(registerButtons)
          Component.onDestruction:unregisterButtons()
          onAvailableChanged:if (!available) root.nowHovered(false,null)
          IndicatorButton {
            id:primary
            objectName:"islandNowIndicator"
            focusable:true
            iconText:NowActivity.glyph(nowGroup.activity)
            text:root.vertical ? "" : nowGroup.description.label.replace(/\s+/g," ").trim()
            Accessible.name:[nowGroup.description.title,nowGroup.description.detail].filter(Boolean).join(" · ")
            foreground:root.foreground
            fontFamily:root.bar ? root.bar.fontFamily : Design.fontFamily
            iconSize:Design.type.bar
            fontSize:Design.type.bar
            horizontalPadding:Design.gap.tight
            verticalPadding:0
            implicitWidth:Math.min(_contentNaturalWidth+2*horizontalPadding+_reservedBorderLeft+_reservedBorderRight,
                                   root.vertical ? root.barSize : Style.space(136))
            implicitHeight:root.vertical ? Math.max(Design.inlineControlHeight,iconSize) : root.barHeight
            onClicked:nowGroup.openPrimary()
            function triggerPress(button) {if(button===Qt.LeftButton) clicked()}
            onHovered:inside=>root.nowHovered(inside && enabled && nowGroup.available,nowGroup.activity)
          }
          IndicatorButton {
            id:more
            objectName:"islandNowMore"
            visible:nowGroup.otherCount>0
            focusable:true
            text:"+"+Commons.I18n.formatNumber(nowGroup.otherCount)
            tooltipText:root.strings.t("now.other").arg(Commons.I18n.formatNumber(nowGroup.otherCount))
            Accessible.name:tooltipText
            foreground:root.foreground
            fontFamily:root.bar ? root.bar.fontFamily : Design.fontFamily
            fontSize:Design.type.bar
            horizontalPadding:Design.gap.tight
            verticalPadding:0
            Layout.maximumWidth:root.vertical ? root.barSize-Style.space(4) : implicitWidth
            implicitHeight:root.vertical ? Design.inlineControlHeight : root.barHeight
            onClicked:root.nowListRequested()
            function triggerPress(button) {if(button===Qt.LeftButton) clicked()}
          }
        }
      }
    Component {id:recordingView; StatusBeacon {id:recordingBeacon;objectName:"islandRecordingIndicator"; implicitHeight:root.vertical ? Style.space(18) : root.barHeight;property bool available:root.preference("indicatorRecording") && root.indicators && root.indicators.recording;tint:Design.barDanger;waveWidth:root.vertical ? 0 : Math.max(0,root.waveSpan-root.x-cell.x)}}
    Component {id:remoteView; StatusBeacon {id:remoteBeacon;objectName:"islandRemoteIndicator";implicitHeight:root.vertical ? Style.space(18) : root.barHeight;property bool available:root.preference("indicatorRemote") && root.indicators && root.indicators.remoteActive;tint:Design.barAccent;waveWidth:root.vertical ? 0 : Math.max(0,root.waveSpan-root.x-cell.x)}}
    Component {id:remindersView; IndicatorButton {
        objectName:"islandReminderIndicator"
        readonly property var reminders:root.service && ("reminders" in root.service) ? root.service.reminders : null
        property bool available:Settings.get(root.settings,"calendarEnabled") && !!reminders && reminders.count>0
        text:reminders ? "󰢌"+(root.vertical ? "\n" : " ")+Commons.I18n.formatNumber(reminders.count) : ""
        foreground:root.foreground;variant:"soft";fontSize:Design.type.bar
        width:root.vertical ? Math.min(implicitWidth,root.barSize-Style.space(4)) : implicitWidth
        implicitHeight:root.vertical ? fontSize*2.7 : root.barHeight
        horizontalPadding:root.vertical ? 0 : Design.gap.small;verticalPadding:0
        tooltipText:reminders && reminders.count ? reminders.rows[0].label+" · "+new Date(reminders.rows[0].at*1000).toLocaleString(Qt.locale(Commons.I18n.formatLocale),"d MMM HH:mm") : ""
        onClicked:root.calendarRequested()
      }}
    Component {id:updateView; StatusBeacon {
        id:updateBeacon
        objectName:"islandUpdateIndicator";
        implicitHeight:root.vertical ? Style.space(18) : root.barHeight
        property bool available:root.preference("indicatorUpdate") && !!root.indicators && !!root.indicators.updateAvailable
        tint:Commons.Color.foreground
        glyph:""
        bidirectional:true
        waveWidth:root.vertical ? 0 : root.waveSpan
        waveOffset:-root.x-cell.x
      }}
    Component {id:microphoneView; PlainText {objectName:"islandMicrophoneIndicator"; property bool available:root.preference("indicatorMicrophone") && root.indicators && root.indicators.microphoneMuted;text:"󰍭";font.pixelSize:Math.round(Style.font.icon*0.85);color:root.foreground}}
    Component {id:dndView; PlainText {objectName:"islandDndIndicator"; property bool available:root.preference("indicatorDnd") && root.service !== null && root.service.doNotDisturb;text:"󰂛";font.pixelSize:Math.round(Style.font.icon*0.85);color:root.foreground}}
    Component {id:nightLightView; PlainText {objectName:"islandNightLightIndicator"; property bool available:root.preference("indicatorNightLight") && root.indicators && root.indicators.nightLight;text:"󰔎";font.pixelSize:Math.round(Style.font.icon*0.85);color:root.foreground}}
    Component {id:stayAwakeView; PlainText {objectName:"islandStayAwakeIndicator"; property bool available:root.preference("indicatorStayAwake") && root.indicators && root.indicators.stayAwake;text:"";font.pixelSize:Math.round(Style.font.icon*0.85);color:root.foreground}}
    }
  }
  component IndicatorButton: FeedbackButton {
    focusOnClick:false
  }
}
