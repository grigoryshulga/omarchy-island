import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.Commons

Item {
  id: root
  property var consumers: []
  property bool recording: false
  property bool remoteActive: false
  property bool nightLight: false
  property bool stayAwake: false
  readonly property var microphone: Pipewire.defaultAudioSource
  readonly property bool microphoneMuted: !!microphone && (UntypedInput.active ? (UntypedInput.known && UntypedInput.muted) : (!!microphone.audio && microphone.audio.muted))
  property bool osdActive: false
  property string osdKind: "volume"
  property real osdValue: 0
  property bool osdMuted: false
  property string osdScreen: ""
  property int osdSerial: 0

  function attach(item) {if(consumers.indexOf(item)<0) consumers=consumers.concat([item]);refresh()}
  function detach(item) {consumers=consumers.filter(function(c){return c!==item})}
  function status(target) {
    var reply=IpcRegistry.call(target,"status",[])
    try {return reply.ran ? JSON.parse(reply.output) : {}} catch(e) {return {}}
  }
  function refreshControls() {
    nightLight=status("nightlight").enabled===true
    stayAwake=status("idle").stayAwake===true
  }
  function refresh() {
    if(!consumers.length) return
    refreshControls()
    if(!recordingProbe.running) recordingProbe.running=true
    if(!remoteProbe.running) remoteProbe.running=true
  }
  function showOsd(raw) {
    if(!consumers.length || typeof raw!=="string" || raw.length>8192) return false
    try {
      var data=JSON.parse(raw),key=String(data.icon || "").toLowerCase()
      var kind=key.indexOf("volume")===0 ? "volume" : key==="brightness" || key==="display" ? "brightness" : ""
      if(!kind || data.message || data.value===null || data.value===undefined || String(data.value).trim()==="") return false
      if(typeof data.value!=="number" && typeof data.value!=="string") return false
      if(data.max!==undefined && typeof data.max!=="number" && typeof data.max!=="string") return false
      var value=Number(data.value),maximum=data.max===undefined || data.max==="" ? 100 : Number(data.max)
      if(!isFinite(value) || !isFinite(maximum) || maximum<=0) return false
      osdValue=Math.max(0,Math.min(1,value/maximum))
      osdKind=kind
      osdMuted=kind==="volume" && key.indexOf("mute")>=0
      osdScreen=Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      osdActive=true;osdSerial++
      var duration=Number(data.duration)
      osdLife.interval=isFinite(duration) && duration>0 ? Math.max(600,Math.min(5000,duration)) : 1200
      osdLife.restart()
      return true
    } catch(e) {return false}
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
