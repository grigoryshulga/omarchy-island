import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire

Item {
  id:root
  property bool active:false
  property var execute:function(command){Quickshell.execDetached(command)}
  property var adapter:Bluetooth.defaultAdapter
  readonly property var sink:Pipewire.defaultAudioSink
  property var networking:Networking
  property string outputName:""
  property var output: {
    var nodes=Pipewire.nodes.values
    for(var i=0;i<nodes.length;i++) {
      var node=nodes[i]
      if(node && node.isSink && !node.isStream && node.name===outputName) return node
    }
    return sink
  }
  property bool tailscaleKnown:false
  property bool tailscaleEnabled:false
  function available(key) {
    if(key==="audio") return !!(output && output.audio)
    if(key==="bluetooth") return !!adapter
    if(key==="network") return networking.backend===NetworkBackendType.NetworkManager
    if(key==="tailscale") return tailscaleKnown
    return false
  }
  function enabledState(key) {
    if(key==="audio") return !!(output && output.audio && !output.audio.muted)
    if(key==="bluetooth") return !!(adapter && adapter.enabled)
    if(key==="network") return networking.wifiEnabled
    if(key==="tailscale") return tailscaleEnabled
    return false
  }
  function toggle(key) {
    if(!available(key)) return
    if(key==="audio") output.audio.muted=!output.audio.muted
    else if(key==="bluetooth") execute(["omarchy-bluetooth-power",adapter.enabled ? "off" : "on"])
    else if(key==="network") networking.wifiEnabled=!networking.wifiEnabled
    else if(key==="tailscale" && !tailscaleAction.running) {
      tailscaleAction.command=tailscaleEnabled ? ["tailscale","down"] : ["tailscale","up","--timeout=10s"]
      tailscaleAction.running=true
    }
  }
  function refresh() {
    if(!active) return
    if(!resolveOutput.running) resolveOutput.running=true
    if(!tailscaleStatus.running && !tailscaleAction.running) tailscaleStatus.running=true
  }
  onActiveChanged:if(active) refresh()
  onSinkChanged:{outputName="";refresh()}
  PwObjectTracker {objects:root.active && root.output ? [root.output] : []}
  Timer {interval:2000;repeat:true;running:root.active;onTriggered:root.refresh()}
  Process {
    id:resolveOutput
    command:["omarchy-audio-output-sink"]
    property string result:""
    onStarted:result=""
    stdout:StdioCollector {onStreamFinished:resolveOutput.result=text.trim()}
    onExited:code=>{root.outputName=code===0 ? result : ""}
  }
  Process {
    id:tailscaleStatus
    command:["tailscale","status","--json"]
    property string result:""
    onStarted:result=""
    stdout:StdioCollector {onStreamFinished:tailscaleStatus.result=text}
    onExited:code=>{
      root.tailscaleKnown=false
      if(code!==0) return
      try {
        var state=JSON.parse(result).BackendState
        root.tailscaleKnown=state==="Running" || state==="Stopped"
        root.tailscaleEnabled=state==="Running"
      } catch(e) {}
    }
  }
  Process {
    id:tailscaleAction
    onExited:code=>{if(code!==0) root.actionFailed();root.refresh()}
  }
  signal actionFailed()
}
