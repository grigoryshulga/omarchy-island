import QtQuick
import QtTest
import Quickshell
import Quickshell.Networking
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
    id:tileState
    property bool on:true
    property bool known:true
    property var toggled:[]
    function available(key){return known && ["audio","bluetooth","network","tailscale"].indexOf(key)>=0}
    function enabledState(key){return on}
    function toggle(key){if(available(key)) {toggled=toggled.concat([key]);on=!on}}
  }
  QtObject {id:fakeAdapter;property bool enabled:true}
  QtObject {id:fakeAudio;property bool muted:false}
  QtObject {id:fakeOutput;property var audio:fakeAudio}
  QtObject {id:fakeNetwork;property var backend:NetworkBackendType.NetworkManager;property bool wifiEnabled:true}
  Island.ControlsState {
    id:actions
    adapter:fakeAdapter;output:fakeOutput;networking:fakeNetwork
    execute:function(command){scene.commands=scene.commands.concat([command])}
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
    id:controlsWindow
    visible:true;implicitWidth:520;implicitHeight:620
    // Offscreen windows need not apply implicit-size requests after creation.
    // Exercise responsive content directly within a stable window surface.
    property int testWidth:520
    Island.ControlsView {
      id:view;anchors.left:parent.left;anchors.top:parent.top;anchors.bottom:parent.bottom;anchors.margins:16
      width:controlsWindow.testWidth-32
      controlState:tileState
      panelCommand:actions.panelCommand
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
      Commons.Style.fontFamily="monospace"
      Commons.Style.fontOverrides=({})
      Commons.Style.fontBaseSize=12
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
      check(actions.enabledState("audio") && actions.enabledState("network") && actions.enabledState("bluetooth"),"native enabled state differs")
      actions.toggle("audio");check(fakeAudio.muted && !actions.enabledState("audio"),"audio mute did not follow real state")
      actions.toggle("audio");check(!fakeAudio.muted,"audio unmute failed")
      actions.toggle("network");check(!fakeNetwork.wifiEnabled && !actions.enabledState("network"),"Wi-Fi did not turn off")
      actions.toggle("network");check(fakeNetwork.wifiEnabled,"Wi-Fi did not turn on")
      actions.toggle("bluetooth");fakeAdapter.enabled=false;actions.toggle("bluetooth")
      check(scene.commands[0].join(" ")==="omarchy-bluetooth-power off" && scene.commands[1].join(" ")==="omarchy-bluetooth-power on","Bluetooth bypassed persistent native power helper")
      actions.adapter=null;actions.output=null
      check(!actions.available("audio") && !actions.available("bluetooth") && !actions.available("tailscale"),"unavailable device can toggle")
      actions.toggle("audio");actions.toggle("bluetooth");actions.toggle("tailscale");actions.toggle("settings")
      check(scene.commands.length===2,"unavailable function launched a command")
      actions.tailscaleKnown=true;actions.tailscaleEnabled=true
      check(actions.available("tailscale") && actions.enabledState("tailscale"),"authorized Tailscale state missing")
      actions.tailscaleKnown=false
      actions.active=true
      tryVerify(function(){return actions.tailscaleKnown && actions.outputName==="test-output"},3000)
      check(actions.tailscaleEnabled,"Tailscale JSON status was not read")
      actions.toggle("tailscale")
      tryVerify(function(){return !actions.tailscaleEnabled},3000)
      actions.toggle("tailscale")
      tryVerify(function(){return actions.tailscaleEnabled},3000)
      actions.active=false
      scene.commands=[]
      var main=findChild(view,"controlMainGrid"),quick=findChild(view,"controlQuickGrid")
      check(main.y+main.height<quick.y && quick.columns===3,"main settings are not above the three-column quick controls")
      for(var key of ["audio","bluetooth","network","tailscale"]) {
        var tile=findChild(view,"controlOpen-"+key)
        check(tile.height<=Commons.Style.space(52),"main tile is not compact")
        check(tile.showLed && tile.selected,"enabled function has no indicator: "+key)
        mouseClick(tile,tile.width/2,tile.height/2,Qt.RightButton);wait(10)
        check(view.section==="" && !tile.selected && tileState.toggled.slice(-1)[0]===key,"right click did not toggle without opening: "+key)
        tileState.on=true;wait(10)
        check(tile.selected,"indicator did not follow external state: "+key)
      }
      for(var key of ["monitors","settings"]) {
        var tile=findChild(view,"controlOpen-"+key),count=tileState.toggled.length
        check(!tile.showLed,"non-toggle tile has an indicator")
        mouseClick(tile,tile.width/2,tile.height/2,Qt.RightButton)
        check(tileState.toggled.length===count && view.section==="","non-toggle right click changed state")
      }
      tileState.known=false;wait(10)
      check(!findChild(view,"controlOpen-bluetooth").showLed,"unavailable state shown as enabled")
      tileState.known=true
      var audioTile=findChild(view,"controlOpen-audio")
      mouseClick(audioTile,audioTile.width/2,audioTile.height/2,Qt.LeftButton)
      check(view.section==="audio","left click no longer opens panel")
      view.back();wait(50)
      var dnd=findChild(view,"controlDnd")
      mouseClick(dnd,dnd.width/2,dnd.height/2,Qt.RightButton)
      check(service.doNotDisturb,"quick control right click did not toggle")
      mouseClick(dnd,dnd.width/2,dnd.height/2,Qt.RightButton)
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
      for(var windowWidth of [520,360]) {
        controlsWindow.testWidth=windowWidth;wait(40)
        check(settingsView.width===windowWidth-32,"settings viewport did not reach requested width: "+windowWidth)
        for(var tabName of ["general","panel","alerts","modules"]) {
          var tab=findChild(settingsView,"settingsTab-"+tabName),label=findChild(tab,"tabLabel")
          check(label.text.length>0 && label.width>=label.implicitWidth,"settings tab label is clipped: "+tabName+" ("+label.width+" < "+label.implicitWidth+")")
          tab.forceActiveFocus();wait(20)
          var at=tab.mapToItem(settingsView,0,0)
          check(at.x>=-1 && at.x+tab.width<=settingsView.width+1 && at.y+tab.height<=findChild(settingsView,"settingsViewport").y,"focused settings tab was not revealed: "+tabName)
          check(at.y===0,"settings categories wrapped into another row")
        }
      }
      controlsWindow.testWidth=520;wait(40)
      var hover=findChild(settingsView,"setting-hoverPreview")
      hover.toggled()
      check(scene.preferences[0]==="hoverPreview" && scene.preferences[1]===false,"toggle did not persist")
      for(var category of ["panel","modules","alerts","general"]) {
        findChild(settingsView,"settingsTab-"+category).clicked();wait(20)
        check(view.implicitHeight===stableHeight,"settings category resized Controls")
        if(category==="panel") check(!findChild(settingsView,"setting-controlsEnabled").enabled,"Controls can be disabled, losing Settings access")
        if(category==="modules") check(!findChild(settingsView,"setting-musicVisualizationStyle"),"placeholder style remains visible")
        if(category==="alerts") {
          var style=findChild(settingsView,"setting-notificationStyle")
          style.changed("bar")
          check(scene.preferences[0]==="notificationStyle" && scene.preferences[1]==="bar","notification style did not persist")
        }
      }
      var viewport=findChild(settingsView,"settingsViewport")
      var delay=findChild(settingsView,"setting-hoverDelay"),delayHeight=delay.parent.parent.implicitHeight
      view.settings={hoverPreview:false};wait(20)
      check(!delay.enabled && delay.parent.parent.implicitHeight===delayHeight,"dependent delay moved or stayed interactive")
      view.settings={};wait(20)
      check(delay.enabled,"delay did not follow its parent switch")
      var opening=findChild(settingsView,"setting-openingPage"),openingLabel=findChild(settingsView,"settingLabel-openingPage")
      check(opening.mapToItem(settingsView,0,0).y<openingLabel.mapToItem(settingsView,0,0).y+openingLabel.height,"wide choice did not stay inline")
      controlsWindow.testWidth=360
      var fontSize=Commons.Style.fontBaseSize
      Commons.Style.fontOverrides=({});Commons.Style.fontBaseSize=fontSize*1.5;wait(40)
      check(view.width===328,"narrow fixture did not resize the tested content")
      console.log("CONTROLS_LAYOUT",Commons.I18n.language,openingLabel.font.family,openingLabel.font.pixelSize,view.width)
      check(opening.width<=settingsView.width && opening.mapToItem(settingsView,0,0).y>=openingLabel.mapToItem(settingsView,0,0).y+openingLabel.height,"narrow choice did not move below label")
      for(var tabName of ["general","panel","alerts","modules"]) {
        var tab=findChild(settingsView,"settingsTab-"+tabName)
        tab.forceActiveFocus();wait(20)
        var at=tab.mapToItem(settingsView,0,0)
        check(at.x>=-1 && at.x+tab.width<=settingsView.width+1,"large text tab cannot be reached")
      }
      Commons.Style.fontBaseSize=fontSize;controlsWindow.testWidth=520;wait(40)
      findChild(settingsView,"settingsTab-panel").clicked();wait(20)
      check(viewport.contentHeight>viewport.height,"long settings category is not scrollable")
      viewport.contentY=viewport.contentHeight-viewport.height
      findChild(settingsView,"settingsTab-modules").clicked();wait(20)
      check(viewport.contentY===0,"category switch retained previous scroll position")
      var warning=findChild(settingsView,"setting-agentLimitsWarning"),critical=findChild(settingsView,"setting-agentLimitsCritical")
      check(warning && critical && warning.maximum===100 && warning.step===5 && critical.value===5,"agent limit thresholds were lost during regrouping")
      warning.moved(35)
      check(scene.preferences[0]==="agentLimitsWarning" && scene.preferences[1]===35,"agent limit threshold did not persist")
      var answer=findChild(settingsView,"setting-t3Responses"),answerHeight=answer.parent.parent.implicitHeight
      check(!answer.enabled,"T3 responses are interactive while integration is off")
      view.settings={t3Enabled:true};wait(20)
      check(answer.enabled && answer.parent.parent.implicitHeight===answerHeight,"T3 responses did not follow parent or moved form")
      view.settings={}
      view.back();wait(30)
      for(var section of ["audio","bluetooth","network","tailscale","monitors"]){
        view.openSection(section)
        check(view.implicitHeight===stableHeight,"opening a native section resized Controls: "+section)
        tryVerify(function(){return loader.item && loader.item.opened},4000)
        check(view.implicitHeight===stableHeight,"loading native content resized Controls: "+section)
        check(loader.status===Loader.Ready && loader.item && loader.item.opened,"native section did not load: "+section)
        tryVerify(function(){return loader.item.inlineContentHeight>0},2000)
        var power=findChild(loader.item,"controlPowerSwitch")
        if(power) check(power.trackHeight===Commons.Style.space(20),"native switch does not follow Island sizing: "+section)
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
