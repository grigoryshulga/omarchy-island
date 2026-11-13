import QtQuick
import Quickshell.Io

// Each backend owns its path and schema. Retire its legacy fields only after
// a successful sanitized save; the helper serializes migration-only cleanup.
Item {
  id:root
  objectName:"moduleStorage"
  required property string path
  required property string legacyPath
  property bool enabled:true
  property bool ready:false
  property bool preparing:false
  property bool restartPending:false
  property string error:""
  property var clock:function(){return Date.now()/1000}
  property bool legacyPending:false
  property bool retired:false
  property bool cleaning:false
  property bool cleanupRestartPending:false
  readonly property bool settled:ready && (!legacyPending || retired)
  property var prepareCommand:["python3",String(Qt.resolvedUrl("bin/prepare-module-state")).replace(/^file:\/\//,"")]
  // Strings avoid QVariantList conversion across QML signals; models receive
  // ordinary JS arrays after parsing in their own context.
  signal loaded(string text,string status)
  function start(){if(enabled && !ready && !preparing) {preparing=true;prepare.running=true}}
  function save(data) {if(ready) file.setText(JSON.stringify(data))}
  function retire(){if(enabled && ready && legacyPending && !cleaning) {cleaning=true;cleanup.running=true}}
  onEnabledChanged: {
    if(enabled) {
      if(preparing) restartPending=true;else start()
      if(cleaning) cleanupRestartPending=true;else if(ready) retire()
    } else {restartPending=false;cleanupRestartPending=false;prepare.running=false;cleanup.running=false}
  }
  Component.onCompleted:start()
  Process {
    id:prepare
    command:root.prepareCommand.concat([root.path,root.legacyPath])
    property var result:null
    onStarted:result=null
    stdout:StdioCollector {waitForEnd:true;onStreamFinished:{try{prepare.result=JSON.parse(text)}catch(e){prepare.result=null}}}
    onExited:code=>{
      root.preparing=false
      // A terminated helper can exit after the next enable. Start the new
      // request only after that exit, rather than losing it or accepting stale data.
      if(root.restartPending) {root.restartPending=false;Qt.callLater(root.start);return}
      if(!root.enabled) return
      if(code!==0 || !result || !result.data) {root.error="state";return}
      root.error=result.status==="corrupt" ? "state" : ""
      root.legacyPending=!!result.legacyPending
      root.ready=true
      root.loaded(JSON.stringify(result.data),result.status)
    }
  }
  // Failed-to-start emits no exited signal. Bound the whole attempt, including
  // the interval before a process exists, and allow a later enable to retry.
  Timer {
    interval:5000;running:root.preparing
    onTriggered:{
      prepare.running=false;root.error="state"
      if(!(Number(prepare.processId)>0)) {root.preparing=false;root.restartPending=false}
    }
  }
  FileView {
    id:file
    path:root.ready ? root.path : ""
    atomicWrites:true
    blockWrites:true
    printErrors:false
    onSaved:if(!root.retired) root.retire()
    onSaveFailed:root.error="state"
  }
  Process {
    id:cleanup
    command:root.prepareCommand.concat([root.path,root.legacyPath,"retire",String(root.clock())])
    property var result:null
    onStarted:result=null
    stdout:StdioCollector {waitForEnd:true;onStreamFinished:{try{cleanup.result=JSON.parse(text)}catch(e){cleanup.result=null}}}
    onExited:code=>{
      root.cleaning=false
      if(root.cleanupRestartPending) {root.cleanupRestartPending=false;Qt.callLater(root.retire);return}
      if(!root.enabled) return
      if(code!==0 || !result) {root.error="state";return}
      root.legacyPending=!!result.legacyPending;root.retired=true
    }
  }
  Timer {interval:60000;repeat:true;running:root.enabled && root.ready && root.legacyPending;onTriggered:root.retire()}
  Timer {
    interval:5000;running:root.cleaning
    onTriggered:{cleanup.running=false;root.error="state";if(!(Number(cleanup.processId)>0)) {root.cleaning=false;root.cleanupRestartPending=false}}
  }
}
