import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import Quickshell.Io
import "controls"
import "controls/Layout.js" as ControlLayout

Item {
  id:root
  required property var service
  required property var strings
  property var bar:null
  property var settings:({})
  property var externalSettings:({})
  readonly property var nativeSettings:section.indexOf("plugin:")===0 ? externalSettings : settings
  property var externalFeedback:null
  property bool active:false
  property bool favoriteMode:false
  property bool favoritesInteractive:true
  signal sectionRequested(string key)
  signal allRequested()
  property bool editing:false
  property bool adding:false
  readonly property alias addMenuContent:addPopup.contentItem
  function configure() {
    if(!layoutState || !layoutState.ready) return
    editing=!editing;adding=false
    if(editing) {
      if(controlLayout.hidden.indexOf(editableGrid.selectedKey)>=0 || controlLayout.order.indexOf(editableGrid.selectedKey)<0) editableGrid.selectedKey=ControlLayout.tiles(controlLayout)[0].key
      refreshCatalog()
    } else editableGrid.focusTile(editableGrid.selectedKey)
  }
  function addControl(key) {
    layoutState.add(key);editableGrid.selectedKey=key;adding=false
    editableGrid.focusTile(key)
  }
  function showAdd() {adding=!adding;if(adding) {refreshCatalog();Qt.callLater(function(){pluginSearch.forceActiveFocus()})}}
  function addableControls(query) {
    var rows=controlLayout.hidden.map(function(key){return {key:key,name:root.controlTitle(key)}})
    externalControls.forEach(function(row){if(root.controlLayout.order.indexOf(row.key)<0 && !rows.some(function(x){return x.key===row.key})) rows.push(row)})
    query=String(query).toLowerCase().trim()
    return rows.filter(function(row){return row.name.toLowerCase().indexOf(query)>=0 || row.key.toLowerCase().indexOf(query)>=0})
  }
  function enabledState(key) {
    if(key==="dnd") return !!service && service.doNotDisturb
    if(key==="microphone") return !!indicators && indicators.microphoneMuted
    if(key==="remote") return !!indicators && indicators.remoteActive
    if(["nightLight","stayAwake","recording"].indexOf(key)>=0) return !!indicators && !!indicators[key]
    return !!controlState && controlState.enabledState(key)
  }
  property string section:""
  property string error:""
  property bool changing:false
  property real detailHeight:0
  readonly property bool settingsOwnKeys:section==="settings" && settingsPage.ownsKeys
  readonly property var indicators:service && ("indicators" in service) ? service.indicators : null
  readonly property var microphone:indicators ? indicators.microphone : null
  property var execute:function(command){}
  property var systemCall:function(target,method,args){return {ran:false}}
  property var panelCommand:[]
  property var controlState:null
  readonly property var layoutState:controlState && ("layoutState" in controlState) ? controlState.layoutState : null
  readonly property var controlLayout:layoutState ? layoutState.layout : ControlLayout.normalize({})
  property var externalControls:[]
  function controlTitle(key) {
    if(key.indexOf("plugin:")===0) {
      for(var i=0;i<externalControls.length;i++) if(externalControls[i].key===key) return externalControls[i].name
      return key.slice(7)
    }
    var shortKeys=["dnd","stayAwake","recording"]
    return strings.t(key==="nightLight" ? "indicator.nightLight" : "controls."+key+(shortKeys.indexOf(key)>=0 ? "Short" : ""))
  }
  function refreshCatalog() {
    if(!panelCommand.length || catalogBuilder.running) return
    catalogBuilder.command=panelCommand.concat(["--catalog"]);catalogBuilder.running=true
  }
  Process {
    id:catalogBuilder
    property string result:""
    onStarted:result=""
    stdout:StdioCollector {onStreamFinished:catalogBuilder.result=text}
    onExited:code=>{
      if(code!==0) {if(root.active) root.error=root.strings.t("controls.unavailable");return}
      try {root.externalControls=JSON.parse(result)} catch(e) {root.error=root.strings.t("controls.unavailable")}
    }
  }
  Connections {
    target:root.controlState
    ignoreUnknownSignals:true
    function onActionFailed(){root.error=root.strings.t("controls.unavailable")}
  }
  signal dismissRequested()
  signal settingRequested(string key, var value)
  implicitHeight:favoriteMode ? favorites.implicitHeight : section ? detailHeight : landing.implicitHeight

  function openSection(name) {
    if(name==="customize") {configure();return}
    if(favoriteMode) {sectionRequested(name);return}
    if(["audio","bluetooth","network","tailscale","monitors","settings"].indexOf(name)<0 && controlLayout.main.indexOf(name)<0) return
    editing=false;adding=false
    if(!section) detailHeight=landing.implicitHeight
    changing=true
    if(nativeLoader.item) nativeLoader.item.close()
    nativeLoader.source=""
    section=name;error=""
    changing=false
    if(name==="settings") Qt.callLater(function(){settingsPage.focusContent()})
    else requestPanel()
  }
  function launchExternalPanel(id,payload) {
    if(["omarchy.wifiqr","omarchy.speedtest"].indexOf(id)<0) return
    dismissRequested()
    execute(["omarchy-shell","shell","summon",id,payload])
  }
  function back() {
    if(adding) {adding=false;return}
    if(editing) {configure();return}
    var previous=section
    settingsPage.closeEditors()
    changing=true
    if(nativeLoader.item) nativeLoader.item.close()
    nativeLoader.source=""
    section="";error=""
    changing=false
    Qt.callLater(function(){
      if(!root.active || root.section) return
      editableGrid.focusTile(previous)
    })
  }
  onFavoriteModeChanged:if(favoriteMode) back()
  function modeState(enabled) {return strings.t(enabled ? "controls.on" : "controls.off")}
  function toggleMode(mode) {
    error=""
    if(mode==="microphone") {
      if(!microphone) return
      execute(["omarchy-audio-input-mute"])
    } else if(mode==="dnd") {
      if(service) service.setDoNotDisturb(!service.doNotDisturb)
    } else if(mode==="nightLight" || mode==="stayAwake") {
      var reply=systemCall(mode==="nightLight" ? "nightlight" : "idle","toggle",[])
      if(!reply || !reply.ran) error=strings.t("controls.unavailable")
      if(indicators && ("refreshControls" in indicators)) indicators.refreshControls()
    } else if(mode==="recording") {
      var recording=indicators && indicators.recording
      dismissRequested()
      execute(recording ? ["omarchy-capture-screenrecording","--stop-recording"] : ["omarchy-menu","toggle","trigger.capture.screenrecord"])
    }
  }
  property string buildingSection:""
  property string buildOutput:""
  property string buildError:""
  function requestPanel() {
    if(!active || !section || (section==="settings") || panelBuilder.running) return
    if(!panelCommand.length) {error=strings.t("controls.unavailable");return}
    buildingSection=section;buildOutput="";buildError=""
    panelBuilder.command=panelCommand.concat([section])
    panelBuilder.running=true
  }
  onActiveChanged: {
    changing=true
    if(!active) {
      editing=false;adding=false
      panelBuilder.running=false
      settingsPage.closeEditors()
      if(nativeLoader.item) nativeLoader.item.close()
      nativeLoader.source=""
    } else requestPanel()
    changing=false
  }
  Process {
    id:panelBuilder
    stdout:StdioCollector {onStreamFinished:root.buildOutput=text}
    stderr:StdioCollector {onStreamFinished:root.buildError=text}
    onExited:(code,status)=>{
      if(!root.active || !root.section) return
      if(root.buildingSection!==root.section) {root.requestPanel();return}
      if(code!==0) {root.error=root.strings.t("controls.unavailable");console.warn("Island Controls:",root.buildError);return}
      try {
        var result=JSON.parse(root.buildOutput)
        if(typeof result.url!=="string" || result.url.indexOf("file://")!==0) throw new Error("Invalid panel URL")
        root.externalSettings=result.settings || ({})
        nativeLoader.setSource(result.url,{bar:embeddedBar,settings:root.nativeSettings})
      } catch(error) {root.error=root.strings.t("controls.unavailable");console.warn("Island Controls:",error)}
    }
  }
  QtObject {
    id:embeddedShell
    function firstPartyServiceFor(id) {return root.bar && root.bar.shell ? root.bar.shell.firstPartyServiceFor(id) : null}
    function summon(id,payload) {
      if(id==="omarchy.wifiqr" || id==="omarchy.speedtest") {root.launchExternalPanel(id,payload);return true}
      if(root.bar && root.bar.shell && typeof root.bar.shell.summon==="function") return root.bar.shell.summon(id,payload)
      return false
    }
    function updateEntryInline(id,entry) {
      if(id!=="omarchy.tailscale") return false
      root.settingRequested("recentMullvadRegions",entry.recentMullvadRegions)
      return true
    }
  }
  PluginBarApi {
    id:embeddedBar
    pluginId:root.section.indexOf("plugin:")===0 ? root.section.slice(7) : "gshulga.island"
    moduleName:pluginId==="gshulga.island" ? "gshulga.island.controls" : pluginId
    shell:embeddedShell
    foreground:Design.text
    barForeground:foreground
    background:Design.opaqueCanvas
    urgent:Design.danger
    fontFamily:Design.fontFamily
    _moduleWidgets:function(id){return root.bar && typeof root.bar.moduleWidgets==="function" ? root.bar.moduleWidgets(id) : []}
    _run:function(command){if(root.bar) root.bar.run(command)}
  }
  RowLayout {
    id:favorites
    objectName:"controlFavorites"
    anchors.left:parent.left;anchors.right:parent.right
    visible:root.favoriteMode
    spacing:Design.gap.tight
    Flickable {
      Layout.fillWidth:true
      implicitHeight:Design.controlHeight
      contentWidth:favoriteRow.implicitWidth;contentHeight:height
      flickableDirection:Flickable.HorizontalFlick
      boundsBehavior:Flickable.StopAtBounds;clip:true
      RowLayout {
        id:favoriteRow;height:parent.height;spacing:Design.gap.tight
        Repeater {
          model:root.controlLayout.favorites
          FeedbackButton {
            required property string modelData
            objectName:"controlFavorite-"+modelData
            implicitWidth:Design.controlHeight;implicitHeight:Design.controlHeight
            iconText:({audio:"󰕾",bluetooth:"󰂯",network:"󰤨",tailscale:"󰖂",monitors:"󰍺",settings:"󰒓",microphone:"󰍭",dnd:"󰂛",nightLight:"󰔎",stayAwake:"",recording:"󰻂",remote:"󰢹"})[modelData] || "󰒓"
            tooltipText:root.controlTitle(modelData);focusable:true;feedback:root.externalFeedback
            selected:root.controlState && root.controlState.enabledState(modelData)
              || modelData==="dnd" && root.service && root.service.doNotDisturb
              || modelData==="nightLight" && root.indicators && root.indicators.nightLight
              || modelData==="stayAwake" && root.indicators && root.indicators.stayAwake
              || modelData==="recording" && root.indicators && root.indicators.recording
              || modelData==="microphone" && root.indicators && root.indicators.microphoneMuted
            enabled:root.favoritesInteractive && modelData!=="remote" && (modelData!=="microphone" || !!root.microphone)
            onClicked: {
              if(ControlLayout.quickDefaults.indexOf(modelData)>=0) root.toggleMode(modelData)
              else root.openSection(modelData)
            }
            onRightClicked: {
              if(ControlLayout.quickDefaults.indexOf(modelData)>=0) clicked()
              else if(root.controlState) root.controlState.toggle(modelData)
            }
          }
        }
      }
    }
    FeedbackButton {
      objectName:"controlAll"
      iconText:Commons.I18n.rightToLeft ? "󰅁" : "󰅂"
      tooltipText:root.strings.t("controls.all");focusable:true;feedback:root.externalFeedback
      onClicked:root.allRequested()
    }
  }
  ColumnLayout {
    id:landing
    anchors.left:parent.left;anchors.right:parent.right
    visible:!root.section && !root.favoriteMode
    spacing:Design.gap.section
    EditableGrid {id:editableGrid;Layout.fillWidth:true;host:root}

    PlainText {Layout.fillWidth:true;visible:root.error!=="";text:root.error;color:Design.danger;wrapMode:Text.Wrap;typeRole:"caption"}
  }
  Controls.Popup {
    id:addPopup
    parent:root
    x:Math.max(0,root.width-width);y:0
    width:Math.min(root.width,Style.space(360))
    padding:Design.gap.small
    visible:root.adding && root.editing && root.active
    focus:true
    closePolicy:Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    onClosed:{root.adding=false;editableGrid.focusTile(editableGrid.selectedKey)}
    background:BorderSurface {color:Design.opaqueCanvas;radius:Design.controlRadius;borderSpec:Border.flat(Design.fieldBorder,1)}
    contentItem:ColumnLayout {
      DesignTextField {id:pluginSearch;objectName:"controlPluginSearch";Layout.fillWidth:true;placeholderText:root.strings.t("controls.searchPlugins");Accessible.name:placeholderText}
      Flickable {
        id:addViewport
        Layout.fillWidth:true;implicitHeight:Math.min(Style.space(200),addRows.implicitHeight)
        contentWidth:width;contentHeight:addRows.implicitHeight;clip:true
        boundsBehavior:Flickable.StopAtBounds
        ColumnLayout {
          id:addRows;width:parent.width
          Repeater {
            model:root.addableControls(pluginSearch.text)
            FeedbackButton {
              required property var modelData
              objectName:"controlAdd-"+modelData.key
              Layout.fillWidth:true;text:modelData.name;iconText:"+";focusable:true;feedback:root.externalFeedback
              onActiveFocusChanged:if(activeFocus) {
                var at=mapToItem(addRows,0,0).y
                if(at<addViewport.contentY) addViewport.contentY=at
                else if(at+height>addViewport.contentY+addViewport.height) addViewport.contentY=at+height-addViewport.height
              }
              onClicked:root.addControl(modelData.key)
            }
          }
          PlainText {visible:root.addableControls(pluginSearch.text).length===0;text:root.strings.t("controls.noPlugins");typeRole:"caption"}
        }
      }
    }
  }
  Loader {
    id:nativeLoader
    objectName:"islandNativeControl"
    anchors.left:parent.left;anchors.right:parent.right
    anchors.top:detailBack.bottom;anchors.bottom:parent.bottom
    anchors.topMargin:Design.gap.small
    active:root.active && !!root.section && root.section!=="settings"
    visible:active
    onLoaded:{item.settings=Qt.binding(function(){return root.nativeSettings});item.open();Qt.callLater(function(){if(nativeLoader.item) nativeLoader.item.focusContent()})}
    onStatusChanged:if(status===Loader.Error) root.error=root.strings.t("controls.unavailable")
    TapHandler {
      acceptedButtons:Qt.LeftButton | Qt.RightButton
      gesturePolicy:TapHandler.DragThreshold
      onTapped:eventPoint=>{if(root.externalFeedback) root.externalFeedback.pulseFrom(nativeLoader,eventPoint.position)}
    }
  }
  ControlBackButton {
    id:detailBack
    visible:!!root.section
    anchors.top:parent.top
    onClicked:root.back()
  }
  PlainText {
    anchors.left:detailBack.right;anchors.leftMargin:Design.gap.medium
    anchors.verticalCenter:detailBack.verticalCenter
    visible:root.section==="settings"
    typeRole:"section"
    text:root.strings.t("settings.title")
  }
  SettingsView {
    id:settingsPage
    objectName:"islandSettings"
    anchors.left:parent.left;anchors.right:parent.right
    anchors.top:detailBack.bottom;anchors.bottom:parent.bottom
    anchors.topMargin:Design.gap.small
    visible:root.section==="settings"
    active:root.active && root.section==="settings"
    settings:root.settings;strings:root.strings
    modules:root.service && root.service.modules ? root.service.modules : ({})
    feedback:root.externalFeedback
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
  }
  Connections {
    target:nativeLoader.item
    function onOpenedChanged(){
      var item=nativeLoader.item
      if(!root.changing && item && !item.opened && root.active)
        Qt.callLater(function(){if(!root.changing && nativeLoader.item===item && !item.opened && root.active) root.back()})
    }
  }
  PlainText {anchors.centerIn:parent;visible:!!root.section && root.error!=="";text:root.error;color:Design.danger;wrapMode:Text.Wrap}
}
