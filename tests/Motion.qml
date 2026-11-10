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
    Island.BarWidget { id: widget; anchors.centerIn: parent; width: implicitWidth; height: implicitHeight; bar: fakeBar }
  }
  TestCase { id: test; when: false }
  property int tick: 0
  property var sizes: []
  property int offCenter: 0
  property var entrance: []
  property bool motionPassed: false
  Timer {
    interval: 16; repeat: true; running: true
    onTriggered: {
      var popup = test.findChild(widget,"islandPopup")
      if (!popup) return
      tick++
      if(tick === 10) { service.latest=service.allEntries[0]; service.arrivalChanged() }
      if(tick===30) {
        if(!popup.frameSuppressed || test.findChild(popup,"islandPopupCard").color.a!==0 || test.findChild(widget,"islandTabs").visible) { console.log("ISLAND_MOTION_FAIL: notification toast retained a background or navigation");widget.close();Qt.quit();return }
      }
      if(tick === 40) widget.open()
      if(tick >= 10 && tick < 70 && popup.backingWindowVisible && (popup.shown === undefined || popup.shown > 0.01)) sizes.push(popup.width+"x"+popup.height)
      if(tick >= 10 && tick < 36 && popup.shown > 0.01) entrance.push({w:popup.drawnWidth,h:popup.drawnHeight,target:popup.contentWidth})
      if(popup.open && popup.shown > 0.01 && popup.cardOrigin !== undefined && Math.abs(popup.cardOrigin.x+popup.drawnWidth/2-popup.screen.width/2)>1) offCenter++
      if(tick === 70) {
        var tabs=test.findChild(widget,"islandTabs"), player=test.findChild(widget,"islandMediaPlayer")
        if(!tabs.visible || player.mapToItem(tabs.parent,0,0).y<tabs.y+tabs.height || popup.frameSuppressed) { console.log("ISLAND_MOTION_FAIL: tabs are not above music or persistent frame is missing");widget.close();Qt.quit();return }
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
        if(test.findChild(widget,"islandPopupArtwork").opacity<0.99) { console.log("ISLAND_MOTION_FAIL: playback did not reveal music backdrop",test.findChild(widget,"islandPopupArtwork").opacity,test.findChild(widget,"islandPopupArtwork").active,test.findChild(widget,"islandPopupArtwork").reveal); widget.close(); Qt.quit(); return }
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
        widget.close(); service.latest=service.allEntries[1]; service.arrivalChanged()
      }
      if(tick===255) {
        if(!popup.frameSuppressed || test.findChild(popup,"islandPopupCard").color.a!==0) { console.log("ISLAND_MOTION_FAIL: incoming toast is not transparent");widget.close();Qt.quit();return }
        widget.close()
      }
      if(tick===260) {
        if(!popup.frameSuppressed || test.findChild(popup,"islandPopupCard").color.a!==0) { console.log("ISLAND_MOTION_FAIL: background flashed while closing toast");widget.close();Qt.quit();return }
        console.log("ISLAND_MOTION_PASS")
        console.log("CALENDAR_ROUTING_PASS")
        console.log("MUSIC_BACKDROP_PASS")
        console.log("TOP_TABS_AND_TRANSPARENT_TOAST_PASS")
        widget.close(); widget.contentExpanded=false; widget.hoverOpen=true
      }
      if(tick===280) {
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
        widget.close();Qt.quit()
      }
    }
  }
}
