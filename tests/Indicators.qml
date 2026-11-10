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
  Island.IndicatorState {id:backend}
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
  Commons.ShellIpc {target:"island-osd";function show(payload:string):string{return backend.showOsd(payload) ? "ok" : "unavailable"}}
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
    function test_indicators(){
      wait(100)
      var clock=findChild(widget,"islandClock"),label=findChild(widget,"islandClockText"),gauge=findChild(widget,"islandOsdGauge")
      check(!findChild(widget,"islandRecordingIndicator").visible && !findChild(widget,"islandMicrophoneIndicator").visible,"inactive indicators are visible")
      states.recording=true;states.remoteActive=true;states.microphoneMuted=true;scene.mockNightLight=true;scene.mockStayAwake=true;backend.refreshControls();service.doNotDisturb=true
      check(backend.nightLight && backend.stayAwake,"native idle/nightlight IPC state was not read")
      wait(240)
      var recording=findChild(widget,"islandRecordingIndicator"),remote=findChild(widget,"islandRemoteIndicator"),left=findChild(widget,"islandLeftIndicators"),right=findChild(widget,"islandRightIndicators")
      check(recording.visible && remote.visible && recording.tint.r>recording.tint.g && remote.tint.g>remote.tint.r,"capture indicator colors or states are wrong")
      var at=label.mapToItem(clock,0,0)
      check(Math.abs(at.x+label.width/2-clock.width/2)<1,"indicators moved the clock off center")
      check(left.x+left.width<=at.x && right.x>=at.x+label.width && right.x+right.width<=clock.width,"indicator sides overlap the clock or overflow")
      for(var name of ["islandMicrophoneIndicator","islandDndIndicator","islandNightLightIndicator","islandStayAwakeIndicator"]) check(findChild(widget,name).visible,"active indicator missing: "+name)
      check(osd("volume-muted",75,100,700).output==="ok" && backend.osdActive && !bridge.opened,"native volume OSD was not routed to Island")
      wait(120)
      check(gauge.muted && gauge.visible && !label.visible && gauge.kind==="volume" && Math.abs(gauge.value-0.75)<0.01,"volume gauge did not replace clock")
      wait(180)
      osd("brightness",40,200,600)
      wait(400)
      check(backend.osdActive && gauge.kind==="brightness" && Math.abs(gauge.value-0.2)<0.01,"latest OSD did not replace value or extend timeout")
      wait(260)
      check(!backend.osdActive && label.visible && !gauge.visible,"clock did not return after OSD expiry")
      osd("keyboard",50,100,1200)
      check(bridge.opened && !backend.osdActive,"unrelated stock OSD was swallowed")
      bridge.close()
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
