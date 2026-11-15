import QtQuick
import QtTest
import Quickshell
import "Island" as Island
ShellRoot {
  QtObject {
    id: service
    readonly property var modules: ({notifications:service})
    property bool playing: false
    property string track: ""
    property real visualPhase: 0
    property real audioLevel: 0
    property real audioBass: 0
    property real audioTreble: 0
    property var player: null
    property bool hasMedia: false
    property var players: []
    readonly property var activeEntries: allEntries
    property var historyEntries: []
    property var allEntries: [{key:"hover-test",app:"Test",summary:"Hover preview",body:"A notification",ts:1}]
    property var latest: null
    property bool doNotDisturb: false
    property var mutedSources: []
    property string error: ""
    signal arrivalChanged()
    function actions(row) {return []}
  }
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
    Island.BarWidget { id: widget; settings:({hoverDelay:20,weatherEnabled:false}); anchors.centerIn: parent; width: implicitWidth; height: implicitHeight; bar: fakeBar }
  }
  TestCase {
    id: test
    when: false
    function enter(clock) {mouseMove(clock,clock.width/2,clock.height/2)}
    function leave() {mouseMove(widget.parent,1,1);wait(30);compare(widget.isHovered,false)}
    function previewOpens(context) {
      try {
        tryCompare(widget,"hoverOpen",true,500)
        tryCompare(findChild(widget,"islandPopup"),"open",true,500)
        tryVerify(function(){return findChild(widget,"islandPopupPages").implicitHeight>0},500)
      } catch(e) {
        var pages=findChild(widget,"islandPopupPages")
        throw new Error(context+": hovered="+widget.isHovered+", suppressed="+widget.hoverSuppressed+", hoverOpen="+widget.hoverOpen+", hovering="+pages.hovering+", size="+pages.width+"x"+pages.implicitHeight)
      }
    }
    function test_hover() {
      var clock=findChild(widget,"islandClock")
      var popup=findChild(widget,"islandPopup")
      leave();enter(clock)
      previewOpens("initial hover")
      leave()
      tryCompare(widget,"hoverOpen",false,500)
      // Dismiss while already outside, through both the popup's outside-click
      // path and the same close() entry point used by Escape and IPC.
      for(var attempt=0;attempt<3;attempt++) {
        widget.open()
        compare(widget.pinned,true)
        leave()
        var outside=findChild(popup,"islandOutside")
        mouseClick(outside,outside.width-2,outside.height-2)
        compare(widget.pinned,false)
        enter(clock)
        previewOpens("first hover after outside click #"+attempt)
        widget.open();leave();widget.close()
        enter(clock)
        previewOpens("first hover after Escape/IPC close #"+attempt)
        leave();tryCompare(widget,"hoverOpen",false,500)
      }
      // A pinned surface covers the clock. Its outside handler forwards the
      // click before the native bar can receive a fresh hover entry.
      for(var button of [Qt.LeftButton,Qt.MiddleButton]) {
        if(button===Qt.MiddleButton) widget.openCalendar();else widget.open()
        leave()
        clock.triggerPress(button)
        compare(widget.pinned,false)
        enter(clock);wait(100)
        compare(widget.hoverOpen,false,"closing via clock must not immediately reopen")
        leave();enter(clock)
        previewOpens("clock toggle rearms after leaving")
        leave();tryCompare(widget,"hoverOpen",false,500)
      }
      // Closing while still over the clock suppresses reopening until exit.
      enter(clock);previewOpens("hover before explicit close")
      widget.close();wait(100)
      compare(widget.hoverOpen,false)
      compare(widget.hoverSuppressed,true)
      leave();enter(clock)
      previewOpens("hover after leaving a suppressed clock")
      leave();tryCompare(widget,"hoverOpen",false,500)
      service.allEntries=[]
      enter(clock)
      previewOpens("hover still shows the header without active notifications")
      console.log("HOVER_PASS")
    }
    function run(){try{test_hover()}catch(e){console.log("MODULES_FAIL",String(e),e.stack)}Qt.quit()}
  }
  Timer {interval:200;running:true;onTriggered:test.run()}
}
