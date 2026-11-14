import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/modules/codex" as Codex

ShellRoot {
  Island.CodexState {id:bridge;allowed:true}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  QtObject {
    id:presentation
    property bool expanded:true
    property bool detail:true
    property bool active:true
    property bool hovering:false
    property int pageHeight:640
    property var strings:strings
    property var feedback:null
  }
  FloatingWindow {
    visible:true;implicitWidth:540;implicitHeight:800
    Codex.Overview {id:overview;width:parent.width;backend:bridge;presentation:presentation}
    TestCase {
      id:test;when:false
      function run() {
        try {
          tryCompare(bridge,"connected",true,4000)
          tryVerify(function(){return bridge.rows.length===1},3000)
          var card=findChild(overview,"t3Session-thread-1")
          verify(!!card)
          var attach=findChild(card,"codexAction")
          tryCompare(bridge,"waitingCount",1,4000)
          tryVerify(function(){return bridge.row("thread-1").attached},2000)
          findChild(card,"t3Option-q-0").forceActiveFocus();keyClick(Qt.Key_Return)
          var firstRequest=card.request
          var submit=findChild(card,"t3Submit");verify(submit.enabled)
          submit.forceActiveFocus();keyClick(Qt.Key_Return)
          tryCompare(bridge,"waitingCount",0,3000)
          var message=findChild(card,"codexMessage")
          message.text="Draft"
          presentation.detail=false;wait(30);presentation.detail=true;wait(30)
          compare(findChild(card,"codexMessage"),message)
          compare(message.text,"Draft")
          message.text="literal $(touch /tmp/never); <b>"
          tryCompare(attach,"enabled",true,2000)
          attach.forceActiveFocus();keyClick(Qt.Key_Return)
          tryVerify(function(){return bridge.row("thread-1").status==="running"},3000)
          tryCompare(message,"text","",2000)
          var stop=findChild(card,"codexInterrupt")
          verify(stop.enabled);stop.forceActiveFocus();keyClick(Qt.Key_Return)
          tryVerify(function(){return bridge.row("thread-1").status==="interrupted"},3000)
          bridge.actions=({"thread-1":{id:"x",status:"sending",startedAt:Date.now()-21000}})
          bridge.expireActions();compare(bridge.actionStatus("thread-1"),"uncertain")
          verify(!bridge.act("message","thread-1","must not retry",""))
          var creation=findChild(overview,"codexNewSession")
          findChild(creation,"codexDirectory").text=Quickshell.env("ISLAND_MODULE_STORAGE")
          findChild(creation,"codexMessage").text="New task"
          var create=findChild(creation,"codexAction");verify(create.enabled)
          create.forceActiveFocus();keyClick(Qt.Key_Return)
          tryVerify(function(){return !!bridge.row("thread-2") && bridge.row("thread-2").status==="running"},3000)
          bridge.restart()
          tryCompare(bridge,"connected",false,1000)
          tryCompare(bridge,"connected",true,4500)
          tryCompare(bridge,"waitingCount",1,3000)
          tryVerify(function(){return bridge.row("thread-1").attached},2000)
          verify(bridge.row("thread-1").requestId!==firstRequest.id)
          verify(!bridge.submit("thread-1",firstRequest,{q:["A"]}))
          compare(bridge.actionStatus("thread-1"),"uncertain")
          bridge.allowed=false;tryCompare(bridge,"connected",false,1000)
          bridge.responsesEnabled=false;bridge.allowed=true
          tryCompare(bridge,"connected",true,4000)
          tryVerify(function(){return bridge.rows.length===1},2000)
          verify(!bridge.row("thread-1").attached)
          verify(!bridge.act("attach","thread-1","",""))
          bridge.allowed=false
          console.log("CODEX_QML_PASS")
        } catch(error) {console.log("MODULES_FAIL",error.stack)}
        Qt.quit()
      }
    }
    Timer {interval:150;running:true;onTriggered:test.run()}
  }
}
