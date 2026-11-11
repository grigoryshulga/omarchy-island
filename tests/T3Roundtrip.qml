import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  Island.T3State {id:bridge;allowed:true}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    visible:true;implicitWidth:540;implicitHeight:360
    Island.T3SessionCard {
      id:card
      width:parent.width-32;anchors.centerIn:parent
      bridge:bridge;strings:strings;expanded:true
      row:bridge.rows.length ? bridge.rows[0] : ({id:"",title:"",project:"",status:"idle",requestId:"",request:null,summary:""})
    }
    TestCase {
      id:test;when:false
      function run() {
        try {
          tryCompare(bridge,"waitingCount",1,5000)
          var id=card.request.id
          verify(id.indexOf("%3A")>=0,"Use T3's native encoded runtime-request ID")
          findChild(card,"t3Option-q1-0").forceActiveFocus();keyClick(Qt.Key_Return)
          var send=findChild(card,"t3Submit")
          verify(send.enabled)
          send.forceActiveFocus();keyClick(Qt.Key_Return)
          compare(bridge.response(id),"sending")
          tryCompare(bridge,"waitingCount",0,4000)
          verify(bridge.response(id)!=="sending","Sending did not clear after RPC success")
          bridge.allowed=false;wait(350)
          console.log("T3_ROUNDTRIP_PASS")
        } catch(error) {console.log("T3_ROUNDTRIP_FAIL",error.stack)}
        Qt.quit()
      }
    }
    Timer {interval:100;running:true;onTriggered:test.run()}
    Timer {interval:10000;running:true;onTriggered:{console.log("T3_ROUNDTRIP_TIMEOUT");Qt.quit()}}
  }
}
