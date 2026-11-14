import QtQuick
import Quickshell
import Quickshell.Io
import "HerdrModel.js" as Herdr

Item {
  id:root
  property bool allowed:Preferences.get("herdrEnabled")
  property bool remoteEnabled:Preferences.get("herdrRemote")
  property var snapshotCommand:["python3",String(Qt.resolvedUrl("bin/herdr-snapshot")).replace(/^file:\/\//,"")]
  property bool accepting:false
  property bool snapshotReceived:false
  property var sources:[]
  property var alertBaseline:({})
  readonly property var rows:sources.reduce(function(all,source){return all.concat(source.rows || [])},[])
  readonly property int waitingCount:rows.filter(function(r){return r.status==="blocked"}).length
  readonly property int workingCount:rows.filter(function(r){return r.status==="working"}).length
  signal activityChanged(var session)
  function receive(data) {
    if(!allowed || !accepting || data.length>4194304) return
    try {
      var event=JSON.parse(data)
      if(!Array.isArray(event.sources)) return
      var result=Herdr.transitions(alertBaseline,event.sources)
      snapshotReceived=true
      sources=event.sources;alertBaseline=result.baseline
      if(result.alerts.length) activityChanged(result.alerts[0])
    } catch(e) {}
  }
  function refresh() {
    if(allowed && !reader.running) {accepting=true;snapshotReceived=false;reader.running=true}
  }
  function reset() {
    accepting=false;sources=[];alertBaseline=({});retry.stop()
    if(reader.running) reader.running=false
    else if(allowed) retry.restart()
  }
  onAllowedChanged:reset()
  onRemoteEnabledChanged:reset()
  Process {
    id:reader
    command:root.snapshotCommand.concat(root.remoteEnabled ? ["--remote"] : [])
    running:root.allowed
    onStarted: {root.accepting=true;root.snapshotReceived=false}
    onExited: {
      if(root.allowed && root.accepting && !root.snapshotReceived) {
        root.sources=[{id:"collector",label:"Herdr",status:"unavailable",rows:[]}]
        root.alertBaseline=({})
      }
      if(root.allowed && !root.accepting) retry.restart()
    }
    stdout:StdioCollector {onStreamFinished:root.receive(text)}
  }
  Timer {id:retry;interval:100;onTriggered:root.refresh()}
  Timer {interval:5000;repeat:true;running:root.allowed;onTriggered:root.refresh()}
}
