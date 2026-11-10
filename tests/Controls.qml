import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  id:scene
  property var calls:[]
  property var commands:[]
  property var preferences:[]
  QtObject {
    id:states
    property bool recording:false
    property bool remoteActive:false
    property bool microphoneMuted:false
    property var microphone:({})
    property bool nightLight:false
    property bool stayAwake:false
  }
  QtObject {
    id:service
    property var indicators:states
    property bool doNotDisturb:false
    function setDoNotDisturb(value){doNotDisturb=value}
  }
  QtObject {id:shell;function firstPartyServiceFor(id){return null}}
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
    function registerClickTarget(t){}
    function unregisterClickTarget(t){}
    function showTooltip(t,s){}
    function hideTooltip(t){}
    function moduleWidgets(id){return []}
    function run(command){scene.commands=scene.commands.concat([command])}
  }
  FloatingWindow {
    visible:true;implicitWidth:520;implicitHeight:620
    Island.ControlsView {
      id:view;anchors.fill:parent;anchors.margins:16
      service:service;bar:bar;strings:translations;active:true
      onSettingRequested:(key,value)=>{scene.preferences=[key,value]}
      execute:function(command){scene.commands=scene.commands.concat([command])}
      systemCall:function(target,method,args){scene.calls=scene.calls.concat([{target:target,method:method}]);return {ran:true}}
    }
  }
  Commons.Translations {id:translations;directory:Qt.resolvedUrl("Island/i18n")}
  TestCase {
    id:test
    when:false
    function check(ok,message){if(!ok){console.log("CONTROLS_FAIL:",message);Qt.quit();throw new Error(message)}}
    function test_controls(){
      wait(80)
      check(view.section==="" && view.implicitHeight>0,"controls landing is empty")
      var main=findChild(view,"controlMainGrid"),quick=findChild(view,"controlQuickGrid")
      check(main.y+main.height<quick.y && quick.columns===3,"main settings are not above the three-column quick controls")
      view.toggleMode("dnd");check(service.doNotDisturb,"DND did not toggle")
      wait(190)
      check(findChild(findChild(view,"controlDnd"),"controlIndicatorGlow").shown>0.99,"active control has no braille status light")
      view.toggleMode("microphone");check(scene.commands[0][0]==="omarchy-audio-input-mute","microphone missed native LED-aware action")
      view.toggleMode("nightLight");view.toggleMode("stayAwake")
      check(scene.calls[0].target==="nightlight" && scene.calls[1].target==="idle","native indicator actions were not used")
      view.toggleMode("recording");states.recording=true;view.toggleMode("recording")
      check(scene.commands[1][0]==="omarchy-menu" && scene.commands[2][1]==="--stop-recording","capture actions differ from stock")
      var loader=findChild(view,"islandNativeControl")
      var stableHeight=view.implicitHeight
      for(var section of ["audio","bluetooth","network","tailscale"]){
        view.openSection(section)
        check(view.implicitHeight===stableHeight,"opening a native section resized Controls: "+section)
        wait(500)
        check(view.implicitHeight===stableHeight,"loading native content resized Controls: "+section)
        check(loader.status===Loader.Ready && loader.item && loader.item.opened,"native section did not load: "+section)
        check(loader.item.inlineContentHeight>0,"native content is empty: "+section)
        var power=findChild(loader.item,"controlPowerSwitch")
        if(section==="bluetooth" && loader.item.adapter) check(power && power.visible && power.width>0 && power.height>0,"Bluetooth power switch is not visible")
        if(power) check(power.trackHeight<=Commons.Style.space(16),"native switch is not compact: "+section)
        check(!loader.item.manageIpc,"native panel owns global IPC: "+section)
        check(view.section===section,"native section lost its selection")
        if(section==="network") {
          var viewport=findChild(loader.item,"inlinePanelViewport")
          check(viewport.contentHeight>=viewport.height && viewport.clip,"Network is not contained in a scroll viewport")
          if(viewport.contentHeight>viewport.height) {viewport.contentY=viewport.contentHeight-viewport.height;check(viewport.contentY>0,"Network cannot scroll");viewport.contentY=0}
        }
        if(section==="tailscale") {
          loader.item.persistRecentMullvad("NL")
          check(scene.preferences[0]==="recentMullvadRegions" && scene.preferences[1][0]==="NL","native preferences did not route to Island")
        }
        findChild(loader.item,"controlBack").clicked();wait(30)
        check(view.section==="" && !loader.active,"back did not return to Controls or stop native backend")
      }
      var commandCount=scene.commands.length
      view.launchExternalPanel("unknown.plugin","{}")
      check(scene.commands.length===commandCount,"unrecognized external panel was launched")
      view.launchExternalPanel("omarchy.wifiqr","{}")
      check(scene.commands[commandCount][0]==="omarchy-shell" && scene.commands[commandCount][3]==="omarchy.wifiqr","native Wi-Fi share card did not use the shell route")
      view.openSection("audio");wait(150);view.active=false;wait(30)
      check(!loader.active,"closing Controls left native polling/scanning active")
      view.active=true;wait(150)
      check(loader.item && loader.item.opened,"native detail did not resume on reopen")
      view.back();wait(30)
      console.log("CONTROLS_PASS");Qt.quit()
    }
  }
  Timer {interval:200;running:true;onTriggered:test.test_controls()}
}
