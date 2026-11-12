import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/DesignTokens.js" as Tokens

ShellRoot {
  Island.Service {id:service}
  SignalSpy {id:alerts;target:service;signalName:"t3Arrival"}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    id:window
    visible:true;implicitWidth:540;implicitHeight:900
    Island.PopupPages {id:pages;anchors.fill:parent;anchors.margins:16;service:service;strings:strings;expanded:true;keyboardActive:true}
    Timer {interval:400;running:true;onTriggered:{try {test.test_sessions()} catch(error) {console.log("T3_QML_FAIL",error.stack);Qt.quit()}}}
    Timer {interval:18000;running:true;onTriggered:{console.log("T3_QML_TIMEOUT");Qt.quit()}}
    TestCase {
      id:test;when:false;name:"T3"
      function snapshot(rows) {service.t3.receive(JSON.stringify({type:"sessions",rows:rows}))}
      function test_sessions() {
        var originalCorners=Commons.Style.cornerRadius,originalReduceMotion=Commons.Style.reduceMotion
        service.t3.allowed=true
        tryCompare(service.t3,"connected",true,5000)
        tryVerify(function(){return service.t3.rows.length===1})
        compare(service.t3.waitingCount,1)
        compare(alerts.count,0,"Initial snapshot must stay quiet")
        var summaryHeight=pages.implicitHeight
        var openDetails=findChild(pages,"t3OpenDetails")
        verify(openDetails.visible,"T3 summary has no details navigation")
        openDetails.forceActiveFocus();keyClick(Qt.Key_Return);wait(80)
        compare(pages.implicitHeight,summaryHeight,"Details must preserve popup height")
        var card=findChild(pages,"t3Session-thread-1")
        verify(card!==null)
        var field=findChild(card,"t3Answer-q1"),submit=findChild(card,"t3Submit")
        verify(!field.visible,"Custom editor must be opt-in when choices exist")
        verify(card.height<Commons.Style.space(300),"Question card is too tall")
        verify(findChild(findChild(pages,"notificationsScroll"),"t3Session-thread-1")===null,"T3 is still inside the notification list")
        verify(!submit.enabled,"No implicit answer")
        var option=findChild(card,"t3Option-q1-0")
        option.forceActiveFocus();keyClick(Qt.Key_Return)
        tryVerify(function(){return submit.enabled})
        verify(!findChild(option,"choiceDescription").visible,"Option descriptions repeat their labels")
        var otherOption=findChild(card,"t3Option-q1-1")
        compare(option.y,otherOption.y,"Short options must share a row")
        verify(Math.abs(option.width-otherOption.width)<1,"Options need equal columns")
        var choices=findChild(card,"t3Options-q1")
        verify(Math.abs(option.width+otherOption.width+choices.columnSpacing-choices.width)<2,"Options must use the available width")
        var customToggle=findChild(card,"t3Custom-q1")
        customToggle.forceActiveFocus();keyClick(Qt.Key_Return)
        verify(field.visible && field.activeFocus)
        field.forceActiveFocus();field.text="custom $ & <b>"
        var draft=field.text
        var row=JSON.parse(JSON.stringify(service.t3.rows[0]));row.summary="New progress"
        snapshot([row]);wait(50)
        compare(findChild(pages,"t3Session-thread-1"),card)
        compare(findChild(card,"t3Answer-q1"),field)
        compare(field.text,draft)
        verify(field.activeFocus,"Progress must retain input focus")
        var second=Object.assign({},row,{id:"thread-2",title:"Проверка сборки",requestId:"",requestKind:"",request:null})
        var originalY=card.y
        snapshot([second,row]);wait(50)
        compare(card.y,originalY,"Incoming sessions must not reorder a focused card")
        var workingCard=findChild(pages,"t3Session-thread-2"),spinner=findChild(workingCard,"t3SessionSpinner")
        verify(workingCard.height<=Commons.Style.space(88),"Working session must be a compact row")
        verify(spinner.animating,"Working session spinner is stopped")
        var glyph=findChild(spinner,"t3SpinnerGlyph"),frame=glyph.text
        wait(120);verify(glyph.text!==frame,"Braille spinner did not advance")
        var title=findChild(workingCard,"t3SessionTitle"),projectIcon=findChild(workingCard,"t3ProjectIcon")
        var titleX=title.mapToItem(workingCard,0,0).x,projectX=projectIcon.mapToItem(workingCard,0,0).x
        var palette=Island.ThemePalette.values
        Island.ThemePalette.values={blue:"#4488ff",green:"#44dd88",yellow:"#ffdd44"};wait(30)
        for(var variant of [Object.assign({},second,{status:"completed"}),Object.assign({},second,{status:"failed"}),Object.assign({},second,{requestId:"pending"}),second]) {
          snapshot([row,variant]);wait(180)
          compare(title.mapToItem(workingCard,0,0).x,titleX,"Status moved the title")
          compare(projectIcon.mapToItem(workingCard,0,0).x,projectX,"Status moved the project icon")
          var icon=workingCard.statusIcon
          verify(Math.abs(icon.mapToItem(workingCard,icon.width/2,icon.height/2).y-title.mapToItem(workingCard,0,title.height/2).y)<1,"Status icon is not aligned with the title")
          compare(findChild(workingCard,"t3StatusLabel").color.toString(),workingCard.statusColor.toString(),"Status label missed its semantic color")
          verify(Tokens.contrast(findChild(workingCard,"t3StatusLabel").color,workingCard.color)>=4.5,"Status text became unreadable with theme-file colors")
          compare(workingCard.statusColor.toString(),(variant.requestId ? Island.Design.warning : variant.status==="completed" ? Island.Design.success : variant.status==="failed" ? Island.Design.danger : Island.Design.info).toString())
        }
        Island.ThemePalette.values={blue:"#6699ff",green:"#55cc88",yellow:"#ddcc55"};wait(30)
        compare(workingCard.statusColor.toString(),Island.Design.info.toString(),"Live theme change did not update status")
        Island.ThemePalette.values=palette
        var section=findChild(pages,"t3Section"),many=[row,second]
        for(var n=3;n<=6;n++) many.push(Object.assign({},second,{id:"thread-"+n}))
        snapshot(many);wait(50)
        var sixth=findChild(pages,"t3Session-thread-6")
        verify(sixth.visible,"Details must reveal every session")
        compare(findChild(card,"t3Answer-q1").text,draft,"Opening details discarded draft")
        verify(pages.back(),"Back did not return to summary");wait(50)
        verify(!sixth.visible && workingCard.visible,"Summary must cap working rows")
        verify(openDetails.activeFocus,"Back lost summary focus")
        compare(pages.implicitHeight,summaryHeight,"Summary resized after returning")
        openDetails.clicked();wait(50)
        compare(findChild(card,"t3Answer-q1").text,draft,"Returning to details lost the draft")
        pages.expanded=false;pages.hovering=true;wait(50)
        verify(card.visible && !workingCard.visible && !sixth.visible,"Hover preview must show only the first sorted thread")
        verify(!spinner.animating,"Hidden hover thread kept its spinner running")
        compare(findChild(card,"t3Answer-q1").text,draft,"Hover transition discarded draft")
        pages.expanded=true;pages.hovering=false;wait(50)
        openDetails.clicked();wait(50)
        var done=Object.assign({},second,{id:"thread-done",status:"completed"})
        snapshot([second,done,row]);wait(50)
        var doneCard=findChild(pages,"t3Session-thread-done")
        verify(card.y<doneCard.y && doneCard.y<workingCard.y,"Threads must sort as needs input, completed, working")
        compare(findChild(card,"t3Answer-q1"),field,"Sorting replaced the input form")
        compare(field.text,draft,"Sorting discarded the input draft")
        row.projectIcon={kind:"lucide",name:"folder-code",color:"red"}
        snapshot([row,second]);wait(80)
        var projectIcon=findChild(card,"t3ProjectIcon")
        verify(projectIcon.visible && projectIcon.geometry.indexOf("path")>=0,"API project icon was not rendered")
        compare(findChild(projectIcon,"projectLucideIcon").status,Image.Ready)
        compare(projectIcon.tint.toString(),projectIcon.dark ? "#ff6467" : "#e7000b","Project icon lost the original T3 color")
        pages.controls=true;wait(30);verify(!spinner.animating,"Hidden page kept animating")
        pages.controls=false;wait(300)
        field.forceActiveFocus()
        if(Quickshell.env("ISLAND_T3_CAPTURE")) {
          findChild(pages,"t3Section").grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_T3_CAPTURE"))})
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
        snapshot([row,second]);wait(50)
        field=findChild(card,"t3Answer-q1");submit=findChild(card,"t3Submit")
        compare(field.text,"");verify(!submit.enabled)
        verify(!field.visible)
        customToggle=findChild(card,"t3Custom-q1");customToggle.forceActiveFocus();keyClick(Qt.Key_Return)
        field.text="literal $(touch /tmp/never); <b>"
        var expected=field.text
        tryVerify(function(){return submit.enabled})
        Commons.Style.reduceMotion=true;Commons.Style.cornerRadius=0
        compare(card.radius,0,"Square system corners must remain square")
        verify(!spinner.animating,"Reduced motion must stop the spinner")
        compare(field.text,expected,"Changing the theme must preserve the answer")
        verify(pages.back(),"T3 Back did not return to summary")
        findChild(pages,"notificationsOpenDetails").clicked();wait(30)
        findChild(pages,"notificationsHistory").clicked();wait(30)
        verify(!findChild(pages,"t3Section").visible,"Notification details must replace T3")
        compare(field.text,expected,"Notification tabs must preserve answers")
        findChild(pages,"notificationsActive").clicked()
        verify(pages.back(),"Notification Back did not return to summary")
        openDetails.clicked();wait(30)
        service.t3.receive('{"type":"connection","status":"offline"}')
        verify(!submit.enabled,"Disconnect disables answers")
        verify(!findChild(pages,"t3Section").visible,"Offline T3 must be completely hidden")
        compare(field.text,expected,"Disconnect keeps drafts")
        service.t3.receive('{"type":"connection","status":"connected","canRespond":true,"environmentId":"env-1"}')
        tryVerify(function(){return submit.enabled})
        var stuck={};stuck[row.request.id]={status:"sending",startedAt:Date.now()-21000}
        service.t3.responses=stuck;service.t3.expireResponses(Date.now())
        compare(service.t3.response(row.request.id),"uncertain","A lost reply must not leave Sending forever")
        verify(!submit.enabled,"Uncertain sends must not be retried")
        service.t3.responses=({});tryVerify(function(){return submit.enabled})
        submit.forceActiveFocus();keyClick(Qt.Key_Return)
        compare(service.t3.response("request-2"),"sending")
        verify(!submit.enabled,"No double-submit")
        tryCompare(service.t3,"waitingCount",0)
        tryCompare(service.t3,"workingCount",1)
        Commons.Style.cornerRadius=originalCorners;Commons.Style.reduceMotion=originalReduceMotion
        // Real answers are often paragraphs: preserve full labels and descriptions.
        var longRow=JSON.parse(JSON.stringify(row));longRow.id="thread-long";longRow.requestId="long-question";longRow.request.id="long-question"
        longRow.request.questions[0].options=[
          {value:"one",label:"Запускать сборку и тесты локально после каждого изменения исходного кода",description:"Результат сразу доступен в рабочем каталоге; потребуется больше ресурсов компьютера."},
          {value:"two",label:"Отправлять изменения на удалённый сервер и получать только итоговый отчёт",description:"Подходит для длительных проверок и работы с несколькими проектами одновременно."}
        ]
        snapshot([longRow,second]);wait(300)
        var longCard=findChild(pages,"t3Session-thread-long"),longChoice=findChild(longCard,"t3Option-q1-0"),longLabel=findChild(longChoice,"choiceLabel")
        verify(longLabel.lineCount>1 && !longLabel.truncated,"Long options must wrap without truncation")
        var description=findChild(longChoice,"choiceDescription")
        verify(description.visible && !description.truncated,"Meaningful descriptions must remain visible")
        if(Quickshell.env("ISLAND_T3_CAPTURE")) {
          findChild(pages,"t3Section").grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_T3_CAPTURE").replace(".png","-long.png"))});wait(150)
        }
        longCard.width=320;wait(300)
        compare(findChild(longCard,"t3Options-q1").columns,1,"Narrow cards need a single column")
        verify(!longLabel.truncated && !description.truncated,"Narrow cards must preserve full option text")
        longChoice.forceActiveFocus();keyClick(Qt.Key_Return)
        keyClick(Qt.Key_Tab);keyClick(Qt.Key_Tab);keyClick(Qt.Key_Tab)
        var longSend=findChild(longCard,"t3Submit"),sessionScroll=findChild(pages,"t3SessionsScroll")
        verify(longSend.activeFocus,"Tab must reach Send on a long form")
        var buttonAt=longSend.mapToItem(sessionScroll,0,0)
        verify(buttonAt.y>=0 && buttonAt.y+longSend.height<=sessionScroll.height+1,"Keyboard focus must scroll the send button into view")
        // Reconnect snapshots stay quiet; the next completion must still alert.
        service.doNotDisturb=false
        service.activeAppId="island-test"
        alerts.clear()
        service.t3.receive('{"type":"connection","status":"offline"}')
        service.t3.receive('{"type":"connection","status":"connected","canRespond":true,"environmentId":"env-1"}')
        snapshot([second]);wait(30)
        compare(alerts.count,0,"Reconnect baseline must not reannounce running threads")
        snapshot([Object.assign({},second,{status:"completed"})]);wait(30)
        compare(alerts.count,1,"First completion after reconnect must alert")
        snapshot([Object.assign({},second,{status:"completed",summary:"Updated metadata"})]);wait(30)
        compare(alerts.count,1,"Metadata must not repeat the completion popup")
        snapshot([]);wait(30)
        alerts.clear()
        service.doNotDisturb=false
        snapshot([Object.assign({},second,{status:"running"})]);wait(30)
        compare(alerts.count,1)
        snapshot([Object.assign({},second,{status:"starting"})]);wait(30)
        compare(alerts.count,1,"Run phases must not repeat popups")
        service.doNotDisturb=true
        snapshot([Object.assign({},second,{status:"completed"})]);wait(30)
        compare(alerts.count,1,"DND must suppress popups")
        service.doNotDisturb=false
        snapshot([Object.assign({},second,{status:"running"})]);wait(30)
        compare(alerts.count,2)
        pages.expanded=false;pages.hovering=false;pages.alertKind="t3";wait(50)
        verify(findChild(pages,"t3ActivityToast").visible,"Status alert must render its compact card")
        pages.alertKind="";pages.expanded=true
        snapshot([]);wait(30)
        verify(!findChild(pages,"t3Section").visible,"Empty T3 must be completely hidden")
        service.t3.allowed=false
        compare(service.t3.rows.length,0)
        compare(service.t3.waitingCount,0)
        console.log("T3_QML_PASS")
        Qt.quit()
      }
    }
  }
}
