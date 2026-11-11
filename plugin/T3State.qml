import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Security.js" as Security
import "T3Model.js" as T3

Item {
  id:root
  property bool allowed:Preferences.get("t3Enabled")
  property bool responsesEnabled:Preferences.get("t3Responses")
  property string status:"offline"
  property string environmentId:""
  property bool canRespond:false
  property var rows:[]
  property var responses:({})
  property var alertBaseline:null
  signal activityChanged(var session)
  onConnectedChanged:if(!connected) alertBaseline=null
  readonly property bool connected:allowed && status==="connected"
  readonly property int waitingCount:connected ? rows.filter(function(r){return !!r.requestId}).length : 0
  readonly property int workingCount:connected ? rows.filter(function(r){return T3.busy(r) && !r.requestId}).length : 0
  function row(id) {return rows.find(function(r){return r.id===id}) || null}
  function response(id) {return responses[id] ? responses[id].status : ""}
  function receive(line) {
    if(line.length>4194304) return
    var event
    try {event=JSON.parse(line)} catch(e) {return}
    if(event.type==="connection") {
      status=event.status
      canRespond=event.status==="connected" && event.canRespond===true
      if(event.environmentId) environmentId=event.environmentId
      if(status!=="connected") failPending()
    } else if(event.type==="sessions" && Array.isArray(event.rows)) {
      var nextRows=event.rows.slice(0,30)
      var changes=T3.transitions(alertBaseline,nextRows)
      rows=nextRows
      alertBaseline=nextRows
      // Prefer an input request or failure when several threads change together.
      changes.sort(function(a,b){return (b.requestId ? 2 : b.status==="failed" ? 1 : 0)-(a.requestId ? 2 : a.status==="failed" ? 1 : 0)})
      if(changes.length && connected) activityChanged(changes[0])
      var keep={}
      rows.forEach(function(r){if(r.requestId && root.responses[r.requestId]) keep[r.requestId]=root.responses[r.requestId]})
      responses=keep
    } else if(event.type==="response" && typeof event.requestId==="string") {
      if(!rows.some(function(r){return r.requestId===event.requestId})) return
      var next=Object.assign({},responses);next[event.requestId]={status:event.status,startedAt:0};responses=next
    }
  }
  function failPending() {
    var next=Object.assign({},responses)
    for(var id in next) if(next[id].status==="sending") next[id]={status:"uncertain",startedAt:0}
    responses=next
  }
  function expireResponses(now) {
    var next=Object.assign({},responses),changed=false
    for(var id in next) if(next[id].status==="sending" && now-next[id].startedAt>=20000) {
      next[id]={status:"uncertain",startedAt:0};changed=true
    }
    if(changed) responses=next
  }
  function submit(id,request,answers) {
    var current=row(id),state=request ? response(request.id) : ""
    if(!connected || !canRespond || !responsesEnabled || !reader.running || !current || !request || !request.canRespond || !current.request || current.request.revision!==request.revision || ["sending","sent","uncertain"].indexOf(state)>=0) return false
    var next=Object.assign({},responses);next[request.id]={status:"sending",startedAt:Date.now()};responses=next
    reader.write(JSON.stringify({type:"respond",threadId:id,requestId:request.id,revision:request.revision,answers:answers})+"\n")
    return true
  }
  function openThread(id) {
    var url=Security.t3ThreadUrl(environmentId,id)
    if(url && row(id)) Util.execArgv(["xdg-open",url])
  }
  function restart() {
    canRespond=false;failPending()
    if(reader.running) reader.running=false
    else if(allowed) retry.restart()
  }
  onAllowedChanged: {
    if(allowed) {status="connecting";reader.running=true}
    else {retry.stop();reader.running=false;rows=[];responses=({});status="offline";canRespond=false}
  }
  onResponsesEnabledChanged:restart()
  Process {
    id:reader
    command:["python3",String(Qt.resolvedUrl("bin/t3-bridge")).replace(/^file:\/\//,"")].concat(root.responsesEnabled ? [] : ["--read-only"])
    running:root.allowed
    stdinEnabled:true
    stdout:SplitParser {onRead:data=>root.receive(data)}
    onExited:{root.status="offline";root.canRespond=false;root.failPending();if(root.allowed) retry.restart()}
  }
  Timer {id:retry;interval:2000;onTriggered:if(root.allowed) reader.running=true}
  Timer {
    interval:1000;repeat:true
    running:root.allowed && Object.keys(root.responses).some(function(id){return root.response(id)==="sending"})
    onTriggered:root.expireResponses(Date.now())
  }
}
