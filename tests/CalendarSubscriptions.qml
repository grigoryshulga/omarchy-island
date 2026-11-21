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
    property bool editing:false
    QtObject {id:calendarBackend;property bool allowed:true;property var calendars:subscriptions}
    Island.SettingsView {
      id:settingsView;anchors.fill:parent;visible:window.editing;active:visible;windowMode:true
      strings:strings;modules:({calendar:calendarBackend})
    }
    Island.CalendarView {id:calendar;visible:!window.editing;onSettingsRequested:{window.editing=true;settingsView.focusGroup("calendar")}
      anchors.fill:parent;anchors.margins:16;strings:strings;subscriptions:subscriptions;showBack:false}
    TestCase {
      id:test;when:false
      function runChecks() {
        tryCompare(subscriptions,"busy",false,5000)
        compare(subscriptions.error,"")
        findChild(calendar,"calendarSettings").clicked();wait(50)
        var menu=findChild(settingsView,"calendarSubscriptions")
        verify(menu.visible);menu.clicked();wait(50)
        verify(window.editing)
        var name=findChild(settingsView,"calendarSourceName"),url=findChild(settingsView,"calendarSourceUrl"),add=findChild(settingsView,"calendarSourceAdd")
        name.text="Calendar <b>"
        var yesterday=new Date(Date.now()-86400000)
        calendar.today=yesterday
        var key=yesterday.getFullYear()+"-"+String(yesterday.getMonth()+1).padStart(2,"0")+"-"+String(yesterday.getDate()).padStart(2,"0")
        calendar.selectDay({year:yesterday.getFullYear(),month:yesterday.getMonth(),day:yesterday.getDate(),key:key})
        findChild(calendar,"calendarDateRefresh").triggered()
        verify(window.editing);compare(name.text,"Calendar <b>")
        url.text="file:///etc/passwd";verify(!add.enabled)
        verify(!!findChild(settingsView,"calendarUrlField").error);verify(url.invalid)
        name.forceActiveFocus()
        tryCompare(name,"activeFocus",true,3000)
        keyClick(Qt.Key_Return);verify(url.activeFocus)
        url.text="webcal://example.com/private-token/basic.ics";verify(add.enabled)
        compare(findChild(settingsView,"calendarUrlField").error,"");verify(!url.invalid)
        keyClick(Qt.Key_Return)
        tryVerify(function(){return subscriptions.sources.length===1 && !subscriptions.busy},5000)
        verify(subscriptions.events.length>0)
        compare(name.text,"");compare(url.text,"")
        verify(JSON.stringify(subscriptions.sources).indexOf("private-token")<0)
        if(Quickshell.env("ISLAND_ICS_CAPTURE")) {
          settingsView.grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_ICS_CAPTURE")+"-sources.png")});wait(100)
        }
        subscriptions.activate(2027);subscriptions.activate(2026)
        tryVerify(function(){return !subscriptions.busy && subscriptions.reports[2027]!==undefined && subscriptions.reports[2026]!==undefined},5000)
        verify(subscriptions.eventsForYear(2026).length>0)
        compare(subscriptions.eventsForYear(2027).length,0)
        var id=subscriptions.sources[0].id
        window.editing=false
        calendar.selectDay({year:2026,month:2,day:29,key:"2026-03-29"})
        tryCompare(subscriptions,"busy",false,5000)
        verify(calendar.markedDays.indexOf("2026-03-29")>=0)
        var day=findChild(calendar,"calendar-day-2026-03-29")
        verify(day.Accessible.selected && day.Accessible.description.includes(strings.t("ics.events")))
        compare(day.Accessible.name,new Date(2026,2,29,12).toLocaleDateString(calendar.locale,Locale.LongFormat))
        calendar.weekStart="monday"
        calendar.viewMonth=11;calendar.viewYear=2025
        tryCompare(subscriptions,"busy",false,5000)
        var adjacent=findChild(calendar,"calendar-day-2026-01-11")
        compare(adjacent.Accessible.name,new Date(2026,0,11,12).toLocaleDateString(calendar.locale,Locale.LongFormat))
        verify(!adjacent.Accessible.selected)
        verify(adjacent.Accessible.description.includes(strings.t("ics.events")))
        calendar.selectDay({year:2026,month:2,day:29,key:"2026-03-29"})
        var event=subscriptions.events.filter(function(e){return e.title.indexOf("<img")===0})[0]
        var label=findChild(calendar,"calendarEvent-"+event.id)
        verify(label!==null);compare(label.textFormat,Text.PlainText)
        if(Quickshell.env("ISLAND_ICS_CAPTURE")) {
          calendar.grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_ICS_CAPTURE")+"-agenda.png")});wait(100)
        }
        window.editing=true
        wait(50)
        var disclosure=findChild(settingsView,"calendarSubscriptions")
        if(!disclosure.Accessible.expanded) disclosure.clicked()
        findChild(settingsView,"calendarRefresh").clicked()
        tryVerify(function(){return !subscriptions.busy && subscriptions.sources[0].stale},5000)
        verify(subscriptions.events.length>0)
        findChild(settingsView,"calendarSourceToggle-"+id).clicked()
        tryVerify(function(){return !subscriptions.busy && !subscriptions.sources[0].enabled},5000)
        compare(subscriptions.events.length,0)
        findChild(settingsView,"calendarSourceToggle-"+id).clicked()
        tryVerify(function(){return !subscriptions.busy && subscriptions.sources[0].enabled},5000)
        verify(subscriptions.events.length>0)
        findChild(settingsView,"calendarSourceRemove-"+id).clicked()
        tryVerify(function(){return !subscriptions.busy && subscriptions.sources.length===0},5000)
        compare(subscriptions.events.length,0)
        console.log("CALENDAR_SUBSCRIPTIONS_PASS")
      }
    }
    Timer {interval:500;running:true;onTriggered:{try {test.runChecks()} catch(error) {console.log("CALENDAR_SUBSCRIPTIONS_FAIL",error.stack)} Qt.quit()}}
  }
}
