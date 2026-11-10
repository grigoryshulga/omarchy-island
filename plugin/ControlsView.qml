import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "controls/monitors" as NativeMonitors
import "controls/audio" as NativeAudio
import "controls/bluetooth" as NativeBluetooth
import "controls/network" as NativeNetwork
import "controls/tailscale" as NativeTailscale

Item {
  id:root
  required property var service
  required property var strings
  property var bar:null
  property var settings:({})
  property var externalFeedback:null
  property bool active:false
  property string section:""
  property string error:""
  property bool changing:false
  property real detailHeight:0
  property string hoveredTile:""
  readonly property real cursorIntensity:active && (hoveredTile!=="" || (!!section && nativeHover.hovered)) ? 2.2 : 1
  function tileHover(name,on) {if(on) hoveredTile=name;else if(hoveredTile===name) hoveredTile=""}
  readonly property var indicators:service && ("indicators" in service) ? service.indicators : null
  readonly property var microphone:indicators ? indicators.microphone : null
  property var execute:function(command){Quickshell.execDetached(command)}
  property var systemCall:function(target,method,args){return IpcRegistry.call(target,method,args)}
  signal dismissRequested()
  signal settingRequested(string key, var value)
  implicitHeight:section ? detailHeight : landing.implicitHeight

  function openSection(name) {
    if(["audio","bluetooth","network","tailscale","monitors"].indexOf(name)<0) return
    if(!section) detailHeight=landing.implicitHeight
    changing=true
    if(nativeLoader.item) nativeLoader.item.close()
    section=name;error=""
    changing=false
    if(nativeLoader.item) Qt.callLater(function(){if(nativeLoader.item && root.active) nativeLoader.item.open()})
  }
  function launchExternalPanel(id,payload) {
    if(["omarchy.wifiqr","omarchy.speedtest"].indexOf(id)<0) return
    dismissRequested()
    execute(["omarchy-shell","shell","summon",id,payload])
  }
  function back() {
    changing=true
    if(nativeLoader.item) nativeLoader.item.close()
    section="";error=""
    changing=false
  }
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
  onActiveChanged: {
    changing=true
    if(nativeLoader.item) {if(active) nativeLoader.item.open();else nativeLoader.item.close()}
    changing=false
  }
  ColumnLayout {
    id:landing
    anchors.left:parent.left;anchors.right:parent.right
    visible:!root.section
    spacing:Style.space(12)
    GridLayout {
      objectName:"controlMainGrid"
      Layout.fillWidth:true
      columns:2
      uniformCellWidths:true
      columnSpacing:Style.space(8);rowSpacing:Style.space(8)
      Repeater {
        model:[{key:"audio",icon:"󰕾"},{key:"bluetooth",icon:"󰂯"},{key:"network",icon:"󰤨"},{key:"tailscale",icon:"󰖂"},{key:"monitors",icon:"󰍺"}]
        ControlTile {
        onHovered:on=>root.tileHover(objectName,on)
          required property var modelData
          objectName:"controlOpen-"+modelData.key
          Layout.fillWidth:true
          feedback:root.externalFeedback
          title:root.strings.t("controls."+modelData.key)
          description:root.strings.t("controls."+modelData.key+"Hint")
          glyph:modelData.icon
          drillDown:true
          onClicked:root.openSection(modelData.key)
        }
      }
    }
    PanelSeparator {Layout.fillWidth:true}
    GridLayout {
      objectName:"controlQuickGrid"
      Layout.fillWidth:true
      columns:3
      uniformCellWidths:true
      columnSpacing:Style.space(8);rowSpacing:Style.space(8)
      ControlTile {
        onHovered:on=>root.tileHover(objectName,on)
        compact:true
        objectName:"controlMicrophone";Layout.fillWidth:true;feedback:root.externalFeedback
        title:root.strings.t("controls.microphone");glyph:"󰍭"
        description:root.microphone ? root.modeState(root.indicators.microphoneMuted) : root.strings.t("controls.noMicrophone")
        selected:root.indicators && root.indicators.microphoneMuted
        enabled:!!root.microphone
        onClicked:root.toggleMode("microphone")
      }
      ControlTile {
        onHovered:on=>root.tileHover(objectName,on)
        compact:true
        objectName:"controlDnd";Layout.fillWidth:true;feedback:root.externalFeedback
        title:root.strings.t("controls.dndShort");glyph:"󰂛"
        description:root.modeState(root.service && root.service.doNotDisturb)
        selected:root.service && root.service.doNotDisturb
        onClicked:root.toggleMode("dnd")
      }
      ControlTile {
        onHovered:on=>root.tileHover(objectName,on)
        compact:true
        objectName:"controlNightLight";Layout.fillWidth:true;feedback:root.externalFeedback
        title:root.strings.t("indicator.nightLight");glyph:"󰔎"
        description:root.modeState(root.indicators && root.indicators.nightLight)
        selected:root.indicators && root.indicators.nightLight
        onClicked:root.toggleMode("nightLight")
      }
      ControlTile {
        onHovered:on=>root.tileHover(objectName,on)
        compact:true
        objectName:"controlStayAwake";Layout.fillWidth:true;feedback:root.externalFeedback
        title:root.strings.t("controls.stayAwakeShort");glyph:""
        description:root.modeState(root.indicators && root.indicators.stayAwake)
        selected:root.indicators && root.indicators.stayAwake
        onClicked:root.toggleMode("stayAwake")
      }
      ControlTile {
        onHovered:on=>root.tileHover(objectName,on)
        compact:true
        objectName:"controlRecording";Layout.fillWidth:true;feedback:root.externalFeedback
        title:root.strings.t("controls.recordingShort");glyph:"󰻂"
        description:root.strings.t(root.indicators && root.indicators.recording ? "controls.stopRecording" : "controls.startRecording")
        selected:root.indicators && root.indicators.recording
        glyphColor:selected ? "#f7768e" : Commons.Color.foreground
        onClicked:root.toggleMode("recording")
      }
      ControlTile {
        onHovered:on=>root.tileHover(objectName,on)
        compact:true
        objectName:"controlRemote";Layout.fillWidth:true
        title:root.strings.t("controls.remoteShort");glyph:"󰢹"
        description:root.strings.t(root.indicators && root.indicators.remoteActive ? "controls.connected" : "controls.noConnection")
        selected:root.indicators && root.indicators.remoteActive
        glyphColor:selected ? "#9ece6a" : Commons.Color.muted
        enabled:false
      }
    }
    PlainText {Layout.fillWidth:true;visible:root.error!=="";text:root.error;color:Commons.Color.urgent;wrapMode:Text.Wrap;font.pixelSize:Style.font.caption}
  }
  Loader {
    id:nativeLoader
    objectName:"islandNativeControl"
    anchors.fill:parent
    active:root.active && !!root.section
    visible:active
    HoverHandler {id:nativeHover}
    sourceComponent:root.section==="audio" ? audioPanel : root.section==="bluetooth" ? bluetoothPanel : root.section==="network" ? networkPanel : root.section==="tailscale" ? tailscalePanel : root.section==="monitors" ? monitorsPanel : null
    onLoaded:{item.open();Qt.callLater(function(){if(nativeLoader.item) nativeLoader.item.focusContent()})}
    onStatusChanged:if(status===Loader.Error) root.error=root.strings.t("controls.unavailable")
    TapHandler {
      acceptedButtons:Qt.LeftButton | Qt.RightButton
      gesturePolicy:TapHandler.DragThreshold
      onTapped:eventPoint=>{if(root.externalFeedback) root.externalFeedback.pulseFrom(nativeLoader,eventPoint.position)}
    }
  }
  Component {id:monitorsPanel;NativeMonitors.Panel {bar:root.bar}}
  Component {id:audioPanel;NativeAudio.Panel {bar:root.bar}}
  Component {id:bluetoothPanel;NativeBluetooth.Panel {bar:root.bar}}
  Component {id:networkPanel;NativeNetwork.Panel {bar:root.bar;onExternalPanelRequested:(id,payload)=>root.launchExternalPanel(id,payload)}}
  Component {id:tailscalePanel;NativeTailscale.Panel {bar:root.bar;settings:root.settings;onPreferencesRequested:regions=>root.settingRequested("recentMullvadRegions",regions)}}
  Connections {
    target:nativeLoader.item
    function onOpenedChanged(){
      var item=nativeLoader.item
      if(!root.changing && item && !item.opened && root.active)
        Qt.callLater(function(){if(!root.changing && nativeLoader.item===item && !item.opened && root.active) root.back()})
    }
  }
  PlainText {anchors.centerIn:parent;visible:!!root.section && nativeLoader.status===Loader.Error;text:root.error;color:Commons.Color.urgent;wrapMode:Text.Wrap}
}
