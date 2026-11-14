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
    property var layoutState:actions.layoutState
    property bool on:true
    property bool known:true
    property var toggled:[]
    property var panelCommand:actions.panelCommand
    function watch(item,visible){}
    function execute(argv){scene.commands=scene.commands.concat([argv])}
    function systemCall(target,method,args){return {ran:true}}
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
    property var modules:({controls:tileState})
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
    Island.PopupPages {
      id:overviewPages;anchors.fill:parent;visible:false
      expanded:true;service:service;strings:translations;bar:bar
      onPageRequested:index=>selectedPage=index
    }
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
      tryVerify(function(){return actions.layoutState.ready},3000)
      if(Quickshell.env("ISLAND_TEST_RESTORE")==="1") {
        check(view.controlLayout.hidden.indexOf("microphone")>=0 && view.controlLayout.main[0]==="network","Controls layout did not survive restart")
        check(!findChild(view,"controlMicrophone") && findChild(view,"controlOpen-settings"),"restored composition differs")
        check(view.controlLayout.sizes.network.width===3 && view.controlLayout.sizes.network.height===2,"tile dimensions did not survive restart")
        check(view.controlLayout.labels.network.title==="Connections" && view.controlLayout.labels.network.icon==="◎","tile metadata did not survive restart")
        var savedSection=view.controlLayout.order.filter(function(k){return k.indexOf("section:")===0})[0]
        check(savedSection && view.controlLayout.sections[savedSection].title==="Devices" && view.controlLayout.sections[savedSection].gap===1,"sections did not survive restart")
        console.log("CONTROLS_PASS");Qt.quit();return
      }
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
      var main=findChild(view,"controlMainGrid")
      check(main && main.height>0,"four-column controls grid is empty")
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
        if(category==="panel") check(!findChild(settingsView,"setting-overviewEnabled").enabled,"Overview can be disabled, losing Settings access")
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
      // Editing preserves the actual layout, without inserting a form or row toolbars.
      var beforeEditWidth=findChild(view,"controlOpen-audio").width
      var beforeEditHeight=view.implicitHeight
      view.configure();wait(60)
      check(findChild(view,"controlOpen-audio").width===beforeEditWidth && view.implicitHeight===beforeEditHeight,"editing changed the layout geometry")
      check(view.editing && view.section==="" && !loader.active,"editing left the controls grid")
      check(findChild(view,"controlOpen-audio"),"editing hides actual tiles")
      check(!findChild(view,"controlHide").enabled || view.controlLayout.hidden.indexOf("settings")<0,"Settings was hidden")
      var audio=findChild(view,"controlOpen-audio")
      audio.forceActiveFocus();wait(10)
      keyClick(Qt.Key_Left,Qt.ShiftModifier);wait(30)
      audio=findChild(view,"controlOpen-audio")
      check(audio.iconOnly && view.controlLayout.sizes.audio.width===1,"quarter tile does not use icon-only layout")
      check(audio.activeFocus,"resizing lost tile focus")
      keyClick(Qt.Key_Down,Qt.ShiftModifier);wait(30)
      check(view.controlLayout.sizes.audio.height===2,"keyboard height resize failed")
      var resize=findChild(view,"controlResize-audio")
      mousePress(resize,resize.width/2,resize.height/2)
      mouseMove(resize,resize.width/2+130,resize.height/2+55,30)
      check(view.controlLayout.sizes.audio.width===1,"resize persisted before pointer release")
      mouseRelease(resize,resize.width/2+130,resize.height/2+55);wait(30)
      check(view.controlLayout.sizes.audio.width===2 && view.controlLayout.sizes.audio.height===3,"pointer resize did not snap to grid")
      var fontSize=findChild(view,"controlOpen-audio").fontSize
      actions.layoutState.resize("audio",3,1);wait(20)
      check(!findChild(view,"controlOpen-audio").iconOnly && findChild(view,"controlOpen-audio").fontSize===fontSize,"three-quarter tile changed typography")
      actions.layoutState.resize("audio",4,1);wait(20)
      check(findChild(view,"controlOpen-audio").width===main.width,"full-row tile does not fill the grid")
      actions.layoutState.reset();wait(30)
      var grip=findChild(view,"controlDrag-audio"),target=findChild(view,"controlDrag-network")
      var point=target.mapToItem(grip,target.width/2,target.height/2)
      mousePress(grip,grip.width/2,grip.height/2)
      mouseMove(grip,point.x,point.y,80)
      mouseRelease(grip,point.x,point.y);wait(40)
      check(view.controlLayout.order[2]==="audio","drag did not reorder panels")
      actions.layoutState.reset();wait(30)
      // The icon remains part of the drag surface; dragging must not open its editor.
      grip=findChild(view,"controlDrag-audio");target=findChild(view,"controlDrag-network")
      point=target.mapToItem(grip,target.width/2,target.height/2)
      mousePress(grip,16,grip.height/2)
      mouseMove(grip,point.x,point.y,80)
      mouseRelease(grip,point.x,point.y);wait(30)
      check(view.controlLayout.order[2]==="audio" && !findChild(view,"controlEdit-audio").visible,"dragging by icon opened the editor")
      actions.layoutState.reset();wait(30)
      // Edit names in place; Escape cancels without leaving the grid.
      var audioGrip=findChild(view,"controlDrag-audio")
      mouseDoubleClickSequence(audioGrip,audioGrip.width/2,audioGrip.height/2);wait(30)
      var nameField=findChild(view,"controlEdit-audio")
      check(nameField.visible && nameField.activeFocus,"inline name editor did not open")
      nameField.text="Discard";keyClick(Qt.Key_Escape);wait(20)
      check(view.editing && !nameField.visible && !view.controlLayout.labels.audio,"Escape did not cancel inline rename")
      findChild(view,"controlOpen-audio").forceActiveFocus();keyClick(Qt.Key_F2);wait(20)
      nameField.text="Speakers";keyClick(Qt.Key_Return);wait(20)
      check(findChild(view,"controlOpen-audio").title==="Speakers","inline name was not applied")
      audioGrip=findChild(view,"controlDrag-audio")
      mouseClick(audioGrip,16,audioGrip.height/2);wait(20)
      var iconField=findChild(view,"controlEdit-audio")
      check(iconField.visible && iconField.maximumLength===16,"icon click did not open inline editor")
      iconField.text="♪";keyClick(Qt.Key_Return);wait(20)
      check(findChild(view,"controlOpen-audio").glyph==="♪","custom tile icon was not applied")
      view.showAdd();wait(30)
      findChild(view.addMenuContent,"controlAddSection").clicked();wait(30)
      check(!view.adding,"adding a section left the add menu open")
      var sectionKey=view.controlLayout.order[0]
      check(sectionKey.indexOf("section:")===0,"section was not inserted before row")
      nameField=findChild(view,"controlEdit-"+sectionKey)
      check(nameField.visible && nameField.activeFocus,"new section did not begin inline rename")
      nameField.text="Devices";keyClick(Qt.Key_Return);wait(20)
      findChild(view,"controlMore-"+sectionKey).clicked();wait(20)
      findChild(view,"controlGapMore").clicked();findChild(view,"controlGapMore").clicked();wait(20)
      check(view.controlLayout.sections[sectionKey].title==="Devices" && view.controlLayout.sections[sectionKey].gap===2,"section title or spacing was not applied")
      findChild(view,"controlHide").clicked();wait(20)
      check(view.controlLayout.order.indexOf(sectionKey)<0 && findChild(view,"controlOpen-audio"),"deleting a heading deleted its tiles")
      actions.layoutState.reset();wait(30)
      tryVerify(function(){return view.externalControls.length===1},3000)
      check(view.externalControls[0].key==="plugin:fixture.control","catalog included incompatible plugins")
      view.showAdd();wait(30)
      check(findChild(view,"controlOpen-audio").visible,"add dropdown replaced the controls grid")
      keyClick(Qt.Key_Escape);wait(30)
      check(!view.adding && view.editing,"Escape did not close only the add dropdown")
      view.showAdd();wait(30)
      var search=findChild(view,"controlPluginSearch")
      search.text="no match";wait(20)
      check(!findChild(view.addMenuContent,"controlAdd-plugin:fixture.control"),"plugin search did not filter")
      search.text="Fixture";wait(20)
      findChild(view.addMenuContent,"controlAdd-plugin:fixture.control").clicked();wait(30)
      view.back();wait(30)
      check(!view.editing && findChild(view,"controlOpen-plugin:fixture.control"),"external plugin tile missing after inline editing")
      view.openSection("plugin:fixture.control")
      tryVerify(function(){return loader.item && loader.item.opened},4000)
      check(loader.item && loader.item.moduleName==="fixture.control" && !loader.item.manageIpc,"external panel contract differs")
      check(loader.item.bar.pluginId==="fixture.control" && loader.item.settings.exampleValue===7 && loader.item.settings.recentMullvadRegions===undefined,"external panel received another module identity or settings")
      view.back();wait(30)
      check(!loader.item,"external panel remained alive after leaving")
      actions.layoutState.reset();wait(30)
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
      view.active=false;view.visible=false;overviewPages.visible=true;wait(60)
      check(!findChild(overviewPages,"islandTabControls"),"Controls still has a separate tab")
      check(overviewPages.enabledPages.indexOf(0)<0,"Controls remains in page navigation")
      var favorites=findChild(overviewPages,"controlFavorites")
      check(favorites && favorites.visible && findChild(overviewPages,"controlFavorite-audio"),"Overview favorites strip is missing")
      var savedLayout=actions.layoutState.layout,savedPreferences=Island.Preferences.values
      var favoriteKeys=["audio","bluetooth","network","tailscale","monitors","settings","microphone","dnd","nightLight","stayAwake","recording","remote"]
      actions.layoutState.commit(Object.assign({},savedLayout,{favorites:favoriteKeys}))
      overviewPages.anchors.fill=null;overviewPages.height=620
      for(var panelWidth of [328,520]) for(var mode of ["minimal","standard","large"]) {
        overviewPages.width=panelWidth
        Island.Preferences.values=Object.assign({},savedPreferences,{overviewLayout:[{id:"controls",visible:true,size:mode}]});wait(30)
        var columns=mode==="minimal" ? 3 : 5,count=mode==="large" ? 10 : columns
        var grid=findChild(overviewPages,"controlFavoritesGrid"),all=findChild(overviewPages,"controlAll")
        check(all.iconText!=="" && all.text==="","All controls must be an inline arrow tile")
        check(all.y===grid.y && all.x>=grid.x+grid.width,"Arrow tile is not beside favorites")
        for(var i=0;i<favoriteKeys.length;i++) {
          var favorite=findChild(overviewPages,"controlFavorite-"+favoriteKeys[i])
          check(i<count ? !!favorite : !favorite,"Incorrect favorite count for "+mode)
          if(favorite) {
            check(favorite.x>=0 && favorite.x+favorite.width<=grid.width+1,"Favorite overflows a narrow panel")
            check(Math.abs(favorite.y-Math.floor(i/columns)*(favorite.height+grid.rowSpacing))<1,"Favorites do not use the requested rows")
          }
        }
        check(actions.layoutState.layout.favorites.length===favoriteKeys.length,"Changing size discarded saved favorites")
        if(panelWidth===520 && Quickshell.env("ISLAND_CONTROLS_CAPTURE"))
          grabImage(controlsWindow.contentItem).save(Quickshell.env("ISLAND_CONTROLS_CAPTURE")+"-"+mode+".png")
      }
      actions.layoutState.commit(Object.assign({},savedLayout,{favorites:[]}));wait(30)
      check(findChild(overviewPages,"controlAll").visible,"Empty favorites hid access to all controls")
      actions.layoutState.commit(savedLayout);Island.Preferences.values=savedPreferences
      overviewPages.anchors.fill=controlsWindow.contentItem;wait(30)
      var previousDnd=service.doNotDisturb
      findChild(overviewPages,"controlFavorite-dnd").clicked()
      check(service.doNotDisturb!==previousDnd,"favorite quick control did not execute")
      actions.layoutState.favorite("audio");wait(20)
      check(!findChild(overviewPages,"controlFavorite-audio"),"favorite removal did not update Overview")
      actions.layoutState.favorite("audio");wait(20)
      findChild(overviewPages,"controlFavorite-audio").clicked();wait(50)
      var overviewControl=findChild(overviewPages,"islandNativeControl")
      tryVerify(function(){return overviewControl.item && overviewControl.item.opened},4000)
      check(overviewPages.controls && overviewPages.selectedPage===1,"favorite panel did not open within Overview")
      check(!findChild(overviewPages,"overviewBack").visible && findChild(overviewPages,"controlBack").visible,"native detail still has duplicate outer navigation")
      check(overviewPages.back(),"native detail did not handle Back")
      check(overviewPages.controls,"Back skipped the full controls page")
      check(overviewPages.back(),"Controls did not return to summary")
      check(!overviewPages.controls && favorites.visible,"Controls did not restore Overview summary")
      findChild(overviewPages,"controlAll").forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
      check(overviewPages.controls && findChild(overviewPages,"controlOpen-settings").visible,"All controls did not open full controls")
      findChild(overviewPages,"controlCustomize").clicked();wait(30)
      check(findChild(overviewPages,"controlAddMenu").visible,"editing has no add button beside the gear")
      check(overviewPages.back() && overviewPages.controls,"Back did not exit inline editing before leaving Controls")
      findChild(overviewPages,"controlOpen-settings").clicked();wait(30)
      check(!findChild(overviewPages,"islandTabs"),"embedded settings did not hide main navigation")
      overviewPages.back();overviewPages.back();wait(20)
      actions.layoutState.move("main","network","audio")
      actions.layoutState.toggle("microphone")
      actions.layoutState.resize("network",3,2)
      actions.layoutState.label("network","Connections","◎")
      actions.layoutState.addSection("network","Devices")
      actions.layoutState.section(view.controlLayout.order[0],"Devices",1)
      wait(50)
      console.log("CONTROLS_PASS");Qt.quit()
    }
  }
  Timer {interval:200;running:true;onTriggered:test.test_controls()}
}
