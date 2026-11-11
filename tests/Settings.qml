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
  FloatingWindow {
    color: "transparent"
    visible:true;implicitWidth:600;implicitHeight:100
    Island.BarWidget { id: widget; hoverSuppressed:true; anchors.centerIn: parent; width: implicitWidth; height: implicitHeight; bar: fakeBar }
  }
  Island.PopupReveal {id:reveal;targetWidth:400;targetHeight:300}
  Island.IndicatorState {id:events}
  TestCase {
    id:test;when:false
    function check(ok,message){if(!ok) throw new Error(message)}
    function run() {
      try {
        widget.settings={id:"gshulga.island",format:"HH:mm",customMetadata:"keep"}
        widget.updateSetting("hoverDelay",300)
        check(fakeShell.writtenEntry.hoverDelay===300 && fakeShell.writtenEntry.customMetadata==="keep","saving lost existing settings")
        widget.updateSetting("hoverDelay",-1)
        widget.updateSetting("notificationStyle","invalid")
        widget.updateSetting("animationsEnabled","false")
        check(widget.settings.hoverDelay===300 && widget.settings.notificationStyle===undefined && widget.settings.animationsEnabled===undefined,"invalid settings accepted")
        widget.updateSetting("openingPage","last")
        widget.openCalendar();widget.close();widget.open()
        check(widget.calendarMode,"last page was not restored")
        widget.updateSetting("calendarEnabled",false)
        check(widget.controlsMode,"disabled current page did not fall back to Controls")
        widget.openCalendar();check(widget.controlsMode,"disabled page opened through IPC path")
        widget.updateSetting("openingPage","overview");widget.updateSetting("overviewEnabled",false)
        widget.open();check(widget.controlsMode,"disabled opening page did not fall back")
        widget.close();widget.hoverOpen=true;widget.updateSetting("hoverPreview",false)
        check(!widget.hoverOpen,"disabling hover retained preview")
        widget.updateSetting("notificationStyle","bar")
        service.latest=service.allEntries[0];widget.showNotification()
        check(widget.stripNotification && !findChild(widget,"islandPopup").open,"bar notification opened card")
        widget.updateSetting("notificationStyle","card")
        check(!widget.stripNotification && findChild(widget,"islandPopup").open,"card notification not opened")
        widget.alertKind="";widget.updateSetting("trackAlerts",false)
        service.playing=true;service.track="one"
        check(widget.alertKind==="","disabled track alert appeared")
        widget.updateSetting("trackAlerts",true);service.track="two"
        check(widget.alertKind==="media","track alert not restored")
        widget.updateSetting("musicVisualization","off")
        check(!findChild(widget,"islandClockArtwork").active,"disabled music effect remains active")
        widget.updateSetting("musicVisualization","open")
        check(!Island.Preferences.visualizationAllowed(true) && Island.Preferences.visualizationAllowed(false),"open-only mode still affects the bar")
        widget.updateSetting("panelAnimation",false)
        widget.updateSetting("musicVisualization","visible")
        check(!Island.Preferences.visualizationAllowed(true),"bar animation switch ignored")
        events.consumers=[widget]
        widget.updateSetting("osdVolume",false)
        check(events.showOsd('{"icon":"volume","value":40}') && !events.osdActive,"disabled OSD not silently handled")
        widget.updateSetting("osdVolume",true)
        check(events.showOsd('{"icon":"volume","value":40}') && events.osdActive,"re-enabled OSD not shown")
        widget.updateSetting("osdVolume",false)
        check(!events.osdActive,"disabled active OSD not dismissed")
        widget.updateSetting("osdModes",false)
        check(events.showOsd('{"icon":"󰂛","message":"DND"}') && !events.osdActive,"disabled mode event not handled")
        events.consumers=[]
        reveal.open=true;wait(50);widget.updateSetting("animationsEnabled",false)
        check(Island.Preferences.reduceMotion && Island.Preferences.duration(200)===0,"animations switch ignored")
        check(reveal.shown===1 && reveal.stretch===1 && reveal.contentShown===1,"reducing motion left entrance unfinished")
        reveal.open=false
        check(reveal.shown===0 && reveal.contentShown===0,"reduced motion left exit unfinished")
        widget.close()
        console.log("SETTINGS_PASS")
      } catch(error) {console.log("SETTINGS_FAIL",String(error),error.stack)}
      Qt.quit()
    }
  }
  Timer {interval:150;running:true;onTriggered:test.run()}
}
