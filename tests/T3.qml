import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  Island.Service {id:service}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    visible:true;implicitWidth:540;implicitHeight:900
    Island.PopupPages {id:pages;anchors.fill:parent;anchors.margins:16;service:service;strings:strings;expanded:true;keyboardActive:true}
    Timer {interval:400;running:true;onTriggered:{try {test.test_sessions()} catch(error) {console.log("T3_QML_FAIL",error.stack);Qt.quit()}}}
    Timer {interval:18000;running:true;onTriggered:{console.log("T3_QML_TIMEOUT");Qt.quit()}}
    TestCase {
      id:test;when:false;name:"T3"
      function snapshot(rows) {service.t3.receive(JSON.stringify({type:"sessions",rows:rows}))}
      function test_sessions() {
        service.t3.allowed=true
        tryCompare(service.t3,"connected",true,5000)
        tryVerify(function(){return service.t3.rows.length===1})
        compare(service.t3.waitingCount,1)
        var card=findChild(pages,"t3Session-thread-1")
        verify(card!==null)
        var field=findChild(card,"t3Answer-q1"),submit=findChild(card,"t3Submit")
        verify(!submit.enabled,"No implicit answer")
        var option=findChild(card,"t3Option-q1-0")
        option.forceActiveFocus();keyClick(Qt.Key_Return)
        tryVerify(function(){return submit.enabled})
        field.forceActiveFocus();field.text="custom $ & <b>"
        var draft=field.text
        var row=JSON.parse(JSON.stringify(service.t3.rows[0]));row.summary="New progress"
        snapshot([row]);wait(50)
        compare(findChild(pages,"t3Session-thread-1"),card)
        compare(findChild(card,"t3Answer-q1"),field)
        compare(field.text,draft)
        verify(field.activeFocus,"Progress must retain input focus")
        var second=Object.assign({},row,{id:"thread-2",requestId:"",requestKind:"",request:null})
        var originalY=card.y
        snapshot([second,row]);wait(50)
        compare(card.y,originalY,"Incoming sessions must not reorder a focused card")
        if(Quickshell.env("ISLAND_T3_CAPTURE")) {
          pages.grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_T3_CAPTURE"))})
          wait(250)
        }
        keyClick(Qt.Key_Space)
        verify(field.text.indexOf(" ")>=0,"Space belongs to the editor")
        keyClick(Qt.Key_Tab)
        verify(submit.activeFocus,"Tab reaches Send from the editor")
        keyClick(Qt.Key_Backtab,Qt.ShiftModifier)
        verify(field.activeFocus)
        // A new question with identical text must still clear the previous answer.
        row.requestId="request-2";row.request.id="request-2";row.request.revision="revision-2"
        snapshot([row]);wait(50)
        field=findChild(card,"t3Answer-q1");submit=findChild(card,"t3Submit")
        compare(field.text,"");verify(!submit.enabled)
        field.text="literal $(touch /tmp/never); <b>"
        var expected=field.text
        tryVerify(function(){return submit.enabled})
        Commons.Style.reduceMotion=true;Commons.Style.cornerRadius=0
        compare(card.radius,0,"Square system corners must remain square")
        compare(field.text,expected,"Changing the theme must preserve the answer")
        service.t3.receive('{"type":"connection","status":"offline"}')
        verify(!submit.enabled,"Disconnect disables answers")
        compare(field.text,expected,"Disconnect keeps drafts")
        service.t3.receive('{"type":"connection","status":"connected","canRespond":true,"environmentId":"env-1"}')
        tryVerify(function(){return submit.enabled})
        submit.forceActiveFocus();keyClick(Qt.Key_Return)
        compare(service.t3.response("request-2"),"sending")
        verify(!submit.enabled,"No double-submit")
        tryCompare(service.t3,"waitingCount",0)
        tryCompare(service.t3,"workingCount",1)
        service.t3.allowed=false
        compare(service.t3.rows.length,0)
        compare(service.t3.waitingCount,0)
        console.log("T3_QML_PASS")
        Qt.quit()
      }
    }
  }
}
