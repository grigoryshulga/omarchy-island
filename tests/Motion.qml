import QtQuick
import QtQuick.Layouts
import QtTest
import Quickshell
import Quickshell.Services.Mpris
import "Island/Model.js" as Model
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  QtObject {
    id: p
    property string identity: "Test Music"
    property string trackTitle: "A test track"
    property string trackArtist: "Test artist"
    property string trackArtUrl: ""
    property int playbackState: MprisPlaybackState.Paused
    property bool isPlaying: false
    property bool canGoNext: true
    property bool canGoPrevious: true
    property bool canTogglePlaying: true
    property bool canSeek: true
    property bool positionSupported: true
    property bool lengthSupported: true
    property bool volumeSupported: true
    property real length: 180
    property real position: 20
    property real volume: 0.5
  }
  QtObject {
    id: service
    property bool playing: false
    property string track: ""
    property string targetScreen: ""
    property real visualPhase: 0
    property real audioLevel: 0
    property real audioBass: 0
    property real audioTreble: 0
    signal arrivalChanged()
    signal t3Arrival()
    property var latestT3: null
    property string t3TargetScreen: ""
    property var t3: QtObject {
      property bool allowed:false
      property bool connected:true
      property bool canRespond:true
      property bool responsesEnabled:true
      property var rows:[]
      property int waitingCount:0
      property int workingCount:0
      function response(id) {return ""}
      function openThread(id) {}
    }
    readonly property var activeEntries: allEntries
    property var historyEntries: []
    property var allEntries: [{key:"n1",app:"Test",summary:"One",body:"one",ts:1},{key:"n2",app:"Test",summary:"Two",body:"two",ts:2},{key:"n3",app:"Test",summary:"Three",body:"three",ts:3},{key:"n4",app:"Test",summary:"Four",body:"four",ts:4}]
    property string error: ""
    property bool doNotDisturb: false
    property var latest: null
    property var player: p
    readonly property bool hasMedia: Model.hasMedia(player,MprisPlaybackState.Stopped)
    property var players: []
    property var mutedSources: []
    property int mediaCalls: 0
    property int activateCalls: 0
    property string copied: ""
    property string muted: ""
    function setDoNotDisturb(value) {doNotDisturb=value}
    function media(action) { mediaCalls++; p.isPlaying = !p.isPlaying }
    function actions(row) { return [] }
    function activate(row) { activateCalls++ }
    function copyCode(row,code) { copied = code }
    function mute(s) { muted = s }
  }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("Island/i18n") }
  QtObject {
    id: fakeShell
    function serviceFor(id) { return service }
    property var writtenEntry: null
    function updateEntryInline(id,entry) {writtenEntry=entry;return true}
  }
  QtObject {
    id: fakeBar
    property var shell: fakeShell
    property string position: "top"
    property bool vertical: false
    property int barSize: 26
    property color foreground: "#ffffff"
    property color barForeground: "#ffffff"
    property color background: "#101315"
    property color urgent: "#ff0000"
    property string fontFamily: "monospace"
    property bool foregroundAnimationEnabled: true
    property bool transparent: false
    property var activePopout: null
    function registerClickTarget(t) {}
    function unregisterClickTarget(t) {}
    function showTooltip(t,s) {}
    function hideTooltip(t) {}
    function requestPopout(t) { activePopout = t }
    function releasePopout(t) { if(activePopout === t) activePopout = null }
  }
  PanelWindow {
    color: "transparent"
    anchors { top: true; left: true; right: true }
    implicitHeight: 26
    exclusionMode: ExclusionMode.Ignore
    Island.BarWidget { id: widget; hoverSuppressed:true; anchors.centerIn: parent; width: implicitWidth; height: implicitHeight; bar: fakeBar }
  }
  TestCase {
    id: test
    when: false
    function checkExit(ok,message) {
      if(!ok) {console.log("ISLAND_MOTION_FAIL:",message);Qt.quit();throw new Error(message)}
    }
    property int exitTick: 0
    property bool artworkFadeTailSeen: false
    property real startWidth: 0
    property real playerWidth: 0
    property point mediaControlPosition: Qt.point(0,0)
    property string nativeSize: ""
    function sampleExit(popup) {
      checkExit(popup.visible && popup.backingWindowVisible && popup.shown>0.1 && popup.shown<0.95,"close has no perceptible intermediate frame")
      checkExit(popup.drawnWidth<startWidth-1 && popup.drawnWidth>startWidth*0.9,"close does not gently contract: stage="+exitTick+", from="+startWidth+", current="+popup.drawnWidth+", open="+popup.open)
      checkExit(popup.width+"x"+popup.height===nativeSize,"closing resized the native surface")
    }
    function test_exit() {
      service.latest=service.allEntries[0]
      service.player=p;p.trackTitle="A test track";p.trackArtist="Test artist";p.playbackState=MprisPlaybackState.Playing;p.isPlaying=true;service.playing=true
      widget.open()
      exitClock.start()
    }
    // Sample real exit frames, interrupt them with the next mode, then
    // verify the final completed close unmaps the native surface.
    function test_exit_step() {
      var popup=findChild(widget,"islandPopup"),tabs=findChild(widget,"islandTabs"),player=findChild(widget,"islandMediaPlayer"),art=findChild(widget,"islandPopupArtwork")
      exitTick++
      if(exitTick===20) {
        startWidth=popup.drawnWidth;nativeSize=popup.width+"x"+popup.height
        widget.close()
        checkExit(tabs.visible && player.visible && art.visible,"pinned close discarded its contents or backdrop before fading")
      }
      if([25,65,105,145,185].indexOf(exitTick)>=0) sampleExit(popup)
      if(exitTick===26) {
        widget.contentExpanded=false;widget.hoverOpen=true
        var hoverCard=findChild(popup,"islandPopupCard")
        mouseMove(hoverCard,hoverCard.width/2,hoverCard.height/2)
      }
      if(exitTick===50) {var card=findChild(popup,"islandPopupCard");mouseMove(card,card.width/2,card.height/2)}
      if(exitTick===60) {
        startWidth=popup.drawnWidth;playerWidth=player.width
        widget.hoverOpen=false
        checkExit(!tabs.visible && player.visible && art.visible,"hover close discarded its overview or showed tabs")
      }
      if(exitTick===65) checkExit(Math.abs(player.width-playerWidth)<1,"hover close reflowed its content")
      if(exitTick===66) widget.showNotification()
      if(exitTick===100) {
        var toast=findChild(tabs.parent,"notificationGroup-Test")
        var toastHeight=toast ? toast.height : -1
        startWidth=popup.drawnWidth
        widget.alertKind=""
        checkExit(toast && toast.visible && toast.height===toastHeight && popup.frameSuppressed,"toast expiry removed its text before fading")
      }
      if(exitTick===106) widget.alertKind="media"
      if(exitTick===132) {
        p.trackTitle="A very long track title that should elide without moving the player controls"
        mediaControlPosition=findChild(player,"mediaToggle").mapToGlobal(0,0)
        widget.hoverOpen=true
      }
      if(exitTick===138) {
        var at=findChild(player,"mediaToggle").mapToGlobal(0,0)
        checkExit(Math.abs(at.x-mediaControlPosition.x)<1 && Math.abs(at.y-mediaControlPosition.y)<1,"hovering Now Playing moved its transport controls")
        console.log("STABLE_MEDIA_CONTROLS_PASS")
      }
      if(exitTick===140) {
        startWidth=popup.drawnWidth
        widget.hoverOpen=false
        widget.alertKind=""
        checkExit(player.visible && art.visible,"media alert removed its player before fading")
      }
      if(exitTick===146) widget.openCalendar()
      if(exitTick>=147 && exitTick<180 && art.reveal<0.0001 && art.artworkReveal>0.005) {
        artworkFadeTailSeen=true
        checkExit(art.visible,"tab switch cut off album artwork before its opacity faded")
      }
      if(exitTick===180) {
        checkExit(artworkFadeTailSeen,"tab switch did not preserve the artwork fade tail")
        startWidth=popup.drawnWidth
        widget.close()
        checkExit(tabs.visible && Math.abs(findChild(widget,"islandCalendar").mapToItem(findChild(widget,"islandPageSwipe"),0,0).x)<1,"calendar close switched its content before fading")
      }
      if(exitTick===185) widget.openCalendar()
      if(exitTick===210) {
        checkExit(popup.visible && popup.shown>0.99 && Math.abs(popup.drawnWidth-popup.settledWidth)<1,"reopening interrupted exit did not restore the full panel")
        Commons.Style.reduceMotion=true
        reducedReveal.open=true
        checkExit(reducedReveal.shown===1,"reduced motion still animated opening")
        reducedReveal.open=false
        checkExit(reducedReveal.shown===0,"reduced motion still animated closing")
        Commons.Style.reduceMotion=false
        widget.close()
      }
      if(exitTick===226) {
        checkExit(!popup.visible && !popup.backingWindowVisible,"closed panel kept its native surface")
        console.log("ANIMATED_CLOSE_PASS")
        exitClock.stop()
        service.latestT3={id:"activity",title:"Проверка плашки",project:"Island",status:"completed",requestId:"",request:null,summary:""}
        service.doNotDisturb=true;service.t3Arrival()
        compare(widget.alertKind,"","DND must suppress T3")
        service.doNotDisturb=false;service.t3TargetScreen="other-monitor";service.t3Arrival()
        compare(widget.alertKind,"","Another monitor must not show T3")
        service.t3TargetScreen=widget.screenName;service.t3Arrival()
        compare(widget.alertKind,"t3")
        wait(100)
        var t3Card=findChild(widget,"t3ActivityToast")
        verify(t3Card.visible)
        verify(popup.bareCardShown && popup.padding===0,"T3 toast retained its outer container")
        verify(popup.frameSuppressed)
        var t3Waves=findChild(widget,"islandToastWaves")
        verify(t3Waves.visible && t3Waves.sourceIcon===t3Card.statusIcon,"T3 toast must radiate from its status icon")
        var t3Center=t3Card.statusIcon.mapToItem(t3Waves,t3Card.statusIcon.width/2,t3Card.statusIcon.height/2)
        verify(Math.abs(t3Center.x-t3Waves.origin.x)<1 && Math.abs(t3Center.y-t3Waves.origin.y)<1)
        verify(!widget.pinned,"T3 must not pin the popup")
        var lifetime=findChild(widget,"islandAlertLife")
        compare(lifetime.interval,4000)
        lifetime.interval=20;lifetime.restart();wait(60)
        compare(widget.alertKind,"","T3 popup must expire")
        service.t3Arrival()
        compare(widget.alertKind,"t3")
        service.latestT3=null
        compare(widget.alertKind,"","Focusing T3 must close its popup")
        verify(!lifetime.running,"Closed T3 popup kept its timer")
        console.log("T3_ACTIVITY_POPUP_PASS")
        console.log("ISLAND_MOTION_PASS")
        Qt.quit()
      }
    }
  }
  Island.PopupReveal {id:reducedReveal;targetWidth:200;targetHeight:100}
  Timer {id:exitClock;interval:16;repeat:true;onTriggered:test.test_exit_step()}

  property int tick: 0
  property var sizes: []
  property int offCenter: 0
  property var entrance: []
  property bool motionPassed: false
  Timer {
    id: motionClock
    interval: 16; repeat: true; running: true
    onTriggered: {
      var popup = test.findChild(widget,"islandPopup")
      if (!popup) return
      tick++
      if(tick===1) {
        widget.settings={format:"dddd HH:mm"}
        widget.updateSetting("calendarWeekStart","sunday")
        widget.updateSetting("weatherTemperatureUnit","kelvin")
        var calendar=test.findChild(widget,"islandCalendar")
        if(!fakeShell.writtenEntry || fakeShell.writtenEntry.calendarWeekStart!=="sunday" || fakeShell.writtenEntry.weatherTemperatureUnit!=="kelvin" || fakeShell.writtenEntry.format!=="dddd HH:mm" || calendar.firstDay!==0) {console.log("ISLAND_MOTION_FAIL: calendar/weather preferences were not saved with existing settings");Qt.quit();return}
        widget.updateSetting("calendarWeekStart","invalid")
        widget.updateSetting("weatherTemperatureUnit","invalid")
        if(widget.settings.calendarWeekStart!=="sunday" || widget.settings.weatherTemperatureUnit!=="kelvin") {console.log("ISLAND_MOTION_FAIL: invalid preference was accepted");Qt.quit();return}
        console.log("ISLAND_PREFERENCES_PASS")
      }
      if(tick===1 && Quickshell.env("ISLAND_EXIT_ONLY")) {motionClock.stop();test.test_exit();return}
      if(tick===5) {
        test.findChild(widget,"islandClock").triggerPress(Qt.RightButton)
        if(service.doNotDisturb || widget.settings.format!=="dddd h:mm AP") {console.log("ISLAND_MOTION_FAIL: right click did not cycle the native clock format or toggled DND");Qt.quit();return}
        widget.updateSetting("format","dddd HH:mm")
        service.setDoNotDisturb(true)
      }
      if(tick===7) {
        var dnd=test.findChild(widget,"islandDndIndicator"),clock=test.findChild(widget,"islandClock")
        // Visibility schedules a layout polish; timer ticks alone do not
        // guarantee it ran before we measure the newly shown indicator.
        dnd.parent.ensurePolished()
        var at=dnd.mapToItem(clock,0,0)
        if(!dnd.visible || dnd.height<Commons.Style.font.bodySmall || at.x<0 || at.x+dnd.width>clock.width || at.y<0 || at.y+dnd.height>clock.height) {console.log("ISLAND_MOTION_FAIL: DND indicator is tiny or outside the clock",JSON.stringify({x:at.x,y:at.y,w:dnd.width,h:dnd.height,cw:clock.width,ch:clock.height}));Qt.quit();return}
        service.setDoNotDisturb(false)
      }
      if(tick === 10) { test.mouseMove(widget.parent,1,1);service.latest=service.allEntries[0]; service.arrivalChanged() }
      if(tick===30) {
        if(!popup.frameSuppressed || test.findChild(popup,"islandPopupCard").color.toString()!==Commons.Color.popups.background.toString() || test.findChild(widget,"islandTabs").visible) { console.log("ISLAND_MOTION_FAIL: notification toast lost its themed background or retained navigation",JSON.stringify({pinned:widget.pinned,hover:widget.hoverOpen,alert:widget.alertKind,frame:popup.frameSuppressed,color:test.findChild(popup,"islandPopupCard").color.toString(),theme:Commons.Color.popups.background.toString()}));widget.close();Qt.quit();return }
      }
      if(tick===30 && !test.findChild(widget,"islandToastWaves").visible) {console.log("ISLAND_MOTION_FAIL: incoming notification has no radio waves");Qt.quit();return}
      if(tick===30) {
        var waves=test.findChild(widget,"islandToastWaves")
        var icon=waves.sourceIcon
        var center=icon.mapToItem(waves,icon.width/2,icon.height/2)
        if(Math.abs(waves.origin.x-center.x)>=1 || Math.abs(waves.origin.y-center.y)>=1) {console.log("ISLAND_MOTION_FAIL: notification wave origin",waves.origin,center);Qt.quit();return}
        console.log("NOTIFICATION_WAVE_ORIGIN_PASS")
      }
      if(tick===32) {
        Commons.Style.reduceMotion=true
        service.latest=service.allEntries[1];service.arrivalChanged()
      }
      if(tick===36) {
        var replacedWaves=test.findChild(widget,"islandToastWaves"),replacedIcon=replacedWaves.sourceIcon
        if(!replacedIcon) {console.log("ISLAND_MOTION_FAIL: replacement lost notification icon");Qt.quit();return}
        var replacedCenter=replacedIcon.mapToItem(replacedWaves,replacedIcon.width/2,replacedIcon.height/2)
        if(Math.abs(replacedWaves.origin.x-replacedCenter.x)>=1 || Math.abs(replacedWaves.origin.y-replacedCenter.y)>=1) {console.log("ISLAND_MOTION_FAIL: reduced-motion wave origin");Qt.quit();return}
        Commons.Style.reduceMotion=false
        console.log("NOTIFICATION_WAVE_REPLACEMENT_PASS")
      }
      if(tick === 40) widget.open()
      if(tick >= 10 && tick < 70 && popup.backingWindowVisible && (popup.shown === undefined || popup.shown > 0.01)) sizes.push(popup.width+"x"+popup.height)
      if(tick >= 10 && tick < 36 && popup.shown > 0.01) entrance.push({w:popup.drawnWidth,h:popup.drawnHeight,target:popup.contentWidth})
      if(popup.open && popup.shown > 0.01 && popup.cardOrigin !== undefined && Math.abs(popup.cardOrigin.x+popup.drawnWidth/2-popup.anchorCenter.x)>1) offCenter++
      if(tick === 70) {
        var tabs=test.findChild(widget,"islandTabs"), player=test.findChild(widget,"islandMediaPlayer")
        if(!tabs.visible || player.mapToItem(tabs.parent,0,0).y<tabs.y+tabs.height || popup.frameSuppressed) { console.log("ISLAND_MOTION_FAIL: tabs are not above music or persistent frame is missing");widget.close();Qt.quit();return }
        if(test.findChild(widget,"islandToastWaves").visible) {console.log("ISLAND_MOTION_FAIL: notification waves leaked into overview");Qt.quit();return}
        var panelEffect=test.findChild(widget,"islandPanelSpotlight")
        if(panelEffect.width<tabs.width || panelEffect.mapToItem(tabs.parent,0,0).y>tabs.y || tabs.children[0].color.a!==0) {console.log("ISLAND_MOTION_FAIL: shared cursor effect excludes tabs or tabs retain a fill");Qt.quit();return}
        var artwork = test.findChild(widget,"islandPopupArtwork")
        if(artwork.mapToItem(tabs.parent,0,0).y>tabs.y || artwork.height<tabs.height+player.height) { console.log("ISLAND_MOTION_FAIL: music backdrop does not extend behind tabs");widget.close();Qt.quit();return }
        if(!service.playing && (artwork.opacity>0.01 || test.findChild(widget,"islandClockArtwork").opacity>0.01)) {
          console.log("ISLAND_MOTION_FAIL: music backdrop visible while playback is paused",artwork.opacity)
          widget.close(); Qt.quit(); return
        }
        if(!test.findChild(widget,"islandMediaPlayer").visible) { console.log("ISLAND_MOTION_FAIL: paused player was hidden"); widget.close(); Qt.quit(); return }
        var distinct = sizes.filter(function(s,i) {return sizes.indexOf(s) === i})
        console.log("MOTION_NATIVE_SIZES",distinct.length,JSON.stringify(distinct.slice(0,8)))
        var seed = entrance[0], grown = entrance[entrance.length-1]
        var grows = seed && grown && seed.w < seed.target*0.4 && grown.w > grown.target*0.9 && grown.h > seed.h*2
        console.log("MOTION_SEED_GROWTH",JSON.stringify(seed),JSON.stringify(grown))
        motionPassed=distinct.length===1 && offCenter===0 && grows
        if(!motionPassed) { console.log("ISLAND_MOTION_FAIL: native surface resized during transition"); widget.close(); Qt.quit() }
      }
      if(tick===72) test.mouseClick(test.findChild(popup,"islandOutside"),popup.width/2,13,Qt.MiddleButton)
      if(tick===90) {
        if(!widget.pinned || !widget.calendarMode) { console.log("ISLAND_MOTION_FAIL: middle click did not open calendar"); widget.close(); Qt.quit(); return }
        test.findChild(widget,"islandTabOverview").clicked()
        if(!Commons.Style.reduceMotion && !test.findChild(widget,"islandPanelSpotlight").rippling) {console.log("ISLAND_MOTION_FAIL: tab click did not use the shared wave");Qt.quit();return}
      }
      if(tick===106) {
        if(widget.calendarMode || !widget.pinned || Math.abs(test.findChild(widget,"islandMediaPlayer").mapToItem(test.findChild(widget,"islandPageSwipe"),0,0).x)>1) { console.log("ISLAND_MOTION_FAIL: calendar back changed panel lifetime"); widget.close(); Qt.quit(); return }
        test.findChild(widget,"calendarOpen").clicked()
      }
      if(tick===122) {
        if(!widget.calendarMode || Math.abs(test.findChild(widget,"islandCalendar").mapToItem(test.findChild(widget,"islandPageSwipe"),0,0).x)>1) { console.log("ISLAND_MOTION_FAIL: calendar glyph did not switch visible page"); widget.close(); Qt.quit(); return }
        test.findChild(widget,"islandClock").triggerPress(Qt.MiddleButton)
      }
      if(tick===140) {
        if(widget.pinned || widget.calendarMode) { console.log("ISLAND_MOTION_FAIL: middle click did not close calendar"); widget.close(); Qt.quit(); return }
        test.findChild(widget,"islandClock").triggerPress(Qt.LeftButton)
        if(!widget.pinned || widget.calendarMode) { console.log("ISLAND_MOTION_FAIL: normal click did not reopen inbox"); widget.close(); Qt.quit(); return }
        p.playbackState=MprisPlaybackState.Playing; p.isPlaying=true; service.playing=true
      }
      if(tick===175) {
        if(Math.abs(test.findChild(widget,"islandPopupArtwork").opacity-0.7)>0.01) { console.log("ISLAND_MOTION_FAIL: playback did not reveal music backdrop",test.findChild(widget,"islandPopupArtwork").opacity,test.findChild(widget,"islandPopupArtwork").active,test.findChild(widget,"islandPopupArtwork").reveal); widget.close(); Qt.quit(); return }
        p.playbackState=MprisPlaybackState.Stopped; p.isPlaying=false; service.playing=false
      }
      if(tick===195) {
        if(test.findChild(widget,"islandPopupArtwork").opacity>0.01 || test.findChild(widget,"islandClockArtwork").opacity>0.01 || test.findChild(widget,"islandMediaPlayer").visible) { console.log("ISLAND_MOTION_FAIL: stopped music left its backdrop or player"); widget.close(); Qt.quit(); return }
        p.trackTitle=""; p.trackArtist=""; p.playbackState=MprisPlaybackState.Playing; p.isPlaying=true; service.playing=true
      }
      if(tick===215) {
        if(test.findChild(widget,"islandPopupArtwork").opacity>0.01 || test.findChild(widget,"islandClockArtwork").opacity>0.01 || test.findChild(widget,"islandMediaPlayer").visible) { console.log("ISLAND_MOTION_FAIL: empty track left its backdrop or player"); widget.close(); Qt.quit(); return }
        service.player=null; service.playing=false
      }
      if(tick===225) {
        if(test.findChild(widget,"islandPopupArtwork").opacity>0.01 || test.findChild(widget,"islandMediaPlayer").visible) { console.log("ISLAND_MOTION_FAIL: disconnected player left its backdrop"); widget.close(); Qt.quit(); return }
        widget.close();test.mouseMove(widget.parent,1,1);service.latest=service.allEntries[1];service.arrivalChanged()
      }
      if(tick===255) {
        if(!popup.frameSuppressed || test.findChild(popup,"islandPopupCard").color.toString()!==Commons.Color.popups.background.toString()) { console.log("ISLAND_MOTION_FAIL: incoming toast lost its themed background",JSON.stringify({pinned:widget.pinned,hover:widget.hoverOpen,alert:widget.alertKind,frame:popup.frameSuppressed,color:test.findChild(popup,"islandPopupCard").color.toString(),theme:Commons.Color.popups.background.toString()}));widget.close();Qt.quit();return }
        widget.close()
      }
      if(tick===260) {
        if(!popup.frameSuppressed || test.findChild(popup,"islandPopupCard").color.toString()!==Commons.Color.popups.background.toString()) { console.log("ISLAND_MOTION_FAIL: toast background changed while closing");widget.close();Qt.quit();return }
        console.log("CALENDAR_ROUTING_PASS")
        console.log("MUSIC_BACKDROP_PASS")
        console.log("TOP_TABS_AND_COMPACT_TOAST_PASS")
        widget.close(); widget.contentExpanded=false; widget.hoverOpen=true
      }
      if(tick===280) {
        var pager=test.findChild(widget,"islandPageSwipe")
        test.mouseWheel(pager,pager.width/2,pager.height/2,-120,0,Qt.NoButton)
      }
      if(tick===290) {
        if(widget.pinned || widget.calendarMode || test.findChild(widget,"islandTabs").visible) {console.log("ISLAND_MOTION_FAIL: hover preview exposed tabs or switched away from Overview");Qt.quit();return}
        widget.open()
        var pager=test.findChild(widget,"islandPageSwipe")
        test.mouseWheel(pager,pager.width/2,pager.height/2,-120,0,Qt.NoButton)
      }
      if(tick===310) {
        var pager=test.findChild(widget,"islandPageSwipe")
        if(!widget.calendarMode || Math.abs(test.findChild(widget,"islandCalendar").mapToItem(pager,0,0).x)>1) {console.log("ISLAND_MOTION_FAIL: hover-to-pinned wheel resized without moving calendar contents");widget.close();Qt.quit();return}
        test.mouseWheel(pager,pager.width/2,pager.height/2,120,0,Qt.NoButton)
      }
      if(tick===340) {
        if(widget.calendarMode || Math.abs(test.findChild(widget,"islandMediaPlayer").mapToItem(test.findChild(widget,"islandPageSwipe"),0,0).x)>1) {console.log("ISLAND_MOTION_FAIL: wheel did not return visible overview");widget.close();Qt.quit();return}
        console.log("RESIZING_PAGE_WHEEL_PASS")
        test.findChild(widget,"islandTabControls").clicked()
      }
      if(tick===370) {
        var controls=test.findChild(widget,"islandControls"),pager=test.findChild(widget,"islandPageSwipe")
        if(!widget.controlsMode || !controls.active || Math.abs(controls.mapToItem(pager,0,0).x)>1) {console.log("ISLAND_MOTION_FAIL: Controls tab did not switch visible page");widget.close();Qt.quit();return}
        if(test.findChild(widget,"islandTabControls").x>=test.findChild(widget,"islandTabOverview").x) {console.log("ISLAND_MOTION_FAIL: Controls is not the first tab");widget.close();Qt.quit();return}
        test.mouseWheel(pager,pager.width/2,pager.height/2,-120,0,Qt.NoButton)
      }
      if(tick===400) {
        if(widget.controlsMode || widget.calendarMode || Math.abs(test.findChild(widget,"islandMediaPlayer").mapToItem(test.findChild(widget,"islandPageSwipe"),0,0).x)>1) {console.log("ISLAND_MOTION_FAIL: Controls wheel did not return Overview");widget.close();Qt.quit();return}
        console.log("CONTROLS_NAVIGATION_PASS")
        var clock=test.findChild(widget,"islandClock")
        test.mouseWheel(clock,clock.width/2,clock.height/2,0,-120,Qt.NoButton)
        if(!widget.calendarMode || !widget.pinned) {console.log("ISLAND_MOTION_FAIL: clock wheel did not open the next tab");Qt.quit();return}
        test.mouseWheel(clock,clock.width/2,clock.height/2,0,120,Qt.NoButton)
        if(widget.calendarMode || widget.controlsMode || widget.weatherMode) {console.log("ISLAND_MOTION_FAIL: reverse clock wheel did not return to Overview");Qt.quit();return}
        console.log("CLOCK_WHEEL_PASS")
        motionClock.stop()
        test.test_exit()
      }
    }
  }
}
