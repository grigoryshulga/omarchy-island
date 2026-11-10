import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "Island" as Island
import "Bridge" as Bridge

ShellRoot {
  id:scene
  property bool mockNightLight:false
  property bool mockStayAwake:false
  Commons.ShellIpc {target:"nightlight";function status():string{return JSON.stringify({enabled:scene.mockNightLight})}}
  Commons.ShellIpc {target:"idle";function status():string{return JSON.stringify({stayAwake:scene.mockStayAwake})}}
  Island.IndicatorState {id:backend;layouts.observeSystem:false}
  QtObject {
    id:states
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
    function attach(item){backend.attach(item)}
    function detach(item){backend.detach(item)}
  }
  QtObject {
    id:service
    property var indicators:states
    property bool doNotDisturb:false
    property var player:null
    property bool hasMedia:false
    property bool playing:false
    property string track:""
    property string targetScreen:""
    property var latest:null
    readonly property var activeEntries: allEntries
    property var historyEntries: []
    property var allEntries:[]
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
  QtObject {id:shell;function serviceFor(id){return service}}
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
    function registerClickTarget(t){}
    function unregisterClickTarget(t){}
    function showTooltip(t,s){}
    function hideTooltip(t){}
    function requestPopout(t){activePopout=t}
    function releasePopout(t){activePopout=null}
  }
  FloatingWindow {
    visible:true
    implicitWidth:620;implicitHeight:80
    Island.BarWidget {id:widget;anchors.centerIn:parent;width:implicitWidth;height:implicitHeight;bar:bar}
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
    function test_indicators(){
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
      if(Quickshell.env("ISLAND_TEST_GPU")) {
        var frozen=new Date(2026,10,10,19,47),saved=widget.now
        widget.now=frozen;wait(30)
        var beforeClock=grabImage(label)
        backend.stayAwake=true;wait(80);widget.now=frozen
        check(beforeClock.equals(grabImage(label)),"Awake indicator changed clock glyph rasterization")
        backend.stayAwake=false;widget.now=saved;wait(30)
        console.log("STABLE_CLOCK_PIXELS_PASS")
      }
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
  Timer {interval:300;running:true;onTriggered:test.test_indicators()}
}
