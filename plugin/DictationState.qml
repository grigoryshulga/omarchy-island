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
  property string source: ""
  property int sessionId: 0
  readonly property bool recording: mode==="recording"
  readonly property bool showing: active && mode!=="idle"
  property string screenName: ""
  property string voxtypeMode: "idle"
  property string superwhisperMode: "idle"
  property real voxtypePeak: 0
  property double voxtypeFrameAt: 0
  property real superwhisperPeak: 0
  property double startedAt: 0
  property int elapsed: 0
  property var history: Model.empty()

  function updateSession() {
    // Keep the current source through transcription if both providers are active.
    var nextSource=active ? Model.source(source,voxtypeMode,superwhisperMode) : ""
    var nextMode=nextSource==="voxtype" ? voxtypeMode : nextSource==="superwhisper" ? superwhisperMode : "idle"
    var switching=nextSource!==source
    if(switching) {
      screenName=nextSource && Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }
    var starting=nextMode==="recording" && (switching || mode!=="recording")
    if(switching || starting) {
      history=Model.empty()
      elapsed=0
    }
    if(starting) startedAt=Date.now()
    source=nextSource
    mode=nextMode
    if(starting || (switching && nextSource)) sessionId++
  }

  onVoxtypeModeChanged: updateSession()
  onSuperwhisperModeChanged: updateSession()
  onActiveChanged: {
    if(active) stateFile.reload()
    else {
      voxtypeMode="idle"
      superwhisperMode="idle"
      superwhisperPeak=0
      retry.stop()
    }
  }
  FileView {
    id: stateFile
    path: root.active && root.runtimeDir ? root.runtimeDir+"/voxtype/state" : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.voxtypeMode=root.active ? Model.state(text()) : "idle"
    onLoadFailed: root.voxtypeMode="idle"
  }
  // Also recover when the daemon creates/replaces a previously absent file.
  Timer {interval:1000;running:root.active;repeat:true;onTriggered:stateFile.reload()}
  Timer {
    interval:50;running:root.active && root.recording;repeat:true
    onTriggered: {
      var now=Date.now()
      var peak=root.source==="superwhisper" ? root.superwhisperPeak
        : now-root.voxtypeFrameAt<400 ? root.voxtypePeak : 0
      root.history=Model.push(root.history,peak)
      root.elapsed=Math.floor((now-root.startedAt)/1000)
    }
  }
  Process {
    id: audio
    readonly property bool wanted: root.active && root.recording && root.source==="voxtype"
    running: wanted && !retry.running
    // Connect to Voxtype's own meter; never open a second microphone stream.
    command:["voxtype-audio-bridge"]
    stdout:SplitParser {onRead:line=>{
      var level=Model.frame(line)
      if(audio.wanted && level!==null) {root.voxtypePeak=level;root.voxtypeFrameAt=Date.now()}
    }}
    onWantedChanged: {
      root.voxtypeFrameAt=0
      if(!wanted) retry.stop()
    }
    onExited: {root.voxtypeFrameAt=0;if(wanted) retry.restart()}
  }
  Timer {id:retry;interval:2000}
  Loader {
    active: root.active
    sourceComponent: Item {
      Process {
        running: !observerRetry.running
        command: ["python3", decodeURIComponent(String(Qt.resolvedUrl("bin/superwhisper-dictation")).replace(/^file:\/\//,""))]
        stdout: SplitParser { onRead: line => {
          if(!root.active) return
          var update=Model.superwhisper(line)
          if(update===null) return
          root.superwhisperPeak=update.peak
          root.superwhisperMode=update.mode
        } }
        onExited: {
          root.superwhisperPeak=0
          root.superwhisperMode="idle"
          observerRetry.restart()
        }
      }
      Timer {id:observerRetry;interval:30000}
    }
  }
}
