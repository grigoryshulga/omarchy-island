import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "Island" as Island
import "Bridge" as Bridge
import "Island/modules/timers" as Timers

ShellRoot {
  id:scene
  property var commands:[]
  property bool mockNightLight:false
  property bool mockStayAwake:false
  Commons.ShellIpc {target:"nightlight";function toggle():void{scene.mockNightLight=!scene.mockNightLight} function status():string{return JSON.stringify({enabled:scene.mockNightLight})}}
  Commons.ShellIpc {target:"idle";function toggle():void{scene.mockStayAwake=!scene.mockStayAwake} function status():string{return JSON.stringify({stayAwake:scene.mockStayAwake})}}
  Timers.State {id:timers;execute:function(argv){}}
  Island.IndicatorState {id:backend;layouts.observeSystem:false}
  QtObject {
    id:states
    property bool updateAvailable:false
    property bool recording:false
    property bool remoteActive:false
    property bool microphoneMuted:false
    property bool nightLight:backend.nightLight
    property bool stayAwake:backend.stayAwake
    property bool osdActive:backend.osdActive
    property string osdKind:backend.osdKind
    property real osdValue:backend.osdValue
    property bool osdMuted:backend.osdMuted
    property bool osdHasProgress:backend.osdHasProgress
    property string osdIcon:backend.osdIcon
    property string osdMessage:backend.osdMessage
    property string osdProgressText:backend.osdProgressText
    property string osdScreen:""
    function refreshControls(){backend.refreshControls()}
    function attach(item){backend.attach(item)}
    function detach(item){backend.detach(item)}
  }
  QtObject {
    id:t3State
    property bool allowed:false
    property int waitingCount:0
    property int workingCount:0
    property int finishedCount:0
    property int failedCount:0
    readonly property var counts:({attention:waitingCount,finished:finishedCount,failed:failedCount,working:workingCount})
    property bool canRespond:false
    property bool connected:false
    function row(id){return rows.find(r=>r.id===id)}
    property string status:"offline"
    property var rows:[]
  }
  QtObject {
    id:service
    property var reminders:QtObject {
      property var rows:[]
      readonly property int count:rows.length
      property double now:Date.now()/1000
      property bool busy:false
      property string error:""
    }
    property var agentLimits:QtObject {
      property bool allowed:false
      property bool indicatorVisible:false
      property var tightest:({name:"Codex",label:"Weekly",remaining:8,stale:false})
      property var summary:[]
      property var rows:[]
      property var pins:[]
      property var catalog:[]
      property var cache:({providers:[]})
      property double now:Date.now()
      property string error:""
      property bool busy:false
      function loadCatalog(){}
    }
    property var controlBackend:Island.ControlsState {panelCommand:[];outputCommand:["true"];tailscaleCommand:["true"]}
    readonly property var modules:({timers:timers,controls:controlBackend,weather:("weather" in service) ? service.weather : null,calendar:{allowed:true,calendars:("calendars" in service) ? service.calendars : null,reminders:("reminders" in service) ? service.reminders : null},notifications:service,media:service,t3:t3,agentLimits:agentLimits})
    property var t3:t3State
    property var indicators:states
    property bool doNotDisturb:false
    property var player:null
    property bool hasMedia:false
    property bool playing:false
    property string track:""
    property string targetScreen:""
    property string focusedScreenName:""
    property var latest:null
    readonly property var activeEntries: allEntries
    property var historyEntries: []
    property var allEntries:[]
    property var allowedPlayers:[]
    property var downloads:[]
    property var players:[]
    property var mutedSources:[]
    property string error:""
    property real visualPhase:0
    property real audioLevel:0
    property real audioBass:0
    property real audioTreble:0
    signal arrivalChanged()
    function setDoNotDisturb(value){doNotDisturb=value}
    function actions(row){return []}
  }
  Commons.ShellIpc {target:"island-osd";function show(payload:string):string{return backend.showOsd(payload) ? "ok" : "unavailable"} function hide():string{backend.hideOsd();return "ok"}}
  Bridge.Panel {id:bridge}
  QtObject {id:shell;function serviceFor(id){return service} function updateEntryInline(id,entry){return true}}
  QtObject {
    id:bar
    property var shell:shell
    property string position:"top"
    property bool vertical:false
    property int barSize:30
    property color background:"#101315"
    property color foreground:"white"
    property color barForeground:"white"
    property color urgent:"red"
    property string fontFamily:"monospace"
    property bool foregroundAnimationEnabled:true
    property bool transparent:false
    property var activePopout:null
    property var clickTargets:[]
    function registerClickTarget(t){if(!clickTargets.includes(t)) clickTargets=clickTargets.concat([t])}
    function unregisterClickTarget(t){clickTargets=clickTargets.filter(item=>item!==t)}

    function showTooltip(t,s){}
    function hideTooltip(t){}
    function requestPopout(t){activePopout=t}
    function releasePopout(t){activePopout=null}
  }
  FloatingWindow {
    visible:true
    implicitWidth:620;implicitHeight:bar.vertical ? 620 : 80
    Island.BarWidget {id:widget;execute:function(argv){scene.commands=scene.commands.concat([argv])};x:fixedEdge==="start" ? 0 : fixedEdge==="end" ? parent.width-width : (parent.width-width)/2;y:bar.vertical ? (fixedEdge==="start" ? 0 : fixedEdge==="end" ? parent.height-height : (parent.height-height)/2) : (parent.height-height)/2;width:implicitWidth;height:implicitHeight;bar:bar}
    MouseArea {
      id:barPointer;anchors.fill:parent;enabled:false
      onClicked:mouse=>{
        for(var i=bar.clickTargets.length-1;i>=0;i--) {
          var button=bar.clickTargets[i]
          if (button.interactive!==false && Commons.Util.itemContainsPoint(button,barPointer,mouse.x,mouse.y)) {
            button.triggerPress(mouse.button)
            return
          }
        }
      }
    }
  }
  LazyLoader {
    id:secondOutput
    active:!!Quickshell.env("ISLAND_PANEL_LAYOUT") && Quickshell.screens.length>1 && widget.screenName!==""
    PanelWindow {
      property alias activityWidget:secondWidget
      screen:Quickshell.screens.find(output=>output.name!==widget.screenName)
      anchors {top:true;left:true;right:true}
      implicitHeight:30
      Island.BarWidget {id:secondWidget;bar:widget.bar;height:30;width:implicitWidth;hoverSuppressed:true}
    }
  }
  TestCase {
    id:test
    when:false
    function check(ok,message){if(!ok){console.log("INDICATORS_FAIL:",message);Qt.quit();throw new Error(message)}}
    function osd(icon,value,max,duration){return Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:icon,value:value,max:max,duration:duration})])}
    function checkEventLayout(gauge,clock) {
      var row=findChild(gauge,"islandOsdEvent"),icon=findChild(row,"islandOsdEventIcon"),message=findChild(row,"islandOsdMessage")
      var at=row.mapToItem(clock,0,0)
      check(Math.abs(at.x+row.width/2-clock.width/2)<1,"event icon and text are not centered on the clock")
      check(at.x>=0 && at.x+row.width<=clock.width,"event message overflowed the widget")
      if(message.visible) check(Math.abs(icon.y+icon.height/2-message.y-message.height/2)<1,"event icon and text are vertically misaligned")
    }
    function test_panelLayout() {
      Commons.Style.reduceMotion=true
      states.recording=true;states.remoteActive=true;states.updateAvailable=true
      states.microphoneMuted=true;service.doNotDisturb=true
      scene.mockNightLight=true;scene.mockStayAwake=true
      t3State.allowed=true;t3State.waitingCount=3
      service.reminders.rows=[{unit:"test",label:"Check the oven",at:Date.now()/1000+300}]
      service.downloads=[{key:"demo",filename:"demo.iso",downloadPath:"/downloads/demo.iso",downloadedBytes:8192,active:true,ts:1}]
      widget.updateSetting("clockLayout",widget.clockLayout.concat([{id:"now",kind:"indicator",side:"left"}]))
      widget.hoverSuppressed=true
      var popup=findChild(widget,"islandPopup"),clock=findChild(widget,"islandClock")
      for (var edge of ["top","bottom","left","right"]) {
        bar.position=edge;bar.vertical=edge==="left" || edge==="right"
        for (var fixed of ["start","center","end"]) {
          widget.fixedEdge=fixed
          widget.open();wait(120)
          var card=findChild(popup,"islandPopupCard")
          check(card.x>=popup.margin-1 && card.x+card.width<=popup.width-popup.margin+1,"card escaped screen on "+edge)
          check(card.y>=popup.margin-1 && card.y+card.height<=popup.height-popup.margin+1,"card escaped screen vertically on "+edge)
          var activity=findChild(widget,"islandNowIndicator")
          check(activity.visible && (bar.vertical ? activity.text==="" : activity.text.includes("KiB")),"missing Now activity on "+edge)
          var label=findChild(widget,"islandClockText")
          for (var name of ["islandLeftIndicators","islandRightIndicators"]) {
            var indicators=findChild(widget,name)
            indicators.ensurePolished()
            check(indicators.x>=-1 && indicators.x+indicators.width<=clock.width+1,"indicators escaped clock width on "+edge)
            check(indicators.y>=-1 && indicators.y+indicators.height<=clock.height+1,"indicators escaped clock height on "+edge)
            if (bar.vertical) {
              var at=label.mapToItem(clock,0,0)
              check(indicators.y+indicators.height<=at.y+1 || indicators.y>=at.y+label.height-1,"indicators overlapped clock on "+edge)
            }
          }
          if (bar.vertical) {
            backend.showOsd(JSON.stringify({icon:"audio-volume-high",value:50,max:100,duration:2000}))
            wait(30)
            check(findChild(widget,"islandVerticalOsd").visible,"vertical OSD missing")
            check(!findChild(widget,"islandOsdGauge").visible,"horizontal gauge visible in side panel")
            backend.hideOsd()
          }
          widget.close();wait(20)
        }
      }
      if (secondOutput.active) {
        tryVerify(function(){return secondOutput.item && secondOutput.item.activityWidget.screenName &&
          secondOutput.item.activityWidget.screenName!==widget.screenName})
        var second=secondOutput.item.activityWidget
        service.doNotDisturb=false
        service.targetScreen=widget.screenName
        service.focusedScreenName=second.screenName
        service.playing=true;service.track="track on second output"
        check(!widget.showAlert && second.alertKind==="media" && second.showAlert,"track went to the notification output")
        service.focusedScreenName=widget.screenName
        service.track="track on first output"
        check(widget.showAlert && !second.showAlert,"previous track remained on the other output")
        service.doNotDisturb=true
        service.track="quiet"
        check(!widget.showAlert && !second.showAlert,"track toast bypassed DND")
        console.log("MEDIA_OUTPUTS_PASS")
      }
      console.log("PANEL_LAYOUT_PASS")
      Qt.quit()
    }
    function test_indicators(){
      widget.updateSetting("format","HH:mm")
      var tick=findChild(widget,"islandClockTick")
      check(tick && tick.step===60000,"minute clock must not tick every second")
      check(tick.interval>0 && tick.interval<=60000,"minute clock must align to the next epoch minute")
      widget.updateSetting("format","HH:mm:ss")
      check(tick.step===1000 && tick.interval>0 && tick.interval<=1000,"seconds clock must rearm immediately")
      widget.updateSetting("format","HH:mm 'seconds'")
      check(tick.step===60000,"literal seconds must not enable second ticks")
      widget.updateSetting("format","dddd HH:mm")
      wait(100)
      var clock=findChild(widget,"islandClock"),label=findChild(widget,"islandClockText"),gauge=findChild(widget,"islandOsdGauge"),display=findChild(widget,"islandClockDisplay")
      check(!backend.osdActive,"layout flashed at startup")
      backend.layouts.seed(JSON.stringify({keyboards:[{name:"kbd",active_keymap:"English (US)",active_layout_index:0}]}),backend.layouts.revision)
      check(!backend.osdActive,"seeding the layout showed an OSD")
      backend.layouts.handleEvent({name:"activelayout",data:"kbd,Russian"})
      wait(45)
      check(widget.osdTransitioning && widget.osdShown>0 && widget.osdShown<1 && label.visible && gauge.visible,"clock-to-OSD transition did not crossfade both displays")
      if(Quickshell.env("ISLAND_TEST_GPU")) check(display.layer.enabled && display.layer.effect!==null,"GPU transition did not enable braille pixelation")
      else check(!display.layer.enabled,"software rendering did not retain the plain crossfade")
      wait(240)
      tryVerify(function(){return !widget.osdTransitioning},300)
      check(!widget.osdTransitioning,"settled OSD kept its transition layer")
      check(display.layer.effect===null,"settled OSD kept its dissolve shader")
      check(gauge.visible && !label.visible && gauge.kind==="layout" && gauge.message==="Русский" && !gauge.hasProgress,"layout did not replace the clock with its full name")
      var serial=backend.osdSerial
      backend.layouts.handleEvent({name:"activelayout",data:"power-button,English (US)"})
      backend.layouts.handleEvent({name:"activelayout",data:"kbd,Russian"})
      check(backend.osdSerial===serial,"duplicate/virtual layout events restarted OSD")
      backend.layouts.seed(JSON.stringify({keyboards:[{name:"kbd",active_keymap:"English (US)"}]}),backend.layouts.revision-1)
      check(backend.layouts.currentLanguage==="Русский","stale baseline overwrote a layout event")
      wait(650)
      backend.layouts.handleEvent({name:"activelayout",data:"kbd,English (US)"})
      wait(650)
      check(backend.osdActive && gauge.message==="English","rapid layout switch did not replace the message or extend timer")
      wait(800)
      tryVerify(function(){return !widget.osdTransitioning && !gauge.visible},300)
      check(!backend.osdActive && label.visible && !gauge.visible,"clock did not return after layout OSD: "+JSON.stringify({active:backend.osdActive,shown:widget.osdShown,clock:label.visible,gauge:gauge.visible}))
      check(!findChild(widget,"islandRecordingIndicator").visible && !findChild(widget,"islandMicrophoneIndicator").visible,"inactive indicators are visible")
      var t3Indicator=findChild(widget,"islandT3Indicator")
      check(!t3Indicator.visible,"disabled T3 indicator is visible")
      t3State.allowed=true;t3State.workingCount=3;wait(25)
      check(!t3Indicator.visible,"Running work should stay off the bar")
      t3State.finishedCount=4;wait(25)
      check(t3Indicator.visible && t3Indicator.text===Commons.I18n.formatNumber(4),"Completed count missing")
      var count=findChild(widget,"islandT3Count")
      check(Math.abs(count.mapToItem(clock,0,count.baselineOffset).y-label.mapToItem(clock,0,label.baselineOffset).y)<1,"T3 count and clock baselines differ")
      t3State.failedCount=1;wait(25)
      check(t3Indicator.text===Commons.I18n.formatNumber(1),"Failure hidden by completions")
      t3State.waitingCount=2;wait(25)
      check(t3Indicator.text===Commons.I18n.formatNumber(2),"Pending input hidden by other activity")
      var clockAt=label.mapToItem(clock,0,0)
      check(Math.abs(clockAt.x+label.width/2-clock.width/2)<1,"T3 indicator moved the clock off center")
      t3State.rows=[{id:"ready",title:"Ready to review",project:"Island",requestId:"",summary:"Done",status:"completed"}];t3State.connected=true
      var savedLayout=widget.clockLayout,storedLayout=widget.settings.clockLayout || null
      if (!savedLayout.some(row=>row.id==="now"))
        widget.updateSetting("clockLayout",savedLayout.concat([{id:"now",kind:"indicator",side:"left"}]))
      tryVerify(function(){return timers.ready})
      timers.toggle("pomodoro")
      var nowButton=findChild(widget,"islandNowIndicator"),pages=findChild(widget,"islandPopupPages")
      tryVerify(function(){return nowButton.visible && nowButton.activity && nowButton.activity.kind==="timers"})
      barPointer.enabled=true
      wait(80)
      var timerPoint=nowButton.mapToItem(barPointer,nowButton.width/2,nowButton.height/2)
      mouseClick(barPointer,timerPoint.x,timerPoint.y)
      tryCompare(pages,"detailPage","timers",800)
      tryVerify(function(){return findChild(pages,"timeMode-pomodoro").selected})
      var popup=findChild(widget,"islandPopup"),outside=findChild(popup,"islandOutside")
      t3Indicator=findChild(widget,"islandT3Indicator")
      var t3Point=t3Indicator.mapToItem(barPointer,t3Indicator.width/2,t3Indicator.height/2)
      mouseClick(outside,t3Point.x,t3Point.y)
      tryCompare(pages,"detailPage","t3")
      var readyCard=findChild(pages,"t3Session-ready")
      check(readyCard && readyCard.visible && pages.implicitHeight<pages.calendarWeatherHeight,"T3 page does not fit one thread")
      widget.close(true);tryCompare(popup,"visible",false,1000)
      mouseClick(barPointer,t3Point.x,t3Point.y)
      tryCompare(pages,"detailPage","t3")
      widget.close(true);barPointer.enabled=false
      timers.reset("pomodoro");widget.updateSetting("clockLayout",storedLayout)
      t3State.connected=false;t3State.rows=[]
      t3State.waitingCount=0;t3State.finishedCount=0;t3State.failedCount=0;wait(25)
      check(!t3Indicator.visible,"settled T3 sessions kept the bar indicator")
      t3State.allowed=false
      console.log("T3_INDICATOR_PASS")
      var reminderBadge=findChild(widget,"islandReminderIndicator")
      check(!reminderBadge.visible,"Empty reminders badge is visible")
      service.reminders.rows=[{unit:"test",label:"Check the oven",at:Date.now()/1000+300}];wait(30)
      check(reminderBadge.visible && reminderBadge.tooltipText.indexOf("Check the oven")>=0,"Reminder badge is missing its nearest reminder")
      check(reminderBadge.mapToItem(clock,0,0).x>label.mapToItem(clock,0,0).x+label.width,"Reminders must be right of the clock")
      check(Math.abs(label.mapToItem(clock,0,0).x+label.width/2-clock.width/2)<1,"Reminders moved the centered clock")
      reminderBadge.clicked();wait(30)
      check(widget.pinned && widget.calendarMode,"Reminder badge did not open Calendar")
      widget.close();service.reminders.rows=[];wait(30)
      check(!reminderBadge.visible,"Cleared reminders left a badge")
      console.log("REMINDERS_INDICATOR_PASS")
      var limitIndicator=findChild(widget,"islandAgentLimitsIndicator")
      check(!limitIndicator.visible,"disabled limit indicator is visible")
      service.agentLimits.allowed=true;service.agentLimits.indicatorVisible=true;wait(40)
      check(limitIndicator.visible && limitIndicator.implicitWidth>0,"limit indicator missing")
      check(clock.tooltipText.indexOf("Codex")>=0 && clock.tooltipText.indexOf("Weekly")>=0,"limit indicator tooltip lost provider/window")
      check(limitIndicator.mapToItem(clock,0,0).x+limitIndicator.width<label.mapToItem(clock,0,0).x,"limit indicator overlaps clock")
      var limitsButton=findChild(limitIndicator,"moduleIndicatorAction")
      mouseClick(limitsButton,limitsButton.width/2,limitsButton.height/2);wait(60)
      check(widget.pinned && findChild(widget,"islandPopupPages").detailPage==="agentLimits","Limit indicator did not open its center")
      widget.close();wait(40)
      service.agentLimits.indicatorVisible=false;service.agentLimits.allowed=false;wait(20)
      if(Quickshell.env("ISLAND_T3_ONLY")) {console.log("INDICATORS_PASS");Qt.quit();return}
      if(Quickshell.env("ISLAND_TEST_GPU")) {
        var frozen=new Date(2026,10,10,19,47),saved=widget.now
        widget.now=frozen;wait(30)
        var beforeClock=grabImage(label)
        backend.stayAwake=true;wait(80);widget.now=frozen
        check(beforeClock.equals(grabImage(label)),"Awake indicator changed clock glyph rasterization")
        backend.stayAwake=false;widget.now=saved;wait(30)
        console.log("STABLE_CLOCK_PIXELS_PASS")
      }
      var update=findChild(widget,"islandUpdateIndicator")
      check(!update.visible,"inactive update indicator is visible")
      states.updateAvailable=true;wait(220)
      check(update.visible && update.bidirectional && update.glyph!=="", "update indicator or bidirectional wave missing")
      var wave=update.children[0],origin=wave.mapToItem(clock,wave.origin.x,wave.origin.y),icon=update.mapToItem(clock,update.width/2,update.height/2)
      check(Math.abs(origin.x-icon.x)<1 && wave.x<0 && wave.x+wave.width>update.width,"update waves do not spread from the icon in both directions")
      check(update.mapToItem(clock,0,0).x>clock.width/2+label.contentWidth/2,"update indicator is not right of clock")
      states.updateAvailable=false;wait(220)
      check(!update.visible,"update indicator did not clear")
      states.recording=true;states.remoteActive=true;states.microphoneMuted=true;scene.mockNightLight=true;scene.mockStayAwake=true;backend.refreshControls();service.doNotDisturb=true
      check(backend.nightLight && backend.stayAwake,"native idle/nightlight IPC state was not read")
      check(backend.osdActive && backend.osdIcon==="","mode toggle did not show its OSD")
      backend.hideOsd()
      wait(260)
      var recording=findChild(widget,"islandRecordingIndicator"),remote=findChild(widget,"islandRemoteIndicator"),left=findChild(widget,"islandLeftIndicators"),right=findChild(widget,"islandRightIndicators")
      check(recording.visible && remote.visible && recording.tint.r>recording.tint.g && remote.tint.g>remote.tint.r,"capture indicator colors or states are wrong")
      var at=label.mapToItem(clock,0,0)
      check(Math.abs(at.x+label.width/2-clock.width/2)<1,"indicators moved the clock off center")
      check(left.x>=0 && left.x+left.width<=clock.width/2-Math.min(label.width,label.contentWidth)/2 && right.x>=clock.width/2 && right.x+right.width<=clock.width,"indicator sides overlap the clock or overflow")
      for(var name of ["islandMicrophoneIndicator","islandDndIndicator","islandNightLightIndicator","islandStayAwakeIndicator"]) check(findChild(widget,name).visible,"active indicator missing: "+name)
      states.updateAvailable=true;wait(30)
      for(var mode of ["microphone","recording","update","nightLight","stayAwake","dnd","remote"]) {
        var action=findChild(widget,"indicatorAction-"+mode)
        check(action && action.visible && action.height>=bar.barSize,"Indicator has no bar-height hit area: "+mode)
        mouseClick(action,action.width/2,action.height/2);wait(40)
        if(mode!=="update") {
          var pages=findChild(widget,"islandPopupPages")
          check(pages.detailPage===(mode==="dnd" ? "notifications" : "controls"),mode+" routed to "+pages.detailPage)
          if(mode==="microphone") check(findChild(pages,"islandControls").section==="audio","Audio section did not open")
          if(mode==="dnd") check(service.doNotDisturb,"Navigation changed DND")
          if(mode==="nightLight") check(backend.nightLight,"Navigation changed night light")
          if(mode==="stayAwake") check(backend.stayAwake,"Navigation changed idle")
          if(["nightLight","stayAwake","recording"].includes(mode)) {
            var tile=findChild(pages,"control"+mode.charAt(0).toUpperCase()+mode.slice(1))
            check(tile && tile.focus,"Missing focus on "+mode)
          }
          widget.close();wait(50)
          if(mode!=="remote") mouseClick(action,action.width/2,action.height/2,Qt.RightButton)
        }
        if(mode==="dnd") check(!service.doNotDisturb,"DND indicator did not turn off DND")
        if(mode==="nightLight") check(!backend.nightLight,"Night light indicator did not turn off mode")
        if(mode==="stayAwake") check(!backend.stayAwake,"Stay awake indicator did not turn off mode")

      }
      check(JSON.stringify(scene.commands)===JSON.stringify([["omarchy-audio-input-mute"],["omarchy-capture-screenrecording","--stop-recording"],["omarchy-launch-floating-terminal-with-presentation","omarchy-update"]]),"Indicator command arguments changed")
      widget.close();wait(40)
      console.log("INDICATOR_ACTIONS_PASS")
      check(osd("volume-muted",75,100,700).output==="ok" && backend.osdActive && !bridge.opened,"native volume OSD was not routed to Island")
      wait(270)
      tryVerify(function(){return !label.visible},300)
      check(gauge.muted && gauge.visible && !label.visible && gauge.kind==="volume" && Math.abs(gauge.value-0.75)<0.01,"volume gauge did not replace clock: "+JSON.stringify({muted:gauge.muted,visible:gauge.visible,clock:label.visible,opacity:label.opacity,kind:gauge.kind,value:gauge.value}))
      wait(180)
      osd("brightness",40,200,600)
      check(widget.osdShown===1 && !widget.osdTransitioning,"repeated OSD restarted the clock transition")
      wait(400)
      check(backend.osdActive && gauge.kind==="brightness" && Math.abs(gauge.value-0.2)<0.01,"latest OSD did not replace value or extend timeout")
      wait(420)
      tryVerify(function(){return !widget.osdTransitioning && !gauge.visible},300)
      check(!backend.osdActive && label.visible && !gauge.visible,"clock did not return after OSD expiry")
      osd("keyboard",50,100,1200)
      check(!bridge.opened && backend.osdActive && gauge.kind==="keyboard" && gauge.hasProgress,"keyboard brightness was not routed to Island")
      for(var item of [
        {icon:"microphone-muted",message:"Microphone off"},
        {icon:"microphone",message:"Microphone on"},
        {icon:"volume-high",message:"USB speakers"},
        {icon:"touchpad",message:"Touchpad disabled"},
        {icon:"touchscreen",message:"Touch enabled"},
        {icon:"logout",message:"Logging out…"},
        {icon:"reboot",message:"Restarting…"},
        {icon:"shutdown",message:"Powering off…"},
        {icon:"media-source",message:"<b>Plain text player</b>"}
      ]) {
        item.duration=600
        Commons.IpcRegistry.call("osd","show",[JSON.stringify(item)])
        check(!bridge.opened && backend.osdActive && !gauge.hasProgress && gauge.message===item.message,"message OSD was not rendered in Island: "+item.icon)
        check(findChild(gauge,"islandOsdMessage").textFormat===Text.PlainText,"OSD message interpreted markup")
        wait(25)
        checkEventLayout(gauge,clock)
      }
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"microphone-muted",message:"Microphone muted",duration:0})])
      wait(270)
      var eventMessage=findChild(gauge,"islandOsdMessage"),eventRow=findChild(gauge,"islandOsdEvent")
      tryVerify(function(){return eventMessage.text==="Microphone muted" && !gauge.eventTransitioning},400)
      checkEventLayout(gauge,clock)
      check(gauge.contentWidth<gauge.width && Math.abs(right.x-(clock.width/2+gauge.contentWidth/2+Commons.Style.space(6)))<1,"status indicators are detached from a short event message")
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"microphone",message:"Microphone on",duration:0})])
      wait(40)
      check(gauge.eventTransitioning && gauge.eventShown>0 && gauge.eventShown<1 && eventMessage.text==="Microphone muted","event text was replaced before dissolving")
      if(Quickshell.env("ISLAND_TEST_GPU")) check(eventRow.layer.effect!==null,"message change did not use the braille dissolve shader")
      tryVerify(function(){return eventMessage.text==="Microphone on" && !gauge.eventTransitioning},400)
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"microphone-muted",message:"Microphone muted",duration:0})])
      wait(25)
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"microphone",message:"Microphone on",duration:0})])
      tryVerify(function(){return eventMessage.text==="Microphone on" && !gauge.eventTransitioning},500)
      check(eventRow.layer.effect===null,"settled message kept its dissolve shader")
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"microphone",message:"Microphone on",duration:0})])
      wait(25)
      check(!gauge.eventTransitioning,"unchanged event restarted the text dissolve")
      console.log("EVENT_DISSOLVE_PASS")
      var longMessage="Very long audio device name ".repeat(20)
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"volume-high",message:longMessage,duration:0})])
      wait(240)
      tryVerify(function(){return eventMessage.text===longMessage && !gauge.eventTransitioning},400)
      checkEventLayout(gauge,clock)
      check(findChild(gauge,"islandOsdMessage").truncated,"long event text was not elided")
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"microphone",duration:0})])
      wait(240)
      tryVerify(function(){return eventMessage.text==="" && !gauge.eventTransitioning},400)
      checkEventLayout(gauge,clock)
      check(!findChild(gauge,"islandOsdMessage").visible,"icon-only event kept an empty message")
      console.log("CENTERED_OSD_EVENTS_PASS")
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"microphone-muted",message:"Microphone muted",duration:0})])
      wait(40)
      var textOpacity=gauge.eventShown
      bridge.close()
      check(gauge.eventShown===textOpacity,"closing OSD reset a message dissolve to full opacity")
      wait(240)
      tryVerify(function(){return !gauge.visible},300)
      for(var mode of ["dnd","nightLight","stayAwake"]) {
        backend.announceMode(mode,true)
        var onMessage=backend.osdMessage
        check(backend.osdActive && !backend.osdHasProgress && onMessage!=="","mode-on OSD is missing: "+mode)
        backend.announceMode(mode,false)
        check(backend.osdMessage!==onMessage && backend.osdMessage!=="","mode-off OSD is missing: "+mode)
      }
      console.log("MODE_OSD_PROMPTS_PASS")
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"keyboard",value:1,max:2,progressText:"On",duration:0})])
      wait(700)
      check(backend.osdActive && gauge.valueText==="On" && Math.abs(gauge.value-0.5)<0.01,"persistent/custom progress OSD was lost")
      bridge.close();wait(45)
      check(widget.osdTransitioning && label.visible && gauge.visible && gauge.valueText==="On","OSD-to-clock transition dropped its outgoing content")
      var leaving=widget.osdShown
      osd("volume",60,100,0)
      check(widget.osdShown===leaving,"new OSD snapped an interrupted transition")
      wait(270)
      check(widget.osdShown===1 && gauge.visible && !label.visible,"interrupted transition did not return to OSD")
      bridge.close();wait(240)
      tryVerify(function(){return !widget.osdTransitioning && !gauge.visible},300)
      check(!backend.osdActive && !gauge.visible,"osd close did not dismiss Island")
      Commons.Style.reduceMotion=true
      osd("volume",30,100,0)
      check(widget.osdShown===1 && !widget.osdTransitioning && !label.visible,"reduced motion animated the OSD entrance")
      Commons.IpcRegistry.call("osd","show",[JSON.stringify({icon:"microphone",message:"Microphone on",duration:0})])
      wait(25)
      check(eventMessage.text==="Microphone on" && gauge.eventShown===1 && !gauge.eventTransitioning,"reduced motion animated an event message")
      bridge.close()
      check(widget.osdShown===0 && !widget.osdTransitioning && !gauge.visible,"reduced motion animated the OSD exit")
      Commons.Style.reduceMotion=false
      check(!backend.showOsd('{"icon":"volume","value":"oops"}') && !backend.showOsd('{"icon":"volume","value":1,"max":0}'),"invalid OSD accepted")
      widget.updateSetting("osdVolume",false)
      osd("volume",20,100,1200)
      check(!backend.osdActive && !bridge.opened,"disabled OSD used Island or native fallback")
      widget.updateSetting("osdVolume",true)
      osd("volume",20,100,1200)
      check(backend.osdActive && !bridge.opened,"re-enabled OSD did not return to Island")
      widget.updateSetting("osdVolume",false)
      check(!backend.osdActive,"disabling an active OSD did not dismiss it")
      widget.updateSetting("indicatorDnd",false)
      service.doNotDisturb=true
      var dndIcon=findChild(widget,"islandDndIndicator")
      check((!dndIcon || !dndIcon.visible) && service.doNotDisturb,"indicator preference changed system DND state")
      widget.updateSetting("indicatorDnd",true)
      widget.updateSetting("osdVolume",true)
      backend.detach(widget)
      osd("volume",20,100,1200)
      check(bridge.opened,"OSD did not fall back when Island had no consumer")
      bridge.close()
      console.log("INDICATORS_PASS")
      if(Quickshell.env("ISLAND_INDICATOR_CAPTURE")) {
        backend.attach(widget);osd("volume",70,100,1200);wait(160)
        widget.grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_INDICATOR_CAPTURE"));Qt.quit()})
      } else Qt.quit()
    }
  }
  Timer {interval:300;running:true;onTriggered:{try {Quickshell.env("ISLAND_PANEL_LAYOUT") ? test.test_panelLayout() : test.test_indicators()} catch(e){console.log("INDICATORS_FAIL",e,e.stack);Qt.quit()}}}
}
