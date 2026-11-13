import QtQuick
import Quickshell.Io
import "ReminderModel.js" as Model
import "Security.js" as Security

Item {
  id:root
  property bool allowed:true
  property var command:["omarchy-reminder"]
  property var clock:function(){return Date.now()/1000}
  onAllowedChanged:if(!allowed) {reader.running=false;action.running=false}else refresh()
  property var snapshot:[]
  property double now:clock()
  readonly property var rows:snapshot.filter(function(row){return row.at>root.now})
  readonly property int count:rows.length
  readonly property bool busy:action.running
  property string error:""
  signal created()
  function refresh() {if(allowed && !reader.running) reader.running=true}
  function create(minutes,message) {
    var args=Security.reminderArgs(minutes,message)
    if(!allowed || !args.length || busy) return false
    error="";action.command=command.concat(args);action.creating=true;action.running=true
    return true
  }
  function clear() {
    if(!allowed || busy) return
    error="";action.command=command.concat(["clear"]);action.creating=false;action.running=true
  }
  Process {
    id:reader
    command:root.command.concat(["show","--json"])
    running:root.allowed
    property var result:null
    onStarted:result=null
    stdout:StdioCollector {onStreamFinished:{try {reader.result=JSON.parse(text)} catch(e) {reader.result=null}}}
    onExited:code=>Qt.callLater(function(){
      if(!root.allowed) return
      root.now=root.clock()
      if(code===0 && result && Array.isArray(result.reminders)) {root.snapshot=Model.rows(result,root.now);root.error=""}
      else root.error="reminders.unavailable"
    })
  }
  Process {
    id:action
    property bool creating:false
    onExited:code=>{
      if(!root.allowed) return
      if(code===0) {if(creating) root.created();root.refresh()}
      else root.error="reminders.failed"
    }
  }
  Timer {interval:10000;running:root.allowed;repeat:true;onTriggered:root.refresh()}
  Timer {interval:1000;running:root.allowed && root.snapshot.length>0;repeat:true;onTriggered:root.now=root.clock()}
}
