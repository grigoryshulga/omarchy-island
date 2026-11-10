import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Commons as Commons
import "Osd.js" as Osd
import "osd-bridge/OsdModel.js" as NativeOsd

Item {
  id: root
  property var consumers: []
  property bool updateAvailable: false
  function refreshUpdate() {if(!updateProbe.running) updateProbe.running=true}
  function clearUpdate() {updateAvailable=false}
  property bool recording: false
  property bool remoteActive: false
  property bool nightLight: false
  property bool stayAwake: false
  property bool nightLightKnown: false
  property bool stayAwakeKnown: false
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("i18n")}
  function announceMode(mode,on) {
    var icons={dnd:on ? "󰂛" : "󰂚",nightLight:"󰔎",stayAwake:""}
    showOsd(JSON.stringify({icon:icons[mode],message:strings.t("osd."+mode+(on ? ".on" : ".off")),duration:1400}))
  }
  readonly property var microphone: Pipewire.defaultAudioSource
  readonly property bool microphoneMuted: !!microphone && (UntypedInput.active ? (UntypedInput.known && UntypedInput.muted) : (!!microphone.audio && microphone.audio.muted))
  property bool downloading: false
  function showDownload() {if(downloading && !osdActive) showOsd(JSON.stringify({icon:"download",message:"Downloading file...",duration:0}))}
  onDownloadingChanged: {if(downloading) showDownload();else if(osdKind==="download") hideOsd()}
  onOsdActiveChanged: if(!osdActive && downloading) Qt.callLater(showDownload)
  property bool osdActive: false
  property string osdKind: "volume"
  property real osdValue: 0
  property bool osdMuted: false
  property bool osdHasProgress: true
  property string osdIcon: ""
  property string osdMessage: ""
  property string osdProgressText: ""
  property string osdScreen: ""
  property int osdSerial: 0

  function attach(item) {if(consumers.indexOf(item)<0) consumers=consumers.concat([item]);refresh();showDownload()}
  function detach(item) {consumers=consumers.filter(function(c){return c!==item});if(!consumers.length) hideOsd()}
  function status(target) {
    var reply=IpcRegistry.call(target,"status",[])
    try {return reply.ran ? JSON.parse(reply.output) : {}} catch(e) {return {}}
  }
  function refreshControls() {
    var night=status("nightlight").enabled,awake=status("idle").stayAwake
    if(typeof night==="boolean") {
      if(nightLightKnown && night!==nightLight) announceMode("nightLight",night)
      nightLight=night;nightLightKnown=true
    }
    if(typeof awake==="boolean") {
      if(stayAwakeKnown && awake!==stayAwake) announceMode("stayAwake",awake)
      stayAwake=awake;stayAwakeKnown=true
    }
  }
  function refresh() {
    if(!consumers.length) return
    refreshControls()
    if(!recordingProbe.running) recordingProbe.running=true
    if(!remoteProbe.running) remoteProbe.running=true
  }
  function hideOsd() {osdLife.stop();osdActive=false}
  function showOsd(raw) {
    if(!consumers.length) return false
    var next=Osd.parse(raw)
    if(!next) return false
    osdValue=next.value
    osdKind=next.kind
    osdMuted=next.muted
    osdHasProgress=next.hasProgress
    osdIcon=next.kind==="layout" ? "󰌌" : NativeOsd.iconFor(next.iconName,next.hasProgress ? Math.round(next.value*100) : -1)
    osdMessage=next.message
    osdProgressText=next.progressText
    osdScreen=Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    osdActive=true;osdSerial++
    osdLife.stop()
    if(next.duration>0) {osdLife.interval=next.duration;osdLife.start()}
    return true
  }
  readonly property alias layouts:layoutState
  KeyboardLayoutState {
    id:layoutState
    active:root.consumers.length>0
    onSwitched:language=>root.showOsd(JSON.stringify({icon:"layout",message:language,duration:1200}))
  }
  PwObjectTracker {objects:root.microphone ? [root.microphone] : []}
  Timer {id:osdLife;interval:1200;onTriggered:root.osdActive=false}
  Timer {interval:500;repeat:true;running:root.consumers.length>0;onTriggered:root.refreshControls()}
  Timer {interval:root.recording || root.remoteActive ? 2000 : 10000;repeat:true;running:root.consumers.length>0;onTriggered:root.refresh()}
  Connections {target:Hyprland;function onRawEvent(event) {if(event && event.name==="screencast") captureChange.restart()}}
  Timer {id:captureChange;interval:150;onTriggered:root.refresh()}
  FileView {
    path:Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR")+"/omarchy-screenrecord-pid" : ""
    watchChanges:true;printErrors:false
    onFileChanged:{reload();captureChange.restart()}
    onLoaded:captureChange.restart()
    onLoadFailed:captureChange.restart()
  }
  // Match the default widget's six-hour check; package changes refresh sooner.
  Timer {interval:21600000;repeat:true;triggeredOnStart:true;running:root.consumers.length>0;onTriggered:root.refreshUpdate()}
  FileView {
    path:"/var/log/pacman.log"
    watchChanges:true;printErrors:false
    onFileChanged: {reload();updateDebounce.restart()}
  }
  Timer {id:updateDebounce;interval:3000;onTriggered:if(root.consumers.length) root.refreshUpdate()}
  Process {
    id:updateProbe
    command:["omarchy-update-available"]
    // QProcess::NormalExit is 0; Quickshell does not export its enum.
    onExited:(code,status)=>{if(status===0 && (code===0 || code===1)) root.updateAvailable=code===0}
  }
  Process {
    id:recordingProbe
    command:["omarchy-capture-screenrecording","--status"]
    onExited:code=>{if(code===0 || code===1) root.recording=code===0}
  }
  Process {
    id:remoteProbe
    command:["bash",(Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/shell/plugins/services/remote-session/probe.sh"]
    property string output: ""
    onStarted:output=""
    stdout:StdioCollector {waitForEnd:true;onStreamFinished:remoteProbe.output=text}
    onExited:code=>Qt.callLater(function(){if(code===0) root.remoteActive=remoteProbe.output.split("\n").some(function(line){return /^\d+(?:\s|$)/.test(line.trim())})})
  }
  Timer {interval:6000;running:recordingProbe.running || remoteProbe.running;onTriggered:{recordingProbe.running=false;remoteProbe.running=false}}
}
