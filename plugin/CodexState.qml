import QtQuick

AgentSessionState {
  id:root
  bridgeCommand:["python3",String(Qt.resolvedUrl("bin/codex-bridge")).replace(/^file:\/\//,"")]
  allowed:Preferences.get("codexEnabled")
  responsesEnabled:Preferences.get("codexResponses")
  property var actions:({})
  property int serial:0
  function actionStatus(key) {return actions[key] ? actions[key].status : ""}
  function act(operation, id, text, cwd) {
    var key=id || "new",state=actionStatus(key)
    if(state==="sending" || state==="uncertain") return false
    var token=String(++serial),next=Object.assign({},actions)
    if(!sendCommand({type:"action",operation:operation,threadId:id || "",text:text || "",cwd:cwd || "",actionId:token})) return false
    next[key]={id:token,status:"sending",startedAt:Date.now()};actions=next;return true
  }
  function openThread(id) {} // Session titles expand details; no external URI is assumed.
  function receive(line) {
    if(line.length>4194304) return
    var event
    try {event=JSON.parse(line)} catch(e) {return}
    if(event.type!=="action") {receiveSession(line);return}
    var next=Object.assign({},actions)
    for(var key in next) if(next[key].id===event.actionId) next[key]={id:event.actionId,status:event.status,startedAt:0}
    actions=next
  }
  function expireActions() {
    var next=Object.assign({},actions),changed=false
    for(var key in next) if(next[key].status==="sending" && (!connected || Date.now()-next[key].startedAt>20000)) {
      next[key]={id:next[key].id,status:"uncertain",startedAt:0};changed=true
    }
    if(changed) actions=next
  }
  Timer {interval:1000;repeat:true;running:Object.keys(root.actions).some(function(k){return root.actionStatus(k)==="sending"});onTriggered:root.expireActions()}
}
