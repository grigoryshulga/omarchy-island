import QtQuick
import Quickshell.Io
import "ReminderModel.js" as Model
import "Security.js" as Security

Item {
  id:root
  property var snapshot:[]
  property double now:Date.now()/1000
  readonly property var rows:snapshot.filter(function(row){return row.at>root.now})
  readonly property int count:rows.length
  readonly property bool busy:action.running
  property string error:""
  signal created()
  function refresh() {if(!reader.running) reader.running=true}
  function create(minutes,message) {
    var args=Security.reminderArgs(minutes,message)
    if(!args.length || busy) return false
    error="";action.command=["omarchy-reminder"].concat(args);action.creating=true;action.running=true
    return true
  }
  function clear() {
    if(busy) return
    error="";action.command=["omarchy-reminder","clear"];action.creating=false;action.running=true
  }
  Process {
    id:reader
    command:["omarchy-reminder","show","--json"]
    running:true
    property var result:null
    onStarted:result=null
    stdout:StdioCollector {onStreamFinished:{try {reader.result=JSON.parse(text)} catch(e) {reader.result=null}}}
    onExited:code=>Qt.callLater(function(){
      root.now=Date.now()/1000
      if(code===0 && result && Array.isArray(result.reminders)) {root.snapshot=Model.rows(result,root.now);root.error=""}
      else root.error="reminders.unavailable"
    })
  }
  Process {
    id:action
    property bool creating:false
    onExited:code=>{
      if(code===0) {if(creating) root.created();root.refresh()}
      else root.error="reminders.failed"
    }
  }
  Timer {interval:10000;running:true;repeat:true;onTriggered:root.refresh()}
  Timer {interval:1000;running:root.snapshot.length>0;repeat:true;onTriggered:root.now=Date.now()/1000}
}
