import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "ModuleCatalog.mjs" as Catalog
import "ClockLayout.mjs" as ClockLayout
import "SettingsModel.mjs" as Settings

GridLayout {
  id:root
  property var elements:[]
  property var service:null
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
  signal pageRequested(int index)
  signal detailsRequested()
  signal calendarRequested()
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
      property alias view:view
      property alias button:selection
      visible:root.editing || modelData.kind!=="indicator" || live
      implicitWidth:root.vertical ? Math.min(root.barSize-Style.space(4),naturalWidth) : naturalWidth
      readonly property real naturalWidth:modelData.kind==="space" ? Style.space(12) : modelData.kind==="separator" ? (root.vertical ? Style.space(16) : Style.space(1)) : live ? view.implicitWidth : root.editing ? placeholder.implicitWidth : 0
      implicitHeight:modelData.kind==="space" ? (root.vertical ? Style.space(12) : root.barHeight) : modelData.kind==="separator" ? (root.vertical ? Style.space(1) : Style.space(16)) : live ? view.implicitHeight : root.editing ? root.barHeight : 0
      Layout.alignment:Qt.AlignCenter
      z:drag.active ? 10 : 0
      transform:Translate {x:drag.active ? drag.translation.x : 0;y:drag.active ? drag.translation.y : 0}
      Loader {
        id:view
        enabled:!root.editing
        visible:cell.live
        sourceComponent:cell.modelData.kind!=="indicator" ? null : cell.entry && cell.entry.moduleId ? moduleView : ({recording:recordingView,remote:remoteView,reminders:remindersView,update:updateView,microphone:microphoneView,dnd:dndView,nightLight:nightLightView,stayAwake:stayAwakeView})[cell.modelData.id] || null
      }
      PlainText {
        id:placeholder
        anchors.centerIn:parent
        visible:root.editing && cell.modelData.kind==="indicator" && !cell.live
        text:cell.entry ? cell.entry.icon : "◇"
        typeRole:"bar";color:Design.secondaryText
      }
      Rectangle {
        anchors.centerIn:parent
        visible:cell.modelData.kind==="separator"
        width:root.vertical ? parent.width : Math.max(1,Style.space(1))
        height:root.vertical ? Math.max(1,Style.space(1)) : parent.height
        color:root.foreground;opacity:0.35
      }
      Rectangle {
        anchors.fill:parent;anchors.margins:-Style.space(3)
        visible:root.editing && (root.selectedId===cell.modelData.id || selection.activeFocus)
        color:"transparent";radius:Design.controlRadius
        border.width:1;border.color:Design.accent
      }
      FeedbackButton {
        id:selection
        objectName:"clockElement-"+cell.modelData.id
        anchors.fill:parent
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
          onDetailsRequested:cell.entry.pageIndex ? root.pageRequested(cell.entry.pageIndex) : root.detailsRequested()
        }
      }
    Component {id:recordingView; StatusBeacon {id:recordingBeacon;objectName:"islandRecordingIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activate("recording")} implicitHeight:root.vertical ? Style.space(18) : root.barHeight;property bool available:root.preference("indicatorRecording") && root.indicators && root.indicators.recording;tint:Design.barDanger;waveWidth:root.vertical ? 0 : Math.max(0,root.waveSpan-root.x-cell.x)}}
    Component {id:remoteView; StatusBeacon {id:remoteBeacon;objectName:"islandRemoteIndicator";implicitHeight:root.vertical ? Style.space(18) : root.barHeight;property bool available:root.preference("indicatorRemote") && root.indicators && root.indicators.remoteActive;tint:Design.barAccent;waveWidth:root.vertical ? 0 : Math.max(0,root.waveSpan-root.x-cell.x)}}
    Component {id:remindersView; FeedbackButton {
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
        objectName:"islandUpdateIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activate("update")}
        implicitHeight:root.vertical ? Style.space(18) : root.barHeight
        property bool available:root.preference("indicatorUpdate") && !!root.indicators && !!root.indicators.updateAvailable
        tint:Commons.Color.foreground
        glyph:""
        bidirectional:true
        waveWidth:root.vertical ? 0 : root.waveSpan
        waveOffset:-root.x-cell.x
      }}
    Component {id:microphoneView; PlainText {objectName:"islandMicrophoneIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activate("microphone")} property bool available:root.preference("indicatorMicrophone") && root.indicators && root.indicators.microphoneMuted;text:"󰍭";font.pixelSize:Math.round(Style.font.icon*0.85);color:root.foreground}}
    Component {id:dndView; PlainText {objectName:"islandDndIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activate("dnd")} property bool available:root.preference("indicatorDnd") && root.service !== null && root.service.doNotDisturb;text:"󰂛";font.pixelSize:Math.round(Style.font.icon*0.85);color:root.foreground}}
    Component {id:nightLightView; PlainText {objectName:"islandNightLightIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activate("nightLight")} property bool available:root.preference("indicatorNightLight") && root.indicators && root.indicators.nightLight;text:"󰔎";font.pixelSize:Math.round(Style.font.icon*0.85);color:root.foreground}}
    Component {id:stayAwakeView; PlainText {objectName:"islandStayAwakeIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activate("stayAwake")} property bool available:root.preference("indicatorStayAwake") && root.indicators && root.indicators.stayAwake;text:"";font.pixelSize:Math.round(Style.font.icon*0.85);color:root.foreground}}
    }
  }
}
