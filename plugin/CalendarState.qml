import QtQuick
import Quickshell.Io
import "CalendarEvents.js" as Model
import "Security.js" as Security

Item {
  id:root
  property bool allowed:true
  property bool activated:false
  property int year:new Date().getFullYear()
  property var sources:[]
  property var events:[]
  property string error:""
  property bool pending:false
  property bool pendingForce:false
  readonly property bool busy:worker.running
  readonly property var eventDays:Model.days(events)
  readonly property bool hasEnabled:sources.some(function(source){return source.enabled})
  signal saved()
  function activate(value) {
    if(!allowed) return
    activated=true
    if(year!==value) {year=value;events=[]}
    refresh(false)
  }
  function refresh(force) {
    if(!allowed || !activated) return
    if(busy) {pending=true;pendingForce=pendingForce || force;return}
    run({command:"snapshot",refresh:!!force})
  }
  function run(request) {
    if(!allowed || busy) return false
    request.year=year;worker.request=request;worker.result=null;error=""
    worker.running=true
    return true
  }
  function add(name,url) {
    var safe=Security.calendarUrl(String(url).trim())
    if(!safe) {error="url";return false}
    return run({command:"add",name:name,url:safe})
  }
  function toggle(id,enabled) {return run({command:"toggle",id:id,enabled:enabled})}
  function remove(id) {return run({command:"remove",id:id})}
  onAllowedChanged:if(!allowed) {worker.running=false;pending=false;pendingForce=false;events=[]} else if(activated) refresh(false)
  Process {
    id:worker
    command:["python3",String(Qt.resolvedUrl("bin/calendar-data")).replace(/^file:\/\//,"")]
    stdinEnabled:true
    property var request:({})
    property var result:null
    onStarted:write(JSON.stringify(request)+"\n")
    stdout:StdioCollector {waitForEnd:true;onStreamFinished:worker.result=Model.parse(text)}
    onExited:code=>Qt.callLater(function(){
      if(!root.allowed) return
      var report=worker.result
      if(code!==0 || !report) root.error="unavailable"
      else if(report.error) root.error=report.error
      else {
        root.sources=report.sources
        if(report.year===root.year) root.events=report.events
        if(worker.request.command==="add") root.saved()
      }
      worker.request=({})
      if(root.pending) {var force=root.pendingForce;root.pending=false;root.pendingForce=false;root.refresh(force)}
    })
  }
  Timer {interval:60000;running:worker.running;onTriggered:{worker.running=false;root.error="unavailable"}}
  Timer {interval:900000;repeat:true;running:root.allowed && root.activated && root.hasEnabled;onTriggered:root.refresh(false)}
}
