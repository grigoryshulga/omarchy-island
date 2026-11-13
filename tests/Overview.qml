import QtQuick
import QtQuick.Layouts
import QtTest
import Quickshell
import Quickshell.Services.Mpris
import "Island/Model.js" as Model
import "Island/SpotlightModel.js" as Spotlight
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  QtObject {
    id: fakeWeather
    property bool allowed: true
    property bool loading: false
    property bool searching: false
    property bool saving: false
    property bool stale: false
    property bool useImperial: false
    property string temperatureUnit: "celsius"
    property string error: ""
    property string searched: ""
    property int autoCalls: 0
    property var suggestions: []
    property var report: ({location:"Demo City",country:"",fetchedAt:1794300000,current:{temperature:7,feels:5,wind:12,humidity:81,code:63,isDay:true},days:[{"date":"2026-11-10","min":3,"max":8,"code":63},{"date":"2026-11-11","min":1,"max":6,"code":3},{"date":"2026-11-12","min":-1,"max":3,"code":71},{"date":"2026-11-13","min":0,"max":7,"code":0},{"date":"2026-11-14","min":-2,"max":2,"code":61},{"date":"2026-11-15","min":-3,"max":1,"code":3},{"date":"2026-11-16","min":1,"max":5,"code":2},{"date":"2026-11-17","min":2,"max":8,"code":0}]})
    function activate() {}
    function refresh() {}
    function search(query) { searched=query }
    property var chosen: null
    function choose(place) {chosen=place}
    function cancelSearch() {suggestions=[]}
    function autoLocate() { autoCalls++ }
  }
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
    // The real service always provides a bridge, even when T3 is disabled.
    readonly property var modules:({weather:("weather" in service) ? service.weather : null,calendar:{allowed:true,calendars:("calendars" in service) ? service.calendars : null,reminders:("reminders" in service) ? service.reminders : null},notifications:service,media:service,t3:t3,agentLimits:agentLimits})
    property var t3: bridge
    property var agentLimits: limits
    property var weather: fakeWeather
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
    property var removed: []
    function clearHistory() {historyEntries=[]}
    function clear() {historyEntries=allEntries;allEntries=[]}
    function media(action) { mediaCalls++; p.isPlaying = !p.isPlaying }
    property var actionRows: []
    property var invokedRows: []
    property string executedRow: ""
    function execAction(row,index) { executedRow=row.key+":"+index }
    function actions(row) { return actionRows.indexOf(row.key)>=0 ? [{id:"read",text:"Mark as read"}] : [] }
    function invoke(row,id) { invokedRows=invokedRows.concat([row.key]);remove(row.key) }
    function activate(row) { activateCalls++ }
    function copyCode(row,code) { copied = code }
    function mute(s) { muted = s }
    function remove(key) { removed=removed.concat([key]);allEntries=allEntries.filter(function(row){return row.key!==key}) }
  }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("Island/i18n") }
  QtObject {
    id:bridge
    property bool allowed:true
    property bool connected:true
    property bool canRespond:false
    property bool responsesEnabled:false
    property var rows:[]
    function row(id) {return rows.find(function(r){return r.id===id})}
    function response(id) {return ""}
    function openThread(id) {}
  }
  QtObject {
    id:limits
    property bool allowed:true
    property bool busy:false
    property string error:""
    property double now:Date.now()
    property var pins:[]
    property var cache:({providers:[]})
    property var catalog:[]
    property var summary:[{id:"quota",name:"Codex",label:"Weekly",remaining:2,stale:true,pendingReset:false,resetsAt:0}]
    property var rows:summary
    function loadCatalog() {}
    function refresh() {}
  }
  FloatingWindow {
    id:window
    color:Island.Design.opaqueCanvas
    visible:true;implicitWidth:560;implicitHeight:660
    Island.IslandContent {id:overview;anchors.fill:parent;anchors.margins:16;service:service;strings:strings;expanded:true}
    Island.KeyboardNavigation {id:navigation;scope:overview;containers:[overview]}
    TestCase {
      id:test;when:false
      function test_overview() {
        var finished=[]
        for(var i=0;i<30;i++) finished.push({id:"done-"+i,title:"Completed task "+i,project:"Island",status:"completed",requestId:"",summary:""})
        bridge.rows=finished;wait(80)
        compare(overview.implicitHeight,overview.pageHeight,"Many finished tasks resized Overview")
        verify(!findChild(overview,"t3Session-done-0").visible,"Completed cards leaked into summary")
        compare(findChild(overview,"t3Count-finished").count,30,"Completed indicator missed tasks")
        verify(!findChild(overview,"t3Count-working").visible,"Zero working count is visible")
        var seek=findChild(overview,"mediaCompactProgress")
        verify(seek.visible && seek.enabled,"Compact player has no seek control")
        seek.forceActiveFocus();keyClick(Qt.Key_Right);compare(p.position,21,"Thin progress cannot seek")
        verify(findChild(overview,"mediaOpenDetails")===null,"Music still has submenu navigation")
        var braille=findChild(overview,"limitBrailleProgress")
        verify(braille.visible && braille.width>Commons.Style.space(104),"Quota braille field is not full width")
        var notificationsArrow=findChild(overview,"notificationsOpenDetails"),bell=findChild(overview,"overviewDnd")
        verify(bell.x<notificationsArrow.x,"Bell must precede the navigation arrow")
        verify(!findChild(overview,"mediaSeek").visible,"Summary still shows full playback controls")
        verify(!findChild(overview,"mediaSectionHeading").visible,"Summary still has an outer media heading")
        verify(findChild(overview,"limitRemaining").text.indexOf("·")>=0,"Cached quota lost its marker")
        verify(!findChild(overview,"limitSummaryResetCountdown").visible,"Summary invented a reset countdown")
        verify(findChild(overview,"notification-n4")===null,"Summary did not cap notifications")
        var height=overview.implicitHeight
        var t3Button=findChild(overview,"t3OpenDetails")
        var limitsButton=findChild(overview,"limitsExpand")
        compare(t3Button.mapToItem(overview,0,0).x,limitsButton.mapToItem(overview,0,0).x,"T3 and limits navigation are not aligned")
        compare(t3Button.width,limitsButton.width,"T3 and limits arrows have different sizes")
        t3Button.forceActiveFocus();t3Button.clicked();wait(50)
        verify(!findChild(overview,"islandMediaPlayer").visible,"T3 details did not replace music")
        compare(findChild(overview,"overviewBack").mapToItem(overview,0,0).x,t3Button.mapToItem(overview,0,0).x,"Back arrow is not aligned to the right")
        verify(findChild(overview,"t3Session-done-29").visible,"Full T3 list is incomplete")
        compare(overview.implicitHeight,height,"Full T3 list grew the panel")
        verify(overview.back());wait(50)
        verify(t3Button.activeFocus,"Back did not restore focus")
        var notifications=findChild(overview,"notificationsOpenDetails")
        notifications.forceActiveFocus();notifications.clicked();wait(50)
        verify(findChild(overview,"notification-n4").visible,"Full notifications are incomplete")
        verify(findChild(overview,"notificationsHistory").visible,"History is missing from notification details")
        compare(overview.implicitHeight,height)
        verify(overview.back());wait(50)
        findChild(overview,"limitsExpand").clicked();wait(50)
        verify(overview.detailPage==="agentLimits" && !findChild(overview,"t3Section").visible,"Limits did not replace summary")
        compare(overview.implicitHeight,height)
        verify(overview.back());wait(50)
        bridge.rows=finished.concat([
          {id:"busy",title:"Working task",status:"running",requestId:""},
          {id:"question",title:"Question",status:"running",requestId:"q"},
          {id:"failed",title:"Failed task",status:"failed",requestId:""},
          {id:"cancelled",title:"Stopped task",status:"cancelled",requestId:""}
        ].map(function(row){return Object.assign({project:"Island",summary:""},row)}));wait(80)
        for(var kind of ["attention","working","failed","other"]) {
          var badge=findChild(overview,"t3Count-"+kind)
          compare(badge.count,1,"Incorrect status count: "+kind)
          verify(badge.visible && badge.tooltipText!=="","Missing status indicator: "+kind)
        }
        var spinner=findChild(findChild(overview,"t3Count-working"),"t3CountSpinner")
        verify(spinner.animating,"Working counter spinner is stopped")
        overview.overviewActive=false;wait(20)
        verify(!spinner.animating,"Inactive Overview kept the counter animating")
        overview.overviewActive=true
        overview.anchors.fill=null;overview.width=348;overview.height=148;Commons.Style.cornerRadius=0;Commons.Style.reduceMotion=true;wait(80)
        verify(!spinner.animating,"Reduced motion kept the counter animating")
        var heading=findChild(overview,"t3SummaryHeading")
        for(var kind of ["attention","working","finished","failed","other"]) {
          var badge=findChild(overview,"t3Count-"+kind)
          verify(badge.x>=0 && badge.x+badge.width<=heading.width+1,"Counter overflows a narrow heading: "+kind)
        }
        var scroll=findChild(overview,"overviewScroll")
        verify(scroll.height<=overview.height,"Small window does not constrain summary")
        navigation.focusItem(notifications);wait(30)
        var position=notifications.mapToItem(scroll,0,0)
        verify(position.y>=0 && position.y+notifications.height<=scroll.height+1,"Keyboard did not reveal summary navigation")
        verify(scroll.contentItem.contentY>0,"Small summary is not scrollable")
        var originalFontSize=Commons.Style.fontBaseSize
        Commons.Style.fontBaseSize=originalFontSize*1.5;wait(40)
        for(var kind of ["attention","working","finished","failed","other"]) {
          var badge=findChild(overview,"t3Count-"+kind)
          verify(badge.x+badge.width<=heading.width+1 && badge.y+badge.height<=heading.height+1,"Large counters overflow instead of wrapping")
        }
        Commons.Style.fontBaseSize=originalFontSize;wait(30)
        if(Quickshell.env("ISLAND_OVERVIEW_CAPTURE")) {
          overview.anchors.fill=window.contentItem;Commons.Style.cornerRadius=12;scroll.contentItem.contentY=0;wait(80)
          grabImage(window.contentItem).save(Quickshell.env("ISLAND_OVERVIEW_CAPTURE"))
        }
        console.log("OVERVIEW_PASS");Qt.quit()
      }
    }
    Timer {interval:150;running:true;onTriggered:{try {test.test_overview()} catch(e){console.log("OVERVIEW_FAIL",e,e.stack);Qt.quit()}}}
  }
}
