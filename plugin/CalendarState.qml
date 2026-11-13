import QtQuick
import Quickshell.Io
import "CalendarEvents.js" as Model
import "Security.js" as Security

Item {
  id:root
  property bool allowed:true
  property var helperCommand:["python3",String(Qt.resolvedUrl("bin/calendar-data")).replace(/^file:\/\//,"")]
  property bool activated:false
  property int year:new Date().getFullYear()
  property var sources:[]
  property var reports:({})
  property var reportOrder:[]
  property var queue:[]
  property string error:""
  property bool settling:false
  readonly property bool busy:worker.running || settling
  readonly property var events:eventsForYear(year)
  readonly property var eventDays:Model.days(events)
  readonly property bool hasEnabled:sources.some(function(source){return source.enabled})
  signal saved()
  function eventsForYear(value) {
    var enabled=sources.filter(function(s){return s.enabled}).map(function(s){return s.id})
    return (reports[value] || []).filter(function(e){return enabled.indexOf(e.sourceId)>=0})
  }
  function daysForYear(value) {return Model.days(eventsForYear(value))}
  function activate(value) {
    if(!allowed) return
    activated=true;year=value;requestYear(value,false)
  }
  function requestYear(value,force) {
    if(!allowed || !activated) return
    if(!busy) {run({command:"snapshot",year:value,refresh:!!force});return}
    var next=queue.slice(),index=next.findIndex(function(item){return item.year===value})
    if(index>=0) next[index]={year:value,force:next[index].force || force}
    else next.push({year:value,force:!!force})
    queue=next.slice(-8)
  }
  function refresh(force) {
    requestYear(year,force)
    reportOrder.forEach(function(value){if(value!==root.year) root.requestYear(value,false)})
  }
  function run(request) {
    if(!allowed || busy) return false
    if(request.year===undefined) request.year=year
    worker.request=request;worker.result=null;error=""
    settling=true;worker.running=true
    return true
  }
  function add(name,url) {
    var safe=Security.calendarUrl(String(url).trim())
    if(!safe) {error="url";return false}
    return run({command:"add",name:name,url:safe})
  }
  function toggle(id,enabled) {return run({command:"toggle",id:id,enabled:enabled})}
  function remove(id) {return run({command:"remove",id:id})}
  onAllowedChanged:if(!allowed) {worker.running=false;queue=[];reports=({});reportOrder=[]} else if(activated) refresh(false)
  Process {
    id:worker
    command:root.helperCommand
    stdinEnabled:true
    property var request:({})
    property var result:null
    onStarted:write(JSON.stringify(request)+"\n")
    stdout:StdioCollector {waitForEnd:true;onStreamFinished:worker.result=Model.parse(text)}
    onExited:code=>Qt.callLater(function(){
      if(!root.allowed) {root.settling=false;return}
      var report=worker.result
      if(code!==0 || !report) root.error="unavailable"
      else if(report.error) root.error=report.error
      else {
        root.sources=report.sources
        // Keep independent year reports for calendars opened on other monitors.
        var order=root.reportOrder.filter(function(y){return y!==report.year}).concat([report.year]).slice(-8),cache={}
        order.forEach(function(y){cache[y]=y===report.year ? report.events : root.reports[y]})
        root.reports=cache;root.reportOrder=order
        if(worker.request.command!=="snapshot") {
          order.forEach(function(y){if(y!==report.year) root.requestYear(y,false)})
          if(worker.request.command==="add") root.saved()
        }
      }
      worker.request=({});root.settling=false
      if(root.queue.length) {var next=root.queue[0];root.queue=root.queue.slice(1);root.requestYear(next.year,next.force)}
    })
  }
  Timer {interval:60000;running:root.busy;onTriggered:{worker.running=false;root.settling=false;root.error="unavailable"}}
  Timer {interval:900000;repeat:true;running:root.allowed && root.activated && root.hasEnabled;onTriggered:root.refresh(false)}
}
