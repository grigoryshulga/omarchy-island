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
    property var latestHerdr:null
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
    property var cache:({providers:[{id:"codex",name:"Codex"}]})
    property var catalog:[]
    property var summary:[{id:"quota",providerId:"codex",name:"Codex",label:"Weekly",remaining:2,stale:true,pendingReset:false,resetsAt:0}]
    property var rows:summary
    function loadCatalog() {}
    function refresh() {}
  }
  FloatingWindow {
    id:window
    color:Island.Design.opaqueCanvas
    visible:true;implicitWidth:560;implicitHeight:660
    Island.IslandContent {id:overview;anchors.fill:parent;anchors.margins:16;service:service;strings:strings;expanded:true;onSettingRequested:(key,value)=>{var settings=Object.assign({},Island.Preferences.values);settings[key]=value;Island.Preferences.values=settings}}
    Island.KeyboardNavigation {id:navigation;scope:overview;containers:[overview]}
    TestCase {
      id:test;when:false
      function test_overview() {
        var finished=[]
        for(var i=0;i<30;i++) finished.push({id:"done-"+i,title:"Completed task "+i,project:"Island",status:"completed",requestId:"",summary:""})
        bridge.rows=finished;wait(80)
        compare(findChild(overview,"overviewScroll").height,overview.height,"Summary clips content above unused window space")
        verify(overview.implicitHeight>0 && overview.implicitHeight<=overview.maximumOverviewHeight,"Summary exceeds its height limit")
        verify(!findChild(overview,"t3Session-done-0").visible,"Completed cards leaked into summary")
        compare(findChild(overview,"t3Count-finished").count,30,"Completed indicator missed tasks")
        verify(!findChild(overview,"t3Count-working").visible,"Zero working count is visible")
        var seek=findChild(overview,"mediaCompactProgress")
        verify(seek.visible && seek.enabled,"Compact player has no seek control")
        compare(findChild(overview,"mediaTitle").y,0,"Media still reserves a source row above the track title")
        compare(seek.trackStyle,"braille")
        verify(findChild(seek,"sliderBrailleProgress").visible,"Media did not use the shared dot track")
        seek.forceActiveFocus();keyClick(Qt.Key_Right);compare(p.position,21,"Braille progress cannot seek")
        verify(findChild(overview,"mediaOpenDetails")===null,"Music still has submenu navigation")
        var braille=findChild(overview,"limitBrailleProgress")
        verify(braille.visible && braille.width>Commons.Style.space(104),"Quota braille field is not full width")
        var notificationsArrow=findChild(overview,"notificationsOpenDetails"),bell=findChild(overview,"overviewDnd")
        verify(notificationsArrow.width>bell.width && bell.x>notificationsArrow.x,"Notification heading must be the navigation target; DND stays separate")
        verify(!findChild(overview,"mediaSeek").visible,"Summary still shows full playback controls")
        verify(findChild(overview,"mediaSectionHeading")===null,"Media still has an outer source heading")
        verify(findChild(overview,"limitRemaining").text.indexOf("·")>=0,"Cached quota lost its marker")
        verify(!findChild(overview,"limitResetCountdown").visible,"Summary invented a reset countdown")
        verify(findChild(overview,"notification-n4")===null,"Summary did not cap notifications")
        var height=overview.pageHeight
        var t3Button=findChild(overview,"t3OpenDetails")
        var limitsButton=findChild(overview,"limitsExpand")
        compare(t3Button.mapToItem(overview,0,0).x,limitsButton.mapToItem(overview,0,0).x,"T3 and limits navigation are not aligned")
        verify(t3Button.title==="T3 Code" && limitsButton.title.length>0 && !t3Button.iconText && !limitsButton.iconText,"Module headings still use navigation arrows")
        notificationsArrow.forceActiveFocus();wait(20)
        var underline=findChild(notificationsArrow,"sectionFocusUnderline")
        verify(underline.visible && underline.height<=Commons.Style.space(2) && underline.width<notificationsArrow.width,"heading focus is not a compact underline")
        var threadAction=findChild(findChild(overview,"t3Session-done-0"),"t3Details")
        verify(threadAction.iconText==="","thread still has a navigation arrow")
        mouseMove(t3Button.parent,t3Button.parent.width/2,t3Button.parent.height/2);wait(20)
        verify(t3Button.hot,"Header whitespace has no hover feedback")
        mouseClick(t3Button.parent,t3Button.parent.width/2,t3Button.parent.height/2);wait(50)
        compare(overview.detailPage,"t3","Header whitespace did not open T3 details")
        verify(!findChild(overview,"islandMediaPlayer").visible,"T3 details did not replace music")
        verify(findChild(overview,"overviewBack").visible,"Detail view has no Back action")
        verify(findChild(overview,"t3Session-done-29").visible,"Full T3 list is incomplete")
        compare(overview.implicitHeight,height,"Full T3 list grew the panel")
        verify(overview.back());wait(50)
        verify(t3Button.activeFocus,"Back did not restore focus")
        var finishedBadge=findChild(overview,"t3Count-finished")
        mouseClick(finishedBadge,finishedBadge.width/2,finishedBadge.height/2);wait(50)
        compare(overview.detailPage,"t3","Header counters did not open T3 details")
        verify(overview.back());wait(50)
        verify(finishedBadge.activeFocus,"Back did not restore counter focus")
        var notifications=findChild(overview,"notificationsOpenDetails")
        notifications.forceActiveFocus();notifications.clicked();wait(50)
        verify(findChild(overview,"notification-n4").visible,"Full notifications are incomplete")
        verify(findChild(overview,"notificationsHistory").visible,"History is missing from notification details")
        compare(overview.implicitHeight,height)
        verify(overview.back());wait(50)
        var limitsSection=findChild(overview,"agentLimitsSection"),standardLimitsHeight=limitsSection.height
        limits.pins=["quota"]
        overview.changeLayout("agentLimits",{size:"compact"},0);wait(50)
        var limitOpen=findChild(limitsSection,"limitOpen")
        verify(!limitsButton.visible && limitOpen.visible,"Compact limits must replace the heading with row navigation")
        verify(limitsSection.height<standardLimitsHeight,"Compact limits retained heading space")
        mouseClick(braille,braille.width/2,braille.height/2);wait(50)
        compare(overview.detailPage,"agentLimits","Clicking the compact gauge did not open limits")
        verify(overview.back());wait(50)
        verify(limitOpen.activeFocus,"Back did not restore the compact limit focus")
        keyClick(Qt.Key_Return);wait(50)
        compare(overview.detailPage,"agentLimits","Compact limit cannot open with the keyboard")
        verify(overview.back());wait(50)
        overview.hovering=true;overview.expanded=false;wait(30)
        verify(limitsSection.visible && !limitOpen.visible && !limitOpen.enabled,"Hover limits must remain read-only")
        overview.expanded=true;overview.hovering=false;wait(30)
        overview.changeLayout("agentLimits",{size:"standard"},0);wait(50)
        verify(limitsButton.visible && !limitOpen.visible,"Standard limits lost heading navigation")
        var manyQuotas=[]
        for(var q=0;q<12;q++) manyQuotas.push(Object.assign({},limits.summary[0],{id:"quota-"+q,label:"Window "+q}))
        limits.rows=manyQuotas
        findChild(overview,"limitsExpand").clicked();wait(50)
        verify(overview.detailPage==="agentLimits" && !findChild(overview,"t3Section").visible,"Limits did not replace summary")
        var limitsContent=findChild(overview,"limitsCenterContent")
        var hostScroll=findChild(overview,"overviewScroll")
        verify(limitsContent.height>Commons.Style.space(300),"Limits list still has an internal height cap")
        verify(!limitsContent.clip,"Limits list must use the host clipping boundary")
        var lastQuota=findChild(limitsContent,"limitDetail-quota-11")
        var lastPin=findChild(lastQuota,"limitPin")
        navigation.focusItem(lastPin);wait(30)
        var lastPosition=lastPin.mapToItem(hostScroll,0,0)
        verify(hostScroll.contentItem.contentY>0,"Quota navigation did not scroll the full host")
        verify(lastPosition.y>=0 && lastPosition.y+lastPin.height<=hostScroll.height+1,"Last quota remains clipped after keyboard navigation")
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
        // Customize through the real host controls; retain module instances and drafts.
        var retainedPlayer=findChild(overview,"islandMediaPlayer")
        var customize=findChild(overview,"notificationsOpenDetails")
        overview.width=window.width-32;overview.height=window.height-32
        customize.forceActiveFocus();overview.configure(customize);wait(30)
        verify(overview.configuring && retainedPlayer.visible && !retainedPlayer.enabled,"Editor must retain read-only live module previews")
        verify(findChild(overview,"overviewVisible-battery").visible,"Unavailable module cannot be restored")
        verify(!findChild(overview,"overviewUp-notifications"),"Editor retained reorder arrow buttons")
        var settingsButton=findChild(overview,"overviewSettings")
        verify(settingsButton.visible && settingsButton.focusable,"Customization has no accessible Settings action")
        var editorScroll=findChild(overview,"overviewScroll")
        editorScroll.contentItem.contentY=0;wait(20)
        var editorY=editorScroll.contentItem.contentY
        settingsButton.forceActiveFocus();keyClick(Qt.Key_Return);wait(40)
        var settingsView=findChild(overview,"customizationSettings")
        verify(overview.settingsOpen && settingsView.visible && !editorScroll.visible,"Settings did not replace the customization previews")
        verify(overview.navigationHidden,"Settings retained outer navigation")
        compare(overview.implicitHeight,height,"Settings changed the popup height")
        verify(findChild(settingsView,"settingsTab-general").activeFocus,"Settings did not focus its first category")
        for(var category of ["general","panel","alerts","modules"]) verify(findChild(settingsView,"settingsTab-"+category).visible,"Missing settings category: "+category)
        findChild(settingsView,"setting-hoverPreview").toggled();wait(20)
        compare(Island.Preferences.get("hoverPreview"),false,"Settings did not forward changes to the host")
        findChild(overview,"customizationSettingsBack").clicked();wait(30)
        verify(overview.configuring && !overview.settingsOpen && settingsButton.activeFocus,"Settings Back did not restore customization focus")
        compare(editorScroll.contentItem.contentY,editorY,"Settings Back lost customization scroll")
        settingsButton.clicked();wait(30)
        verify(overview.back());wait(30)
        verify(overview.configuring && settingsButton.activeFocus,"Escape route skipped customization")
        editorScroll.contentItem.contentY=0;wait(20)
        if(Quickshell.env("ISLAND_EDITOR_CAPTURE")) {
          overview.grabToImage(function(result){result.saveToFile(Quickshell.env("ISLAND_EDITOR_CAPTURE"))});wait(60)
        }
        var hideMedia=findChild(overview,"overviewVisible-media")
        verify(hideMedia.text==="" && hideMedia.iconText!=="","Visibility still uses a text button")
        var sizeEditor=findChild(overview,"overviewSize-media")
        compare(sizeEditor.mapToItem(hideMedia.parent,0,sizeEditor.height/2).y,hideMedia.y+hideMedia.height/2,"Size and visibility are not in the same row")
        hideMedia.clicked();wait(30)
        compare(Island.Preferences.get("overviewLayout").find(function(row){return row.id==="media"}).visible,false)
        scroll.contentItem.contentY=0;wait(30)
        var dragArea=findChild(overview,"overviewModuleDrag-battery"),dropHandle=findChild(overview,"overviewDrag-controls")
        var drag=findChild(overview,"overviewDragController"),marker=findChild(overview,"overviewDropMarker")
        var originalOrder=JSON.stringify(Island.Preferences.get("overviewLayout"))
        var dropPoint=dropHandle.mapToItem(scroll,dropHandle.width/2,dropHandle.height/2)
        mousePress(dragArea,dragArea.width/2,dragArea.height/2)
        mouseMove(scroll,dropPoint.x,dropPoint.y,30);wait(30)
        verify(drag.dragging && marker.visible && marker.color.toString()===Island.Design.accent.toString(),"Dragging has no accent insertion marker")
        compare(JSON.stringify(Island.Preferences.get("overviewLayout")),originalOrder,"Reordering saved before drop")
        mouseRelease(scroll,dropPoint.x,dropPoint.y);wait(50)
        compare(Island.Preferences.get("overviewLayout")[0].id,"battery","Dragging the module preview did not reorder it")
        verify(!marker.visible,"Insertion marker remained after drop")
        var canceledOrder=JSON.stringify(Island.Preferences.get("overviewLayout"))
        mousePress(dragArea,dragArea.width/2,dragArea.height/2)
        mouseMove(dragArea,dragArea.width/2,dragArea.height/2+40,30);wait(20)
        verify(drag.dragging,"Preview drag did not restart")
        verify(overview.back() && overview.configuring && !drag.dragging,"Escape did not cancel drag before leaving the editor")
        mouseMove(scroll,dropPoint.x,dropPoint.y+20,30)
        verify(!drag.dragging,"Pointer movement restarted a canceled drag")
        mouseRelease(scroll,dropPoint.x,dropPoint.y);wait(30)
        compare(JSON.stringify(Island.Preferences.get("overviewLayout")),canceledOrder,"Canceled drag changed the layout")
        scroll.contentItem.contentY=0;wait(30)
        mousePress(dragArea,dragArea.width/2,dragArea.height/2)
        mouseMove(scroll,scroll.width/2,scroll.height-2,30);wait(160)
        verify(scroll.contentItem.contentY>0,"Dragging at the viewport edge does not auto-scroll")
        overview.back();mouseRelease(scroll,scroll.width/2,scroll.height-2);wait(30)
        compare(JSON.stringify(Island.Preferences.get("overviewLayout")),canceledOrder,"Canceled edge drag changed the layout")
        var keyboardDrag=findChild(overview,"overviewDrag-notifications")
        var notificationPosition=Island.Preferences.get("overviewLayout").findIndex(function(row){return row.id==="notifications"})
        navigation.focusItem(keyboardDrag);keyClick(Qt.Key_Up,Qt.ControlModifier);wait(30)
        verify(keyboardDrag.activeFocus && keyboardDrag.activeFocusOnTab,"Module heading lost keyboard focus after reordering")
        compare(Commons.Border.left(keyboardDrag.borderSpec),0,"Module heading has a duplicate focus border")
        var focusedFrame=keyboardDrag.parent
        while(focusedFrame && !("entryKey" in focusedFrame)) focusedFrame=focusedFrame.parent
        verify(focusedFrame && focusedFrame.border.width>0,"Focused module lost its outer focus border")
        compare(Island.Preferences.get("overviewLayout")[notificationPosition-1].id,"notifications")
        var mediaSize=findChild(overview,"overviewSize-media")
        mediaSize.changed("large");wait(30)
        verify(overview.back());wait(30)
        verify(customize.activeFocus,"Customize did not restore focus")
        verify(!retainedPlayer.visible,"Hidden module remains visible")
        compare(findChild(overview,"islandMediaPlayer"),retainedPlayer,"Reordering recreated the module view")
        overview.expanded=false;overview.alertKind="media";wait(30)
        verify(retainedPlayer.visible,"Hidden Overview block suppressed the media toast")
        service.latestHerdr={title:"Remote agent",source:"Build / default",pane:"w1:p1",status:"blocked"}
        overview.alertKind="herdr";wait(30)
        verify(findChild(overview,"herdrActivityToast").visible,"Herdr activity toast is hidden")
        compare(overview.toastIcon,findChild(overview,"herdrActivityToast").statusIcon,"Herdr toast waves lost their status origin")
        verify(!retainedPlayer.visible,"Media leaked into the Herdr toast")
        service.latestHerdr=null;wait(30)
        verify(!findChild(overview,"herdrActivityToast").visible,"Cleared Herdr activity toast remains visible")
        overview.expanded=true;overview.alertKind="";wait(30)
        overview.configure(customize);wait(30)
        findChild(overview,"overviewVisible-media").clicked();wait(30)
        overview.back();wait(30)
        verify(retainedPlayer.visible)
        verify(findChild(overview,"mediaSeek").visible,"Large media did not expose full controls")
        compare(retainedPlayer.y,0,"Large media still reserves a source heading above the player")
        for(var mediaSizeVariant of ["minimal","compact","standard","large"]) {
          overview.changeLayout("media",{size:mediaSizeVariant},0);wait(30)
          compare(retainedPlayer.y,0,"Media reserves source heading space in "+mediaSizeVariant)
          compare(findChild(overview,"mediaTitle").y,0,"Media reserves a source caption in "+mediaSizeVariant)
        }
        overview.hovering=false;overview.expanded=false;overview.alertKind="media";wait(30)
        verify(retainedPlayer.visible,"Layout preferences suppressed the media toast")
        overview.expanded=true;overview.alertKind=""
        for(var variant of ["minimal","compact","standard","large"]) {
          overview.changeLayout("notifications",{size:variant},0);wait(30)
          var notificationContent=findChild(overview,"notificationContent")
          compare(notificationContent.notificationLimit,({minimal:0,compact:1,standard:3,large:6})[variant])
          compare(findChild(overview,"notificationsScroll").visible,variant!=="minimal")
        }
        Island.Preferences.values={};wait(30)
        var savedNotifications=service.allEntries
        service.allEntries=[];wait(30)
        verify(!findChild(overview,"notificationContent").visible,"Empty notification block remains in summary")
        verify(findChild(overview,"overviewHeader").visible,"Empty notifications hid date/weather")
        service.allEntries=savedNotifications;wait(30)
        verify(findChild(overview,"notificationsOpenDetails").visible,"New notifications did not restore the heading")
        var originalFontSize=Commons.Style.fontBaseSize
        Commons.Style.fontBaseSize=originalFontSize*1.5;wait(40)
        for(var kind of ["attention","working","finished","failed","other"]) {
          var badge=findChild(overview,"t3Count-"+kind)
          verify(badge.x+badge.width<=heading.width+1 && badge.y+badge.height<=heading.height+1,"Large counters overflow instead of wrapping")
        }
        Commons.Style.fontBaseSize=originalFontSize;wait(30)
        overview.height=148;wait(30)
        var bottomMargin=overview.anchors.bottomMargin
        overview.anchors.bottomMargin=200;wait(30)
        compare(scroll.height,overview.height,"Small popup exceeds its allocated height")
        verify(!findChild(overview,"overviewScrollBar").visible,"Overflow shows a scrollbar")
        var beforeScroll=scroll.contentItem.contentY
        mouseWheel(scroll,scroll.width/2,scroll.height/2,0,-120);wait(80)
        verify(scroll.contentItem.contentY>beforeScroll,"Hidden scrollbar disabled wheel scrolling")
        overview.anchors.bottomMargin=bottomMargin;wait(30)
        overview.anchors.fill=null
        overview.height=Qt.binding(function(){return overview.implicitHeight})
        Island.Preferences.values={overviewLayout:overview.moduleDefinitions.map(function(entry){return {id:entry.id,visible:false,size:"standard"}})};wait(40)
        var emptyHeight=overview.implicitHeight
        compare(emptyHeight,findChild(overview,"overviewHeader").height,"Empty summary retains a minimum height")
        Island.Preferences.values={};wait(40)
        verify(overview.height>emptyHeight && overview.height<=overview.maximumOverviewHeight,"Summary does not grow with its content")
        overview.maximumOverviewHeight=120;wait(40)
        compare(overview.height,120,"Summary does not respect a small screen height limit")
        verify(scroll.contentItem.contentHeight>scroll.height,"Capped summary has no scrollable overflow")
        overview.maximumOverviewHeight=Commons.Style.space(640);wait(30)
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
