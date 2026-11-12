import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/AgentLimitsModel.js" as Model
import "Island/SettingsModel.js" as Settings

ShellRoot {
  id:scene
  Island.AgentLimitsState {
    id:backend
    collector:Quickshell.env("ISLAND_LIMITS_HELPER")
    statePath:Quickshell.env("ISLAND_LIMITS_CACHE")
  }
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    id:window;visible:true;implicitWidth:540;implicitHeight:700
    Island.AgentLimitsOverview {
      id:overview;width:parent.width;expanded:true;backend:backend;strings:strings
      onSettingRequested:(key,value)=>{var next=Object.assign({},Island.Preferences.values);next[key]=value;Island.Preferences.values=next}
    }
  TestCase {
    id:test;when:false
    function check(ok,message){if(!ok){console.log("LIMITS_FAIL:",message);Qt.quit();throw new Error(message)}}
    function test_limits(){
      Island.Preferences.values={agentLimitsEnabled:true,agentLimitsIndicator:"warning"}
      tryCompare(backend,"busy",false,3000)
      tryVerify(function(){return backend.rows.length===2},3000)
      check(backend.automatic.length===1 && backend.summary.length===1,"automatic low quota")
      check(backend.indicatorVisible && backend.tightest.remaining===8,"clock policy")
      backend.error="invalid";wait(20)
      check(backend.rows[0].stale,"cache failure looks freshly measured")
      backend.error=""
      check(backend.catalog.length===2,"provider catalog")
      tryCompare(backend,"busy",false,3000)
      backend.change("codex","disable","","global")
      tryVerify(function(){return backend.catalog.length===2 && !backend.catalog[0].enabled},3000)
      tryCompare(backend,"busy",false,3000)
      var summaryPin=findChild(overview,"limitPin")
      check(summaryPin && !summaryPin.visible,"compact summary still exposes pin editing")
      var forward=findChild(overview,"limitsExpand"),forwardIcon=forward.iconText
      forward.clicked();wait(30)
      var center=findChild(overview,"limitsCenterScroll")
      var pin=findChild(center,"limitPin")
      check(pin && pin.visible,"pin control missing")
      pin.forceActiveFocus();keyClick(Qt.Key_Space);wait(30)
      check(backend.pins.length===1,"keyboard pin not persisted")
      var cache=JSON.parse(JSON.stringify(backend.cache));cache.providers[0].limits[0].percent=91
      cache.providers[0].limits[0].resetsAt=new Date(backend.now+(26*60+5)*60000).toISOString()
      backend.cache=cache;wait(30)
      check(pin.activeFocus && findChild(center,"limitPin")===pin,"refresh destroyed focus/delegate")
      var countdown=findChild(center,"limitResetCountdown")
      check(countdown.text===strings.t("limits.resetIn").arg(strings.t("limits.daysHoursMinutes").arg(Commons.I18n.formatNumber(1)).arg(Commons.I18n.formatNumber(2)).arg(Commons.I18n.formatNumber(5))),"quota caption is not a relative countdown")
      forward.clicked();wait(30)
      check(forward.text==="" && forward.iconText!=="" && forward.tooltipText===strings.t("limits.all"),"limits navigation is not an accessible icon button")
      if(Quickshell.env("ISLAND_LIMITS_CAPTURE")) grabImage(window.contentItem).save(Quickshell.env("ISLAND_LIMITS_CAPTURE")+"/summary.png")
      findChild(overview,"limitsExpand").clicked();wait(30)
      check(overview.centerOpen,"center did not expand")
      check(forward.iconText!==forwardIcon && forward.tooltipText===strings.t("calendar.back"),"center has no back arrow")
      forward.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
      check(!overview.centerOpen && forward.iconText===forwardIcon,"back arrow did not restore summary")
      keyClick(Qt.Key_Return);wait(20)
      check(overview.centerOpen,"forward arrow did not reopen center")
      check(center && center.visible && center.height<=Commons.Style.space(300),"center unbounded")
      if(Quickshell.env("ISLAND_LIMITS_CAPTURE")) grabImage(window.contentItem).save(Quickshell.env("ISLAND_LIMITS_CAPTURE")+"/center.png")
      var centerRoot=center.parent
      centerRoot.tab="usage";wait(30)
      check(findChild(centerRoot,"agentProviderTotals-codex").text.indexOf("100")>=0,"usage total lost snapshot data")
      centerRoot.tab="cost";wait(30)
      centerRoot.tab="providers";wait(30)
      centerRoot.tab="limits";wait(30)
      var oldRadius=Commons.Style.cornerRadius
      Commons.Style.cornerRadius=0;Commons.Style.reduceMotion=true;wait(20)
      check(Island.Design.cardRadius===0 && Island.Preferences.reduceMotion,"theme settings not inherited")
      Commons.Style.cornerRadius=oldRadius;Commons.Style.reduceMotion=false
      overview.width=360;wait(30)
      check(center.width<=360 && center.contentWidth<=360,"narrow center overflows")
      cache=JSON.parse(JSON.stringify(backend.cache));cache.providers[0].limits[0].percent=0;cache.providers[0].limits[0].rolledWindows=1
      backend.cache=cache;wait(30)
      check(backend.rows[0].remaining===null && backend.automatic.length===1,"unconfirmed reset lost warning")
      cache=JSON.parse(JSON.stringify(backend.cache));cache.providers[0].limits[0].rolledWindows=0;cache.providers[0].limits[0].percent=20
      backend.cache=cache;wait(30)
      check(backend.automatic.length===0 && backend.summary.length===1,"pin lost after recovery")
      overview.expanded=false;wait(20)
      check(!overview.centerOpen && !findChild(overview,"limitPin").visible,"hover preview is interactive")
      Island.Preferences.values={agentLimitsEnabled:false};wait(50)
      check(!backend.busy && backend.rows.length===0 && !backend.indicatorVisible,"disable retained work")
      console.log("LIMITS_PASS");Qt.quit()
    }
  }
  Timer {interval:150;running:true;onTriggered:{try {test.test_limits()} catch(e){console.log("LIMITS_FAIL",e,e.stack);Qt.quit()}}}
  }
}
