import QtQuick
import QtTest
import Quickshell
import "Island" as Island
ShellRoot {
  QtObject {
    id: service
    readonly property var modules: ({notifications:service,downloads:service})
    property bool allowed:true
    property var indicators: Island.IndicatorState {layouts.observeSystem:false}
    property var downloads:[]
    property var t3:null
    function openDownload(row) {}
    property bool playing: false
    property string focusedScreenName:""
    property string targetScreen:""
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
      leave()
      service.indicators.downloading=true
      tryCompare(widget,"showOsd",true,500)
      enter(clock)
      wait(80)
      verify(!widget.hoverOpen)
      tryCompare(widget,"showOsd",false,2200)
      previewOpens("stationary pointer after download announcement")
      service.indicators.downloading=false
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
      leave();tryCompare(widget,"hoverOpen",false,500)
      widget.updateSetting("clockLayout",[{id:"now",kind:"indicator",side:"left"}])
      service.downloads=["sample.iso","other.iso"].map(function(name,index){
        return {key:name,active:true,filename:name,downloadPath:"/downloads/"+name,downloadedBytes:1024,ts:index+1}
      })
      var indicator=findChild(widget,"islandNowIndicator")
      tryVerify(function(){return indicator && indicator.visible},500)
      tryCompare(popup,"visible",false,1000)
      enter(indicator)
      var nowCard=findChild(widget,"nowActivityPreview")
      tryVerify(function(){return nowCard.visible && nowCard.copy.detail.indexOf("sample.iso")>=0},500)
      verify(!widget.pinned)
      enter(clock)
      tryVerify(function(){return !nowCard.visible && widget.hoverOpen},500)
      enter(indicator)
      tryVerify(function(){return nowCard.visible},500)
      tryVerify(function(){return popup.shown>0.99 && Math.abs(popup.drawnHeight-popup.layoutHeight)<1},1000)
      mouseClick(nowCard,nowCard.width/2,nowCard.height/2)
      tryCompare(widget,"pinned",true,500)
      var pages=findChild(widget,"islandPopupPages")
      tryCompare(pages,"detailPage","downloads",500)
      tryVerify(function(){var file=findChild(pages,"download-sample.iso");return file && file.visible})
      verify(!findChild(pages,"download-other.iso"))
      // Exercise the real pinned popup, including its Escape/Back handler.
      pages.Window.window.requestActivate()
      tryCompare(pages.Window.window,"active",true,500)
      var folder=findChild(findChild(pages,"download-sample.iso"),"downloadOpenFolder")
      tryCompare(findChild(pages,"overviewBack"),"activeFocus",true,1000)
      folder.forceActiveFocus(Qt.TabFocusReason)
      var folderTip=findChild(folder,"islandButtonTooltip")
      tryCompare(folderTip,"opened",true,1500)
      keyClick(Qt.Key_Escape)
      tryCompare(folderTip,"visible",false,500)
      verify(widget.pinned && folder.activeFocus && pages.detailPage==="downloads","Hint Escape navigated away from the focused download")
      verify(!findChild(pages,"download-sample.iso").activeFocusOnTab)
      service.downloads=[Object.assign({},service.downloads[0],{active:false}),service.downloads[1]]
      tryVerify(function(){return !findChild(pages,"download-sample.iso").row.active && !findChild(pages,"download-other.iso")})
      service.downloads=service.downloads.slice(1)
      tryVerify(function(){var ended=findChild(pages,"downloadEnded");return ended && ended.visible && ended.text.indexOf("sample.iso")>=0 && !findChild(pages,"download-other.iso")})
      keyClick(Qt.Key_Escape)
      tryCompare(pages,"detailPage","",500)
      widget.openNow({kind:"downloads",row:service.downloads[0]})
      tryVerify(function(){return pages.detailPage==="downloads" && findChild(pages,"download-other.iso")})
      service.downloads=[]
      tryVerify(function(){var ended=findChild(pages,"downloadEnded");return ended && ended.visible && ended.text.indexOf("other.iso")>=0})
      keyClick(Qt.Key_Escape)
      tryCompare(pages,"detailPage","",500)
      var gear=findChild(pages,"overviewCustomize")
      wait(30) // Allow Overview to restore the summary focus after Back.
      gear.forceActiveFocus(Qt.TabFocusReason)
      tryCompare(gear,"activeFocus",true,500)
      var keyboardTip=findChild(gear,"islandButtonTooltip")
      tryCompare(keyboardTip,"opened",true,1500)
      keyClick(Qt.Key_Escape)
      tryCompare(keyboardTip,"visible",false,500)
      verify(widget.pinned && gear.activeFocus,"Dismissing an icon hint closed the pinned popup")
      keyClick(Qt.Key_Escape)
      tryCompare(widget,"pinned",false,500)
      leave()
      service.targetScreen="old-notification-screen"
      service.focusedScreenName=widget.screenName
      service.playing=true;service.track="first"
      compare(widget.showAlert,true)
      compare(widget.alertKind,"media")
      service.focusedScreenName="other-monitor"
      compare(widget.showAlert,true,"focus alone must not move the toast")
      service.track="second"
      compare(widget.showAlert,false)
      service.focusedScreenName=widget.screenName
      service.track="third";compare(widget.showAlert,true)
      service.doNotDisturb=true;compare(widget.showAlert,false)
      service.track="muted";service.doNotDisturb=false
      compare(widget.showAlert,false)
      console.log("HOVER_PASS")
    }
    function run(){try{test_hover()}catch(e){console.log("MODULES_FAIL",String(e),e.stack)}Qt.quit()}
  }
  Timer {interval:200;running:true;onTriggered:test.run()}
}
