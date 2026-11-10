import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Dictation.js" as Model

Item {
  id: root
  property bool active: true
  property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  property string mode: "idle"
  readonly property bool recording: mode==="recording"
  readonly property bool showing: active && mode!=="idle"
  property string screenName: ""
  property real peak: 0
  property double lastFrame: 0
  property double startedAt: 0
  property int elapsed: 0
  property var history: Model.empty()
  onModeChanged: {
    peak=0;lastFrame=0
    if(recording) {history=Model.empty();startedAt=Date.now();elapsed=0}
    if(mode!=="idle" && screenName==="") screenName=Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    if(mode==="idle") screenName=""
  }
  onActiveChanged: {if(!active) mode="idle";else stateFile.reload()}
  FileView {
    id: stateFile
    path: root.runtimeDir ? root.runtimeDir+"/voxtype/state" : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.mode=root.active ? Model.state(text()) : "idle"
    onLoadFailed: root.mode="idle"
  }
  // Also recover when the daemon creates/replaces a previously absent file.
  Timer {interval:1000;running:root.active;repeat:true;onTriggered:stateFile.reload()}
  Timer {
    interval:50;running:root.active && root.recording;repeat:true
    onTriggered: {
      root.history=Model.push(root.history,Date.now()-root.lastFrame<400 ? root.peak : 0)
      root.elapsed=Math.floor((Date.now()-root.startedAt)/1000)
    }
  }
  Process {
    id: audio
    running: root.active && root.recording && !retry.running
    // Connect to Voxtype's own meter; never open a second microphone stream.
    command:["voxtype-audio-bridge"]
    stdout:SplitParser {onRead:line=>{
      var level=Model.frame(line)
      if(level!==null) {root.peak=level;root.lastFrame=Date.now()}
    }}
    onExited: {root.peak=0;if(root.active && root.recording) retry.restart()}
  }
  Timer {id:retry;interval:2000}
}
