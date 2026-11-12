import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  Island.ReminderState {id:reminders}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    id:window;visible:true;implicitWidth:520;implicitHeight:900
    Island.CalendarView {id:calendar;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:16;strings:strings;reminders:reminders;showBack:false}
    TestCase {
      id:test;when:false
      function runChecks() {
        tryCompare(reminders,"error","")
        compare(reminders.count,0)
        verify(!reminders.create("1;false","bad"))
        findChild(calendar,"reminderAdd").clicked()
        findChild(calendar,"reminderMinutes").text="005"
        findChild(calendar,"reminderMessage").text="literal $(touch /tmp/island-never); <b>"
        var save=findChild(calendar,"reminderSave")
        verify(save.enabled);save.clicked()
        tryCompare(reminders,"count",1,3000)
        compare(reminders.rows[0].label,"literal $(touch /tmp/island-never); <b>")
        verify(!findChild(calendar,"reminderMinutes").visible)
        verify(calendar.reminderDays.length===1)
        if(Quickshell.env("ISLAND_CALENDAR_CAPTURE")) {
          calendar.grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_CALENDAR_CAPTURE")+"-month.png")});wait(100)
        }
        calendar.viewYear=2024;calendar.viewMonth=0
        findChild(calendar,"calendarMonth").clicked()
        verify(calendar.yearMode)
        for(var i=0;i<12;i++) verify(findChild(calendar,"calendarYearMonth-"+i).visible)
        verify(calendar.monthImplicitHeight<calendar.implicitHeight)
        calendar.height=400
        var scroll=findChild(calendar,"calendarScroll")
        tryVerify(function(){return scroll.contentHeight>scroll.availableHeight})
        scroll.contentItem.contentY=scroll.contentHeight-scroll.availableHeight
        verify(scroll.contentItem.contentY>0)
        calendar.height=Qt.binding(function(){return calendar.implicitHeight})
        scroll.contentItem.contentY=0
        if(Quickshell.env("ISLAND_CALENDAR_CAPTURE")) {
          calendar.grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_CALENDAR_CAPTURE")+"-year.png")});wait(100)
        }
        var february=findChild(calendar,"calendarYearMonth-1")
        february.forceActiveFocus();keyClick(Qt.Key_PageDown);compare(calendar.viewYear,2025)
        keyClick(Qt.Key_PageUp);compare(calendar.viewYear,2024)
        keyClick(Qt.Key_Return)
        verify(!calendar.yearMode);compare(calendar.viewMonth,1)
        verify(findChild(calendar,"calendar-day-2024-02-29")!==null)
        calendar.showToday();verify(!calendar.yearMode)
        findChild(calendar,"reminderClear").clicked()
        tryCompare(reminders,"count",0,3000)
        verify(!findChild(calendar,"reminderClear").visible)
        console.log("CALENDAR_REMINDERS_PASS")
      }
    }
    Timer {interval:500;running:true;onTriggered:{try {test.runChecks()} catch(error) {console.log("CALENDAR_REMINDERS_FAIL",error.stack)} Qt.quit()}}
  }
}
