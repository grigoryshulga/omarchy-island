import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Downloads.js" as Downloads

Item {
  id:root
  property bool allowed:true
  property var latest:null
  property bool restored:false
  property string error:""
  property var clock:function(){return Date.now()}
  property var execute:function(argv){Util.execArgv(argv)}
  property var watcherCommand:["python3",String(Qt.resolvedUrl("bin/watch-downloads")).replace(/^file:\/\//,"")]
  property string stateDir:Quickshell.env("HOME")+"/.local/state/omarchy/island"
  property alias storageCommand:storage.prepareCommand
  signal completed(var row)
  signal changed()
  function restore(rows) {downloads=Downloads.retain(rows,downloadsDir,clock()/1000);restored=true;save();startWatching()}
  function save(){if(restored) storage.save({version:1,downloads:snapshot()})}
  function startWatching() {if(allowed && restored && !downloadWatcher.running) downloadWatcher.running=true}
  function snapshot() {return Downloads.retain(downloads,downloadsDir,clock()/1000)}
  function remove(key) {downloads=downloads.filter(function(row){return row.key!==key});changed()}
  onAllowedChanged:if(!allowed) {save();saveSoon.stop();downloadRetry.stop();downloadWatcher.running=false;activeDownloads=0;downloads=downloads.filter(function(row){return !row.active})} else startWatching()
  onChanged:{if(latest && !downloads.some(function(row){return row.key===root.latest.key})) latest=null;saveSoon.restart()}
  property string downloadsDir: Quickshell.env("HOME") + "/downloads"
  property var downloads: []
  property int activeDownloads: 0
  property int downloadSequence: 0
  function downloadEvent(data) {
    if(!allowed || !restored) return
    var event
    try {event=JSON.parse(data)} catch(e) {return}
    if(!event || typeof event!=="object") return
    if(event.event==="active" && Array.isArray(event.files)) {
      var previous=downloads
      var active=event.files.filter(function(f){return f && Downloads.validPath(f.path,root.downloadsDir)}).map(function(f){
        var old=previous.find(function(r){return r.active && r.downloadPath===f.path})
        return Downloads.row(f.path,old ? old.ts : clock()/1000,f.bytes,true)
      })
      downloads=active.concat(downloads.filter(function(r){return !r.active}))
      activeDownloads=active.length
    } else if(event.event==="complete" && Downloads.validPath(event.path,downloadsDir)) {
      var row=Downloads.row(event.path,clock()/1000+(++downloadSequence)/1000000,event.bytes,false)
      var remaining=downloads.filter(function(r){return r.downloadPath!==event.path})
      downloads=remaining.filter(function(r){return r.active}).concat(Downloads.retain([row].concat(remaining.filter(function(r){return !r.active})),downloadsDir,clock()/1000))
      latest=row;completed(row)
      changed()
    }
  }
  function openDownload(row) {
    if(!allowed || !Downloads.validPath(row.downloadPath,downloadsDir)) return false
    execute(["xdg-open",row.downloadPath.substring(0,row.downloadPath.lastIndexOf("/"))])
    if(!row.active) remove(row.key)
    return true
  }
  Process {
    id:downloadWatcher
    command:root.watcherCommand.concat([root.downloadsDir])
    stdout:SplitParser {onRead:data=>root.downloadEvent(data)}
    onExited:code=>{root.activeDownloads=0;root.downloads=root.downloads.filter(function(r){return !r.active});if(root.allowed && root.restored) {if(code!==0) root.error="download watcher";downloadRetry.restart()}}
  }
  Timer {id:downloadRetry;interval:5000;onTriggered:root.startWatching()}
  Timer {id:saveSoon;interval:300;onTriggered:root.save()}
  ModuleStorage {
    id:storage;enabled:root.allowed
    clock:function(){return root.clock()/1000}
    path:root.stateDir+"/downloads.json";legacyPath:root.stateDir+"/state.json"
    onLoaded:(text,status)=>{var data=JSON.parse(text);root.restore(data.downloads || (status==="legacy" ? data.recents : []) || [])}
    onErrorChanged:if(error || root.error==="state") root.error=error
  }
  Component.onDestruction:save()

  Timer {
    interval:1000;repeat:true;running:root.allowed && root.restored && root.downloads.length>0
    onTriggered:{var kept=root.downloads.filter(function(row){return row.active || row.ts>root.clock()/1000-1800});if(kept.length!==root.downloads.length) {root.downloads=kept;root.changed()}}
  }
}
