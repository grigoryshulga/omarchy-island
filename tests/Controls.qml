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
      var loader=findChild(view,"islandNativeControl")
      if(Quickshell.env("ISLAND_TEST_MISSING_SYSTEM")==="1") {
        view.openSection("audio")
        tryVerify(function(){return view.error!==""},4000)
        check(!loader.item,"missing system loaded a stale panel")
        view.back()
        check(view.section==="" && view.error==="","failed panel cannot return to Controls")
        console.log("CONTROLS_PASS");Qt.quit();return
      }
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
      var stableHeight=view.implicitHeight
      check(findChild(view,"controlOpen-settings"),"sixth Settings tile is missing")
      view.openSection("settings");wait(40)
      var settingsView=findChild(view,"islandSettings")
      check(view.implicitHeight===stableHeight && !loader.active && settingsView.visible,"Settings did not inherit Controls size or started native backend")
      var hover=findChild(settingsView,"setting-hoverPreview")
      hover.toggled()
      check(scene.preferences[0]==="hoverPreview" && scene.preferences[1]===false,"toggle did not persist")
      for(var category of ["sections","music","indicators","events","behavior"]) {
        findChild(settingsView,"settingsTab-"+category).clicked();wait(20)
        check(view.implicitHeight===stableHeight,"settings category resized Controls")
        if(category==="sections") check(!findChild(settingsView,"setting-controlsEnabled").enabled,"Controls can be disabled, losing Settings access")
        if(category==="music") check(!findChild(settingsView,"setting-musicVisualizationStyle").enabled,"placeholder style is interactive")
        if(category==="events") {
          var style=findChild(settingsView,"setting-notificationStyle")
          style.changed("bar")
          check(scene.preferences[0]==="notificationStyle" && scene.preferences[1]==="bar","notification style did not persist")
        }
      }
      view.back();wait(30)
      for(var section of ["audio","bluetooth","network","tailscale","monitors"]){
        view.openSection(section)
        check(view.implicitHeight===stableHeight,"opening a native section resized Controls: "+section)
        tryVerify(function(){return loader.item && loader.item.opened},4000)
        check(view.implicitHeight===stableHeight,"loading native content resized Controls: "+section)
        check(loader.status===Loader.Ready && loader.item && loader.item.opened,"native section did not load: "+section)
        tryVerify(function(){return loader.item.inlineContentHeight>0},2000)
        var power=findChild(loader.item,"controlPowerSwitch")
        if(power) check(power.trackHeight<=Commons.Style.space(16),"native switch is not compact: "+section)
        check(!loader.item.manageIpc,"native panel owns global IPC: "+section)
        check(view.section===section,"native section lost its selection")
        if(section!=="network") {
          var ownViewport=findChild(loader.item,"inlinePanelViewport")
          check(ownViewport.contentHeight===ownViewport.height,"host displaced native scrolling: "+section)
        }
        if(section==="network") {
          var viewport=findChild(loader.item,"inlinePanelViewport")
          check(viewport.contentHeight>=viewport.height && viewport.clip,"Network is not contained in a scroll viewport")
          if(viewport.contentHeight>viewport.height) {viewport.contentY=viewport.contentHeight-viewport.height;check(viewport.contentY>0,"Network cannot scroll");viewport.contentY=0}
        }
        if(section==="tailscale") {
          loader.item.persistRecentMullvad("NL")
          check(scene.preferences[0]==="recentMullvadRegions" && scene.preferences[1][0]==="NL","native preferences did not route to Island")
          view.settings={recentMullvadRegions:["NL"]}
          loader.item.persistRecentMullvad("DE")
          check(scene.preferences[1].join(",")==="DE,NL","native settings stopped following Island updates")
        }
        findChild(view,"controlBack").clicked();wait(30)
        check(view.section==="" && !loader.active,"back did not return to Controls or stop native backend")
      }
      // A helper finishing after navigation must not load its old section.
      view.openSection("audio");view.openSection("bluetooth");view.openSection("network")
      tryVerify(function(){return loader.item && loader.item.moduleName==="omarchy.network"},4000)
      loader.item.close()
      tryVerify(function(){return view.section==="" && !loader.item},1000)
      view.openSection("tailscale");view.back();wait(150)
      check(!loader.item && view.section==="","late helper reopened a closed panel")
      var commandCount=scene.commands.length
      view.launchExternalPanel("unknown.plugin","{}")
      check(scene.commands.length===commandCount,"unrecognized external panel was launched")
      view.launchExternalPanel("omarchy.wifiqr","{}")
      check(scene.commands[commandCount][0]==="omarchy-shell" && scene.commands[commandCount][3]==="omarchy.wifiqr","native Wi-Fi share card did not use the shell route")
      view.openSection("audio");tryVerify(function(){return loader.item && loader.item.opened},4000);view.active=false;wait(30)
      check(!loader.active,"closing Controls left native polling/scanning active")
      view.active=true;tryVerify(function(){return loader.item && loader.item.opened},4000)
      check(loader.item && loader.item.opened,"native detail did not resume on reopen")
      view.back();wait(30)
      console.log("CONTROLS_PASS");Qt.quit()
    }
  }
  Timer {interval:200;running:true;onTriggered:test.test_controls()}
}
