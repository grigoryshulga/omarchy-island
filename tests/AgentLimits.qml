import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/AgentLimitsModel.js" as Model
import "Island/SettingsModel.mjs" as Settings

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
    color:Island.Design.opaqueCanvas
    Island.AgentLimitsOverview {
      onDetailsRequested:centerOpen=!centerOpen
      onExpandedChanged:if(!expanded) centerOpen=false
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
      // Catalog loading can schedule a second sync after the first one finishes.
      wait(300);tryCompare(backend,"busy",false,3000)
      check(backend.automatic.length===1 && backend.summary.length===1,"automatic low quota")
      check(backend.indicatorVisible && backend.tightest.remaining===8,"clock policy")
      backend.error="sync";wait(20)
      check(backend.rows[0].stale,"cache failure looks freshly measured")
      backend.error=""
      check(backend.catalog.length===2,"provider catalog")
      tryCompare(backend,"busy",false,3000)
      backend.change("codex","disable","","global")
      tryVerify(function(){return backend.catalog.length===2 && !backend.catalog[0].enabled},3000)
      tryCompare(backend,"busy",false,3000)
      // Configuration also schedules a sync and an asynchronous snapshot reload.
      wait(300);tryCompare(backend,"busy",false,3000)
      var summaryPin=findChild(overview,"limitPin")
      check(summaryPin && !summaryPin.visible,"compact summary still exposes pin editing")
      var forward=findChild(overview,"limitsExpand"),forwardIcon=forward.iconText
      forward.clicked();wait(30)
      var center=findChild(overview,"limitsCenterContent")
      var status=findChild(center.parent,"limitsCenterStatus")
      tryVerify(function(){return !status.visible},3000)
      backend.error="sync";wait(20)
      check(status.visible && status.text===strings.t("limits.error"),"center lost its error status")
      backend.error="";wait(20)
      var detailGauge=findChild(center,"limitBrailleProgress")
      check(detailGauge.width===center.width,"detail gauge still has card padding")
      check(detailGauge.height===findChild(overview,"limitBrailleProgress").height,"detail and summary gauge heights differ")
      check(findChild(center,"limitName").font.pixelSize===findChild(overview,"limitName").font.pixelSize,"detail and summary typography differs")
      var pin=findChild(center,"limitPin")
      check(findChild(center,"limitsProviderName").text==="Codex","provider heading missing")
      check(findChild(center,"limitName").text===strings.t("limits.window.weekly"),"window name repeats provider")
      check(findChild(center,"limitFreshness").text===strings.t("limits.checkedUnknown"),"unknown check time treated as fresh")
      check(!findChild(center,"limitMoveUp").visible,"pin order controls clutter normal view")
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
      check(forward.text==="" && forward.iconText==="" && forward.title===strings.t("limits.title") && forward.Accessible.name===forward.title,"limits navigation is not an accessible heading")
      var gauge=findChild(overview,"limitBrailleProgress"), summaryReset=findChild(overview,"limitResetCountdown")
      check(gauge && gauge.visible && gauge.width>Commons.Style.space(104),"summary gauge is not full width")
      check(summaryReset.visible && summaryReset.text===countdown.text,"summary reset countdown missing")
      check(gauge.accent.toString()===Island.Design.warning.toString(),"warning threshold color missing")
      Island.Preferences.values=Object.assign({},Island.Preferences.values,{agentLimitsWarning:10,agentLimitsCritical:9});wait(20)
      check(gauge.accent.toString()===Island.Design.danger.toString(),"configured critical threshold color missing")
      Island.Preferences.values=Object.assign({},Island.Preferences.values,{agentLimitsWarning:5,agentLimitsCritical:2});wait(20)
      check(gauge.accent.toString()===Island.Design.accent.toString(),"configured normal color missing")
      Island.Preferences.values=Object.assign({},Island.Preferences.values,{agentLimitsWarning:20,agentLimitsCritical:5});wait(20)

      if(Quickshell.env("ISLAND_LIMITS_CAPTURE")) grabImage(window.contentItem).save(Quickshell.env("ISLAND_LIMITS_CAPTURE")+"/summary.png")
      findChild(overview,"limitsExpand").clicked();wait(30)
      check(overview.centerOpen,"center did not expand")
      check(forward.iconText==="" && forward.title===strings.t("limits.title"),"center heading changed into an arrow")
      forward.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
      check(!overview.centerOpen && forward.iconText===forwardIcon,"heading did not restore summary")
      keyClick(Qt.Key_Return);wait(20)
      check(overview.centerOpen,"heading did not reopen center")
      check(center && center.visible && center.height===center.implicitHeight,"center content was clipped")
      if(Quickshell.env("ISLAND_LIMITS_CAPTURE")) grabImage(window.contentItem).save(Quickshell.env("ISLAND_LIMITS_CAPTURE")+"/center.png")
      var centerRoot=center.parent
      centerRoot.tab="usage";wait(30)
      check(findChild(centerRoot,"agentProviderTotals-codex").text.indexOf("100")>=0,"usage total lost snapshot data")
      centerRoot.tab="cost";wait(30)
      centerRoot.tab="providers";wait(30)
      centerRoot.tab="limits";wait(30)
      // Pin ordering is explicit, keyboard-operable and keeps delegate focus.
      var second=findChild(center,"limitDetail-"+Model.key("codex","Session"))
      findChild(second,"limitPin").clicked();wait(20)
      var editPins=findChild(center,"limitsEditPins")
      editPins.forceActiveFocus();keyClick(Qt.Key_Space);wait(20)
      var down=findChild(center,"limitMoveDown")
      check(down.visible && down.enabled,"pin ordering not revealed")
      down.forceActiveFocus();keyClick(Qt.Key_Space);wait(20)
      check(backend.pins[1]===Model.key("codex","Weekly"),"pin order not saved")
      check(findChild(center,"limitMoveUp").activeFocus && findChild(center,"limitMoveDown")===down,"boundary move lost focus or recreated delegate")
      editPins.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
      check(!down.visible && editPins.activeFocus,"finishing pin editing lost focus")
      findChild(second,"limitPin").clicked();wait(20)

      var oldRadius=Commons.Style.cornerRadius
      Commons.Style.cornerRadius=0;Commons.Style.reduceMotion=true;wait(20)
      check(Island.Design.cardRadius===0 && Island.Preferences.reduceMotion,"theme settings not inherited")
      Commons.Style.cornerRadius=oldRadius;Commons.Style.reduceMotion=false
      overview.width=360;wait(30)
      check(center.width<=360,"narrow center overflows")
      var oldFont=Commons.Style.fontBaseSize
      Commons.Style.fontBaseSize=18;wait(30)
      check(findChild(center,"limitRemaining").width>0 && countdown.width<=360,"large text overflow")
      Commons.Style.fontBaseSize=oldFont
      // Additional providers retain identity on refresh and never fabricate quota values.
      cache=JSON.parse(JSON.stringify(backend.cache))
      cache.providers[0].limitsCheckedAt=backend.now-180000
      cache.providers.push({id:"deepseek",name:"DeepSeek",balance:[{currency:"USD",total:0}]})
      cache.providers.push({id:"openai-api",name:"OpenAI API"})
      backend.cache=cache;wait(20)
      var balanceGroup=findChild(center,"limitsProvider-deepseek")
      check(findChild(balanceGroup,"limitsProviderBalance").visible,"zero balance hidden")
      check(!findChild(balanceGroup,"limitRemaining"),"balance-only provider gained quota")
      check(findChild(findChild(center,"limitsProvider-openai-api"),"limitsProviderEmpty").text===strings.t("limits.localOnly"),"local-only provider shown as failure")
      check(findChild(center,"limitFreshness").text===strings.t("limits.checkedMinutes").arg(Commons.I18n.formatNumber(3)),"freshness missing")
      cache.providers[0].status="error";backend.cache=JSON.parse(JSON.stringify(cache));wait(20)
      check(findChild(center,"limitFreshness").text===strings.t("limits.cached"),"failed provider still looks fresh")
      cache.providers[0].status="ready";cache.providers=cache.providers.slice(0,1);backend.cache=cache;wait(20)
      check(!findChild(center,"limitsProvider-deepseek"),"removed provider retained")
      cache=JSON.parse(JSON.stringify(backend.cache));cache.providers[0].limits[0].percent=0;cache.providers[0].limits[0].rolledWindows=1
      backend.cache=cache;wait(30)
      check(backend.rows[0].remaining===null && backend.automatic.length===1,"unconfirmed reset lost warning")
      check(!findChild(center,"limitBrailleProgress").visible && countdown.text===strings.t("limits.awaitingReset"),"pending reset displayed as full allowance")
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
