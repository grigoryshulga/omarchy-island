import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/SettingsModel.mjs" as Settings
import "Island/ModuleCatalog.mjs" as Catalog

ShellRoot {
  Island.ModuleRegistry {id:registry;definitions:[Catalog.definition("sample")]}
  ModuleHost {id:service;registry:registry}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    visible:true;implicitWidth:900;implicitHeight:600
    Island.IslandContent {id:first;width:440;height:600;service:service;strings:strings;expanded:true}
    Island.IslandContent {id:second;x:450;width:440;height:600;service:service;strings:strings;expanded:true}
    Island.PopupPages {
      id:pages;width:440;height:600;visible:false
      service:service;strings:strings;expanded:true;settings:Island.Preferences.values
      onPageRequested:index=>selectedPage=index
    }
    Island.ModuleSlot {
      id:indicator
      viewSource:Catalog.definition("sample").indicator
      backend:registry.backends.sample || null
      presentation:QtObject {}
    }
    TestCase {
      id:test;when:false
      function test_modules() {
        verify(Catalog.definition("sample")!==null)
        compare(Settings.get({},"sampleEnabled"),false)
        verify(Settings.valid("sampleEnabled",true))
        verify(!Settings.valid("sampleEnabled","true"))
        verify(Settings.sections[3].groups.some(function(group){return group.id==="sample"}))
        tryVerify(function(){return !!registry.backends.sample})
        var state=registry.backends.sample
        compare(state.ticks,0)
        verify(!indicator.available)
        Island.Preferences.values={sampleEnabled:true}
        tryVerify(function(){return state.ticks>0})
        verify(indicator.available)
        tryVerify(function(){return pages.enabledPages.indexOf(4)>=0})
        pages.requestPage(4);wait(30)
        compare(pages.selectedPage,4)
        verify(findChild(pages,"samplePage")!==null)
        pages.requestPage(1);wait(20)
        var left=findChild(first,"sampleView"),right=findChild(second,"sampleView")
        verify(left!==right)
        compare(left.backend,state);compare(right.backend,state)
        left.draft="keep me";right.draft="other monitor"
        var button=findChild(first,"sampleDetails")
        button.forceActiveFocus();button.clicked();wait(40)
        compare(first.detailPage,"sample");compare(second.detailPage,"")
        verify(first.back());wait(40)
        verify(button.activeFocus)
        compare(findChild(first,"sampleView"),left)
        compare(left.draft,"keep me");compare(right.draft,"other monitor")
        button.clicked();wait(30)
        Island.Preferences.values={sampleEnabled:false};wait(50)
        compare(first.detailPage,"")
        verify(!indicator.available)
        var stopped=state.ticks;wait(70);compare(state.ticks,stopped)
        verify(!left.visible && !right.visible)
        Island.Preferences.values={sampleEnabled:true};wait(70)
        compare(registry.backends.sample,state,"Re-enable must not duplicate shared state")
        verify(state.ticks>stopped)
        compare(left.draft,"keep me")
        Island.Preferences.values={sampleEnabled:false};wait(40)
        stopped=state.ticks;wait(70);compare(state.ticks,stopped)
        console.log("MODULES_PASS");Qt.quit()
      }
    }
    Timer {interval:150;running:true;onTriggered:{try{test.test_modules()}catch(error){console.log("MODULES_FAIL",error.stack);Qt.quit()}}}
    Timer {interval:6000;running:true;onTriggered:{console.log("MODULES_TIMEOUT");Qt.quit()}}
  }
}
