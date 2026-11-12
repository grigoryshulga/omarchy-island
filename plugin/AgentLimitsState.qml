import QtQuick
import Quickshell
import Quickshell.Io
import "AgentLimitsModel.js" as Model

Item {
  id:root
  property bool allowed:Preferences.get("agentLimitsEnabled") && Preferences.get("overviewEnabled")
  property string collector:String(Qt.resolvedUrl("bin/agent-limits-sync")).replace(/^file:\/\//,"")
  property string statePath:(Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME")+"/.local/state")+"/omarchy/agent-limits/data.json"
  property var cache:({schemaVersion:1,providers:[],state:"loading"})
  property var catalog:[]
  property var automatic:[]
  property double now:Date.now()
  property string error:""
  property var rows:Model.windows(error ? Object.assign({},cache,{state:"error"}) : cache,now)
  readonly property var pins:Preferences.get("agentLimitsPins")
  readonly property var summary:Model.summary(rows,pins,automatic,Preferences.get("agentLimitsMode"))
  readonly property var tightest:Model.tightest(rows)
  readonly property bool busy:sync.running || configure.running
  readonly property bool indicatorVisible:allowed && Preferences.get("agentLimitsIndicator")!=="off" && !!tightest && (Preferences.get("agentLimitsIndicator")==="always" || tightest.remaining<=Preferences.get("agentLimitsWarning"))
  onRowsChanged:automatic=Model.attention(rows,automatic,Preferences.get("agentLimitsWarning"))
  Connections {target:Preferences;function onValuesChanged(){root.automatic=Model.attention(root.rows,root.automatic,Preferences.get("agentLimitsWarning"))}}
  function refresh() {if(allowed && !busy) sync.running=true}
  function loadCatalog() {if(allowed && !configure.running) {configure.command=[collector,"providers"];configure.running=true}}
  function change(id,action,secret,region) {
    if(!allowed || busy || !catalog.some(function(p){return p.id===id}) || ["enable","disable","up","down","connect"].indexOf(action)<0) return
    if(action==="connect" && (!/^[A-Za-z_][A-Za-z0-9_.-]{0,99}$/.test(secret) || ["global","cn"].indexOf(region)<0)) return
    configure.command=[collector,"configure",id,action].concat(action==="connect" ? ["--secret-name",secret,"--region",region] : [])
    configure.running=true
  }
  Component.onCompleted:if(allowed) {loadCatalog();refresh()}
  onAllowedChanged: {
    if(allowed) {snapshot.reload();loadCatalog();refresh()}
    else {sync.running=false;configure.running=false;cache=({schemaVersion:1,providers:[],state:"loading"});automatic=[];catalog=[];error=""}
  }
  FileView {
    id:snapshot
    path:root.allowed ? root.statePath : ""
    watchChanges:root.allowed
    printErrors:false
    onFileChanged:if(root.allowed) reload()
    onLoaded: {
      if(!root.allowed) return
      var next=Model.parse(text())
      if(next) {root.cache=next;if(next.state!=="error" && root.error!=="sync" && root.error!=="configure") root.error=""}
      else root.error="invalid"
    }
    onLoadFailed:if(root.allowed) root.error="missing"
  }
  Process {
    id:sync
    command:[root.collector,"sync"]
    onExited:(code,status)=>{if(root.allowed) {root.error=code!==0 ? "sync" : "";snapshot.reload()}}
  }
  Process {
    id:configure
    stdout:StdioCollector {
      onStreamFinished: {
        if(!root.allowed) return
        try {root.catalog=JSON.parse(text).providers || []} catch(e) {root.error="configure"}
      }
    }
    onExited:(code,status)=>{
      if(!root.allowed) return
      if(code!==0) root.error="configure"
      else if(command[1]==="configure") {root.error="";root.refresh()}
      else root.refresh()
    }
  }
  // Poll as well as watching: the shared writer replaces the inode atomically.
  Timer {interval:15000;repeat:true;running:root.allowed;onTriggered:{root.now=Date.now();snapshot.reload()}}
  Timer {interval:300000;repeat:true;running:root.allowed;triggeredOnStart:true;onTriggered:root.refresh()}
}
