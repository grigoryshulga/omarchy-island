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
    Island.IslandContent {
      id:overview; anchors.fill:parent; service:host; strings:strings; expanded:true
    }
  }
  TestCase {
    id: test; parent:overview; when:false
    function run() {
      tryVerify(function(){return !!fixture.toolsState && fixture.toolsState.ready})
      findChild(overview,"openTimeTools").clicked()
      tryCompare(overview,"detailPage","timers")
      wait(60)
      var view=overview.detailItem
      if (fixture.restoring) {
        compare(toolsState.records.timer.status,"done")
        compare(fixture.alerts.length,1)
        compare(toolsState.records.stopwatch.status,"paused")
        compare(Time.reading("stopwatch",toolsState.records.stopwatch,fixture.timestamp),12)
        compare(toolsState.records.pomodoro.status,"idle")
        compare(toolsState.records.pomodoro.step,0)
        toolsState.refresh(); compare(fixture.alerts.length,1)
      } else {
        compare(Time.parseDuration("1440:00"),86400000)
        for (var input of ["0","24:60","1440:01","-1","abc"]) compare(Time.parseDuration(input),0)
        var primary=findChild(view,"timePrimary"), duration=findChild(view,"timeDuration")
        duration.text="0:00"; verify(!primary.enabled)
        duration.text="0:07"; duration.forceActiveFocus()
        keyClick(Qt.Key_Return)
        tryVerify(function(){return primary.activeFocus})
        compare(toolsState.records.timer.status,"running")
        findChild(view,"timeMode-stopwatch").clicked(); primary.clicked()
        fixture.timestamp+=2500; toolsState.refresh()
        compare(Time.reading("timer",toolsState.records.timer,toolsState.now),5)
        compare(Time.reading("stopwatch",toolsState.records.stopwatch,toolsState.now),2)
        compare(findChild(view,"timeReading").text,"00:02"+Commons.I18n.decimal+"5")
        verify(overview.back())
        var activity=Now.current(host)
        overview.openDetails(activity.kind,{mode:activity.row.mode})
        tryCompare(view,"mode","timer")
        compare(activity.kind,"timers")
        compare(Copy.describe(activity,view.presentation.strings,function(n){return String(n)}).label,"00:05")
        toolsState.toggle("timer"); compare(toolsState.records.timer.status,"paused")
        fixture.timestamp+=10000; toolsState.toggle("stopwatch"); compare(toolsState.records.stopwatch.elapsed,12500)
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
        toolsState.reset("timer"); compare(toolsState.records.timer.status,"idle")
        fixture.timestamp=1000000; toolsState.toggle("timer",1000)
      }
      console.log("TIMERS_PASS"); Qt.quit()
    }
  }
  Timer {interval:100; running:true; onTriggered:{try{test.run()}catch(e){console.log("TIMERS_FAIL",e.stack);Qt.quit()}}}
}
