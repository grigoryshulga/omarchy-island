import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Bridge" as Bridge
ShellRoot {
  Bridge.CalendarState {id:subscriptions}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    id:window;visible:true;implicitWidth:560;implicitHeight:900
    Island.CalendarView {id:calendar;anchors.fill:parent;anchors.margins:16;strings:strings;subscriptions:subscriptions;showBack:false}
    TestCase {
      id:test;when:false
      function runChecks() {
        tryCompare(subscriptions,"busy",false,5000)
        compare(subscriptions.error,"")
        findChild(calendar,"calendarSettings").clicked();wait(50)
        var menu=findChild(calendar,"calendarSubscriptions")
        verify(menu.visible);menu.clicked();wait(50)
        verify(calendar.sourcesMode)
        var name=findChild(calendar,"calendarSourceName"),url=findChild(calendar,"calendarSourceUrl"),add=findChild(calendar,"calendarSourceAdd")
        name.text="Calendar <b>";url.text="file:///etc/passwd";verify(!add.enabled)
        name.forceActiveFocus();keyClick(Qt.Key_Return);verify(url.activeFocus)
        url.text="webcal://example.com/private-token/basic.ics";verify(add.enabled)
        keyClick(Qt.Key_Return)
        tryVerify(function(){return subscriptions.sources.length===1 && !subscriptions.busy},5000)
        verify(subscriptions.events.length>0)
        compare(name.text,"");compare(url.text,"")
        verify(JSON.stringify(subscriptions.sources).indexOf("private-token")<0)
        var id=subscriptions.sources[0].id
        calendar.sourcesMode=false
        calendar.selectDay({year:2026,month:2,day:29,key:"2026-03-29"})
        tryCompare(subscriptions,"busy",false,5000)
        verify(calendar.markedDays.indexOf("2026-03-29")>=0)
        var event=subscriptions.events.filter(function(e){return e.title.indexOf("<img")===0})[0]
        var label=findChild(calendar,"calendarEvent-"+event.id)
        verify(label!==null);compare(label.textFormat,Text.PlainText)
        calendar.sourcesMode=true
        findChild(calendar,"calendarRefresh").clicked()
        tryVerify(function(){return !subscriptions.busy && subscriptions.sources[0].stale},5000)
        verify(subscriptions.events.length>0)
        findChild(calendar,"calendarSourceToggle-"+id).clicked()
        tryVerify(function(){return !subscriptions.busy && !subscriptions.sources[0].enabled},5000)
        compare(subscriptions.events.length,0)
        findChild(calendar,"calendarSourceToggle-"+id).clicked()
        tryVerify(function(){return !subscriptions.busy && subscriptions.sources[0].enabled},5000)
        verify(subscriptions.events.length>0)
        findChild(calendar,"calendarSourceRemove-"+id).clicked()
        tryVerify(function(){return !subscriptions.busy && subscriptions.sources.length===0},5000)
        compare(subscriptions.events.length,0)
        console.log("CALENDAR_SUBSCRIPTIONS_PASS")
      }
    }
    Timer {interval:500;running:true;onTriggered:{try {test.runChecks()} catch(error) {console.log("CALENDAR_SUBSCRIPTIONS_FAIL",error.stack)} Qt.quit()}}
  }
}
