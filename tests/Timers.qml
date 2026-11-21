import QtQuick
import QtTest
import Quickshell
import "Island" as Island
import qs.Commons as Commons
import "Island/ModuleCatalog.mjs" as Catalog
import "Island/modules/timers/Time.mjs" as Time
import "Island/NowActivity.mjs" as Now
import "Island/NowPresentation.js" as Copy

ShellRoot {
  id: fixture
  readonly property bool restoring: Quickshell.env("TIMERS_RESTORE") === "1"
  property double timestamp: restoring ? 2000000 : 100000
  property var alerts: []
  property var toolsState: registry.backends.timers || null
  Island.ModuleRegistry {
    id:registry; definitions:[Catalog.definition("timers")]
    stateProperties: ({timers:{
      clock:function(){return fixture.timestamp}, stateDir:Quickshell.env("ISLAND_MODULE_STORAGE"),
      execute:function(argv){fixture.alerts=fixture.alerts.concat([argv])}
    }})
  }
  ModuleHost {id:host; registry:registry}
  Commons.Translations {id:strings; directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    implicitWidth:390; implicitHeight:350; visible:true
    TextInput {id:clipboardSource; visible:false}
    Island.IslandContent {
      id:overview; anchors.fill:parent; service:host; strings:strings; expanded:true
      onExpandRequested: expanded=true
    }
  }
  TestCase {
    id: test; parent:overview; when:false
    function run() {
      tryVerify(function(){return !!fixture.toolsState && fixture.toolsState.ready})
      var headerTime = findChild(overview,"timersOpen")
      verify(headerTime.visible && headerTime.text.length > 0)
      verify(!overview.overviewLayout.some(row => row.id==="timers"))
      var sample=new Date(2026,10,21,9,5)
      overview.currentDate=sample
      compare(headerTime.text,sample.toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),Locale.ShortFormat))
      overview.expanded=false; overview.hovering=true
      mouseClick(headerTime)
      tryCompare(overview,"detailPage","timers")
      verify(overview.expanded)
      verify(overview.back())
      overview.hovering=false
      tryVerify(function(){return headerTime.activeFocus})
      headerTime.forceActiveFocus()
      keyClick(Qt.Key_Return)
      tryCompare(overview,"detailPage","timers")
      wait(60)
      var view=overview.detailItem
      function fitsContent() {
        var bottom=view.mapToItem(overview,0,view.implicitHeight).y
        return Math.abs(overview.implicitHeight-Math.min(bottom,overview.maximumOverviewHeight))<=1
      }
      tryVerify(fitsContent)
      if (fixture.restoring) {
        compare(toolsState.records.timer.status,"done")
        compare(fixture.alerts.length,1)
        compare(toolsState.records.stopwatch.status,"paused")
        compare(Time.reading("stopwatch",toolsState.records.stopwatch,fixture.timestamp),12)
        compare(toolsState.records.pomodoro.status,"idle")
        compare(toolsState.pomodoroPlan.rounds,3)
        compare(toolsState.pomodoroPlan.shortBreak,2)
        compare(toolsState.records.pomodoro.step,0)
        toolsState.refresh(); compare(fixture.alerts.length,1)
      } else {
        compare(Time.parseDuration("24:00:00"),86400000)
        for (var input of ["00:00:00","00:60:00","00:00:60","24:00:01","02::","-1","abc"]) compare(Time.parseDuration(input),0)
        var primary=findChild(view,"timePrimary"), duration=findChild(view,"timeDuration")
        verify(duration.visible && duration.activeFocus)
        compare(duration.selectedText,duration.text)
        for (var digit of "020000") keyClick(Qt.Key_0+Number(digit))
        compare(duration.text,"02:00:00"); compare(duration.milliseconds,7200000)
        keyClick(Qt.Key_Backspace); verify(!primary.enabled)
        keyClick(Qt.Key_0); verify(primary.enabled)
        keyClick(Qt.Key_Return)
        compare(toolsState.records.timer.duration,7200000)
        toolsState.reset("timer"); duration.forceActiveFocus()
        for (var paste of ["000007","00:00:07"]) {
          clipboardSource.text=paste; clipboardSource.selectAll(); clipboardSource.copy()
          duration.selectAll(); keyClick(Qt.Key_V,Qt.ControlModifier)
          compare(duration.text,"00:00:07"); compare(duration.milliseconds,7000)
        }
        compare(Time.parseDuration("٠٠:٠١:٣٠","٠"),90000)
        compare(primary.text,""); compare(findChild(view,"timeReset").text,"")
        verify(primary.Accessible.name.length>0)
        keyClick(Qt.Key_Return)
        tryVerify(function(){return primary.activeFocus})
        compare(toolsState.records.timer.status,"running")
        var field=findChild(view,"timeField")
        fixture.timestamp+=100
        tryVerify(function(){return field.seconds===0.1})
        findChild(view,"timeMode-stopwatch").clicked(); primary.clicked()
        fixture.timestamp+=2500; toolsState.refresh()
        compare(Time.reading("timer",toolsState.records.timer,toolsState.now),5)
        compare(Time.reading("stopwatch",toolsState.records.stopwatch,toolsState.now),2)
        compare(findChild(view,"timeReading").text,"00:02"+Commons.I18n.decimal+"5")
        tryVerify(fitsContent)
        verify(field.live); compare(field.seconds,2.5)
        Commons.Style.reduceMotion=true
        compare(field.seconds,0)
        Commons.Style.reduceMotion=false
        compare(field.seconds,2.5)
        verify(overview.back())
        verify(!field.live)
        tryVerify(function(){return headerTime.activeFocus})
        var activity=Now.current(host)
        overview.openDetails(activity.kind,{mode:activity.row.mode})
        tryCompare(view,"mode","timer")
        compare(activity.kind,"timers")
        compare(Copy.describe(activity,view.presentation.strings,function(n){return String(n)}).label,"00:05")
        toolsState.toggle("timer"); compare(toolsState.records.timer.status,"paused")
        fixture.timestamp+=10000; toolsState.toggle("stopwatch"); compare(toolsState.records.stopwatch.elapsed,12500)
        compare(field.seconds,2.6)
        toolsState.toggle("timer"); fixture.timestamp+=4500; toolsState.refresh()
        compare(toolsState.records.timer.status,"done"); compare(fixture.alerts.length,1)
        for (var step=0;step<8;step++) {
          compare(toolsState.records.pomodoro.step,step)
          toolsState.toggle("pomodoro")
          fixture.timestamp+=(step%2===0 ? 25 : step===7 ? 15 : 5)*60000
          toolsState.refresh()
          compare(toolsState.records.pomodoro.status,"idle")
        }
        compare(toolsState.records.pomodoro.step,0); compare(fixture.alerts.length,9)
        findChild(view,"timeMode-pomodoro").clicked()
        var gear=findChild(view,"pomodoroSettings"), reset=findChild(view,"timeReset")
        wait(40)
        compare(primary.y,reset.y); compare(reset.y,gear.y)
        compare(primary.width,gear.width); compare(primary.height,gear.height)
        compare(primary.x-gear.x,reset.x-primary.x)
        gear.clicked()
        tryVerify(function(){return !!findChild(view,"plan-rounds")})
        tryVerify(fitsContent)
        var rounds=findChild(view,"plan-rounds")
        rounds.field.forceActiveFocus(); keyClick(Qt.Key_Down); keyClick(Qt.Key_Down)
        tryVerify(function(){return toolsState.pomodoroPlan.rounds===2})
        for (var pair of [["focus",7],["shortBreak",2],["longBreak",9]])
          findChild(view,"plan-"+pair[0]).modified(pair[1])
        findChild(view,"planDone").clicked()
        verify(!view.editingPlan && findChild(view,"pomodoroSettings").activeFocus)
        for (var minutes of [7,2,7,9]) {
          toolsState.toggle("pomodoro")
          compare(Time.limit("pomodoro",toolsState.records.pomodoro),minutes*60000)
          toolsState.changePlan("rounds",3)
          compare(toolsState.records.pomodoro.plan.rounds,2)
          fixture.timestamp+=minutes*60000; toolsState.refresh()
        }
        compare(toolsState.records.pomodoro.step,0)
        compare(toolsState.records.pomodoro.plan.rounds,3)
        if (Quickshell.env("ISLAND_TEST_ELSEWHEN")==="1") {
          var world=findChild(view,"timeMode-world")
          world.clicked()
          tryVerify(function(){var loader=findChild(view,"worldClockPanel"); return !!loader && !!loader.item && loader.item.opened})
          tryVerify(fitsContent)
          var panel=findChild(view,"worldClockPanel").item
          panel.addCity("Asia/Tokyo","Test City",{lat:35,lon:139})
          verify(toolsState.worldSettings.cities.some(city=>city.name==="Test City"))
          findChild(view,"timeMode-timer").clicked()
          world.clicked()
          tryVerify(function(){var loader=findChild(view,"worldClockPanel"); return loader && loader.item && loader.item.zones.some(city=>city.label==="Test City")})
          findChild(view,"timeMode-timer").clicked()
        }
        toolsState.reset("timer"); compare(toolsState.records.timer.status,"idle")
        fixture.timestamp=1000000; toolsState.toggle("timer",1000)
      }
      console.log("TIMERS_PASS"); Qt.quit()
    }
  }
  Timer {interval:100; running:true; onTriggered:{try{test.run()}catch(e){console.log("TIMERS_FAIL",e.stack);Qt.quit()}}}
}
