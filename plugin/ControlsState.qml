import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "controls"
import qs.Commons

Item {
  id:root
  property alias layoutState:layoutState
  LayoutState {id:layoutState;allowed:root.allowed}
  property bool active:false
  property bool allowed:true
  property var consumers:[]
  function watch(item,visible) {
    var next=consumers.filter(function(consumer){return consumer!==item})
    if(visible) next.push(item)
    consumers=next;active=allowed && consumers.length>0
  }
  onAllowedChanged:{active=allowed && consumers.length>0;if(!allowed) tailscaleAction.running=false}
  property var execute:function(command){Quickshell.execDetached(command)}
  property var systemCall:function(target,method,args){return IpcRegistry.call(target,method,args)}
  property var panelCommand:["python3",decodeURIComponent(Qt.resolvedUrl("controls/build-panel.py").toString().replace(/^file:\/\//,""))]
  property var outputCommand:["omarchy-audio-output-sink"]
  property var tailscaleCommand:["tailscale"]
  property var adapter:Bluetooth.defaultAdapter
  property var sink:Pipewire.defaultAudioSink
  property var nodes:Pipewire.nodes.values
  property var networking:Networking
  property string outputName:""
  property var output: {
    var nodes=root.nodes
    for(var i=0;i<nodes.length;i++) {
      var node=nodes[i]
      if(node && node.isSink && !node.isStream && node.name===outputName) return node
    }
    return sink
  }
  property bool tailscaleKnown:false
  property bool tailscaleEnabled:false
  function available(key) {
    if(!allowed) return false
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
      tailscaleAction.command=tailscaleCommand.concat(tailscaleEnabled ? ["down"] : ["up","--timeout=10s"])
      tailscaleAction.running=true
    }
  }
  function refresh() {
    if(!allowed || !active) return
    if(!resolveOutput.running) resolveOutput.running=true
    if(!tailscaleStatus.running && !tailscaleAction.running) tailscaleStatus.running=true
  }
  // Closing the page releases collectors, but a user-requested action may
  // finish in the background. Disabling the module cancels that action too.
  onActiveChanged:if(active) refresh();else {resolveOutput.running=false;tailscaleStatus.running=false}
  onSinkChanged:{outputName="";refresh()}
  PwObjectTracker {objects:root.active && root.output ? [root.output] : []}
  Timer {interval:2000;repeat:true;running:root.active;onTriggered:root.refresh()}
  Process {
    id:resolveOutput
    command:root.outputCommand
    property string result:""
    onStarted:result=""
    stdout:StdioCollector {onStreamFinished:resolveOutput.result=text.trim()}
    onExited:code=>{root.outputName=code===0 ? result : ""}
  }
  Process {
    id:tailscaleStatus
    command:root.tailscaleCommand.concat(["status","--json"])
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
    onExited:code=>{if(root.allowed && code!==0) root.actionFailed();root.refresh()}
  }
  signal actionFailed()
}
