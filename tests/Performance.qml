import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  QtObject {
    id: service
    property bool hasMedia: true
    readonly property var modules:({weather:("weather" in service) ? service.weather : null,calendar:{allowed:true,calendars:("calendars" in service) ? service.calendars : null,reminders:("reminders" in service) ? service.reminders : null},notifications:service,media:service,t3:t3})
    property var t3: ({allowed:false,connected:false,canRespond:false,responsesEnabled:false,rows:[]})
    property var player: player
    property var activeEntries: [{key:"one",app:"First",summary:"One",body:"Body",codes:"123456",ts:1}]
    property var historyEntries: []
    property var latest: null
    property var mutedSources: []
    property string error: ""
    property bool doNotDisturb: false
    property var copiedRow: null
    function actions(row) {return []}
    function copyCode(row, code) {copiedRow=row}
  }
  QtObject {
    id: player
    property bool isPlaying: true
    property bool positionSupported: true
    property bool lengthSupported: true
    property bool canSeek: true
    property bool canGoPrevious: true
    property bool canGoNext: true
    property bool canTogglePlaying: true
    property bool volumeSupported: true
    property real volume: 0.5
    property real length: 180
    property real position: 20
    property string trackTitle: "Test"
    property string trackArtist: "Artist"
    property string trackArtUrl: ""
    property string identity: "Player"
    property int positionPolls: 0
    onPositionChanged: positionPolls++
  }
  FloatingWindow {
    visible: true
    implicitWidth: 560
    implicitHeight: 540
    Commons.Translations { id: translations; directory: Qt.resolvedUrl("Island/i18n") }
    Island.CalendarView {
      id: calendar
      anchors.fill: parent
      anchors.margins: 20
      strings: translations
      today: new Date(2026, 10, 12, 12)
    }
    Island.IslandContent {
      id: inbox
      anchors.fill: parent
      visible: false
      expanded: true
      service: service
      strings: translations
    }
    Island.ControlsView {
      id: controls
      anchors.fill: parent
      visible: false
      service: service
      strings: translations
    }
    TestCase {
      id: test
      when: false
      readonly property bool measureOnly: Quickshell.env("ISLAND_PERF_MEASURE_ONLY")==="1"
      function checkEqual(actual, expected, message) {if(!measureOnly) compare(actual, expected, message || "")}
      function check(condition, message) {if(!measureOnly) verify(condition, message || "")}
      function yearDay(item) {
        if("text" in item && item.text==="15") return item
        for(var i=0;i<item.children.length;i++) {var found=yearDay(item.children[i]);if(found) return found}
        return null
      }
      function test_navigation() {
        wait(100)
        var first = findChild(calendar, "calendar-day-" + calendar.cells[0].key)
        first.forceActiveFocus()
        var started = Date.now()
        for (var i = 0; i < 120; ++i) calendar.shiftMonth(1)
        var months = Date.now() - started
        started = Date.now()
        for (i = 0; i < 20; ++i) calendar.viewYear += i % 2 ? -1 : 1
        var years = Date.now() - started
        wait(30)
        var current = findChild(calendar, "calendar-day-" + calendar.cells[0].key)
        console.log("PERFORMANCE_CALENDAR", JSON.stringify({months120Ms: months, years20Ms: years, retainedDay: first === current}))
        checkEqual(current, first, "Calendar navigation must update existing day controls")
        check(current.activeFocus, "Calendar navigation must retain focus")
        calendar.showToday()
        wait(20)
        checkEqual(calendar.viewYear, 2026)
        checkEqual(calendar.viewMonth, 10)
        checkEqual(calendar.cells.length, 42)
        calendar.weekStart = "monday"
        wait(20)
        checkEqual(calendar.firstDay, 1)
        checkEqual(findChild(calendar, "calendar-day-" + calendar.cells[0].key), first)
        calendar.selectDay(calendar.cells[41])
        calendar.focusSelectedDay()
        check(findChild(calendar, "calendar-day-" + calendar.selectedDay.key).activeFocus)
        if("yearMode" in calendar) {
          calendar.yearMode=true
          wait(30)
          var monthTile=findChild(calendar,"calendarYearMonth-0")
          var yearLabel=yearDay(monthTile)
          monthTile.forceActiveFocus()
          started=Date.now()
          for(i=0;i<20;i++) calendar.shiftMonth(i%2 ? -1 : 1)
          console.log("PERFORMANCE_YEAR_VIEW",JSON.stringify({years20Ms:Date.now()-started,retainedDay:yearDay(monthTile)===yearLabel}))
          checkEqual(yearDay(monthTile),yearLabel,"Year overview must retain day labels")
          check(monthTile.activeFocus,"Year overview must retain month focus")
          calendar.yearMode=false
        }
        var glow = findChild(calendar, "calendarSpotlight")
        glow.active = true
        started = Date.now()
        for (i = 0; i < 240; ++i) {
          glow.pointer = Qt.point(20 + i % 400, 100 + i % 200)
          // Consume both bindings so every pointer update is measured.
          var focused = glow.hoveredSurface, nearby = glow.nearbySurfaces
        }
        console.log("PERFORMANCE_SPOTLIGHT", JSON.stringify({moves240Ms: Date.now() - started}))
        calendar.visible = false
        inbox.visible = true
        wait(200)
        var group = findChild(inbox, "notificationGroup-First")
        var card = findChild(inbox, "notification-one")
        var copy = findChild(card, "copyCode-123456")
        card.forceActiveFocus()
        wait(200)
        copy.forceActiveFocus()
        check(copy.activeFocus, "Notification action must be reachable before updates")
        started = Date.now()
        for (i = 0; i < 30; ++i) {
          service.activeEntries = [{key:"one",app:"First",summary:"One",body:"Updated " + i,codes:"123456",ts:1},
                                   {key:"two",app:"Second",summary:"Two",body:"Body",ts:2}]
        }
        console.log("PERFORMANCE_NOTIFICATIONS", JSON.stringify({updates30Ms: Date.now() - started,
          retainedCard: card === findChild(inbox, "notification-one")}))
        if(measureOnly) {console.log("PERFORMANCE_PASS");Qt.quit();return}
        checkEqual(findChild(inbox, "notificationGroup-First"), group, "Notification updates must retain existing groups")
        checkEqual(findChild(inbox, "notification-one"), card, "Notification updates must retain existing cards")
        checkEqual(findChild(card, "copyCode-123456"), copy, "Body updates must retain action controls")
        check(copy.activeFocus, "Notification updates must retain action focus")
        checkEqual(findChild(card, "notificationBody").text, "Updated 29")
        copy.clicked()
        checkEqual(service.copiedRow.body, "Updated 29", "Retained actions must resolve current notification data")
        var second = findChild(inbox, "notification-two")
        service.activeEntries = [{key:"two",app:"Second",summary:"Two",body:"Body",ts:2},
                                 {key:"one",app:"First",summary:"One",body:"Updated 29",codes:"123456",ts:1}]
        checkEqual(findChild(inbox, "notification-one"), card)
        checkEqual(findChild(inbox, "notification-two"), second)
        check(copy.activeFocus, "Reordering groups must retain action focus")
        service.activeEntries = service.activeEntries.concat([{key:"three",app:"First",summary:"One",body:"New member",ts:3}])
        checkEqual(findChild(inbox, "notification-three"), card, "Coalescing a new member must retain the card")
        checkEqual(card.members.length, 2)
        service.activeEntries = service.activeEntries.filter(function(row){return row.key!=="three"})
        checkEqual(findChild(inbox, "notification-one"), card)
        checkEqual(card.members.length, 1)
        var polls = player.positionPolls
        wait(550)
        check(player.positionPolls > polls, "Active Overview must poll MPRIS position")
        inbox.overviewActive = false
        wait(30)
        polls = player.positionPolls
        wait(550)
        checkEqual(player.positionPolls, polls, "Inactive Overview must stop MPRIS position polling")
        inbox.visible = false
        controls.visible = true
        controls.active = true
        service.doNotDisturb = true
        wait(200)
        var tile = findChild(controls, "controlDnd")
        var led = findChild(tile, "controlIndicatorGlow")
        check(led.active, "Selected Controls tile must have a glow")
        controls.active = false
        wait(200)
        check(!led.active, "Inactive Controls must stop tile effects")
        var phase = led.phase
        wait(80)
        checkEqual(led.phase, phase, "Inactive tile shader must stop its clock")
        controls.active = true
        controls.openSection("settings")
        wait(200)
        var setting = findChild(controls, "setting-hoverPreview")
        led = findChild(setting, "controlIndicatorGlow")
        check(led.active)
        controls.active = false
        wait(200)
        check(!led.active, "Inactive Settings must stop switch effects")
        phase = led.phase
        wait(80)
        checkEqual(led.phase, phase)
        console.log("PERFORMANCE_PASS")
        Qt.quit()
      }
    }
    Timer { interval: 300; running: true; onTriggered: {try {test.test_navigation()} catch (error) {console.log("PERFORMANCE_FAIL", error.stack); Qt.quit()}} }
  }
}
