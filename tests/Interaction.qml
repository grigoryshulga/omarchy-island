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
    readonly property var modules:({weather:("weather" in service) ? service.weather : null,calendar:{allowed:true,calendars:("calendars" in service) ? service.calendars : null,reminders:("reminders" in service) ? service.reminders : null},notifications:service,media:service,t3:t3})
    property var t3: ({allowed:false,connected:false,canRespond:false,responsesEnabled:false,rows:[]})
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
  FloatingWindow {
    id: win
    visible: true
    implicitWidth: 600; implicitHeight: 900
    ColumnLayout {
      anchors.fill: parent
      Island.MediaCard { id: media; Layout.fillWidth: true; service: service; strings: strings; expanded: true }
      Island.NotificationCard {
        id: card
        Layout.fillWidth: true
        service: service; strings: strings; expanded: true
        row: ({key:"test",app:"Test",source:"Test",summary:"A code",body:"<img src='https://example.com/pixel'>482913",codes:"482913",execActions:"",link:"",ts:1})
      }
      Island.IslandContent { id: composed; width: 480; Layout.fillWidth: true; service: service; strings: strings; hovering: true }
      Item { Layout.fillHeight: true }
    }
  }
  FloatingWindow {
    id: calendarWin
    visible: false
    implicitWidth: 450; implicitHeight: calendarSurface.testPages ? pages.implicitHeight+24 : 440
    color: Commons.Color.popups.background
    Item {
      id: calendarSurface
      anchors.fill: parent
      Rectangle { anchors.fill: parent; color: Commons.Color.popups.background }
      property bool testPages: false
      property bool dismissed:false
      Island.CalendarView { id: calendar; visible: !calendarSurface.testPages; x: 12; y: 12; width: parent.width-24; strings: strings; onWeekStartRequested: value => weekStart=value }
      Island.PopupPages {
        id: pages
        x: 12; y: 12; width: parent.width-24; height: implicitHeight
        visible: calendarSurface.testPages
        service: service; strings: strings; expanded: true; hovering: true
        onDismissRequested:calendarSurface.dismissed=true
        onPageRequested:index=>pages.selectedPage=index
        onSettingRequested: (key,value) => {
          var next=Object.assign({},pages.settings);next[key]=value;pages.settings=next
          if(key==="weatherTemperatureUnit") fakeWeather.temperatureUnit=value
        }
      }
    }
  }
  TestCase {
    id: test
    name: "IslandInteraction"
    when: false
    function check(ok,message) { if (!ok) { console.log("ISLAND_FAIL:",message); throw new Error(message) } }
    function test_barWidgetLoads() {
      var component=Qt.createComponent("Island/BarWidget.qml")
      // Offscreen has no PanelWindow backend, but parsing must still succeed.
      var error=component.errorString()
      check(component.status===Component.Ready || (error.indexOf("No PanelWindow backend loaded.")>=0 && error.indexOf("Unexpected token")<0),error)
    }
    function test_controls() {
      wait(200)
      var toggle=findChild(media,"mediaToggle")
      check(toggle !== null,"missing toggle")
      check(findChild(media,"mediaTitle").font.pixelSize===Island.Design.type.section,"track title did not use its larger size")
      mouseClick(toggle)
      check(service.mediaCalls===1,"toggle click did not reach player: "+service.mediaCalls)
      check(Spotlight.pick(media,media,Qt.point(media.width/2,1))===media,"media card does not contain the spotlight")
      check(media.color===Island.Design.surface && media.radius===Island.Design.cardRadius,"media controls are not in a themed card")
      var musicGlow=findChild(media,"mediaSpotlight")
      if(!Commons.Style.reduceMotion) check(musicGlow.rippling,"play button did not start a music ripple")
      check(p.isPlaying,"player did not play")
      var seek=findChild(media,"mediaSeek")
      check(seek.trackStyle==="braille" && findChild(seek,"sliderBrailleProgress").visible,"expanded media does not use the standard progress track")
      var elapsed=findChild(media,"mediaElapsed"),duration=findChild(media,"mediaDuration")
      check(elapsed.parent===seek.parent && duration.parent===seek.parent,"track times are not on the progress row")
      check(elapsed.x+elapsed.width<=seek.x && duration.x>=seek.x+seek.width,"track times do not bracket the progress bar")
      check(Math.abs(elapsed.y+elapsed.height/2-seek.y-seek.height/2)<1 && Math.abs(duration.y+duration.height/2-seek.y-seek.height/2)<1,"track times are not vertically aligned with progress")
      mouseClick(seek,seek.width*0.7,seek.height/2)
      check(p.position>100 && p.position<150,"seek="+p.position)
      p.trackArtUrl=Qt.resolvedUrl("Island/assets/dot-field.svg")
      var popover=findChild(media,"mediaVolumePopover")
      check(!popover.visible,"volume is not hidden by default")
      var volumeTrigger=findChild(media,"mediaVolumeTrigger")
      var mediaHeight=media.height
      mouseMove(volumeTrigger)
      wait(220)
      check(popover.visible && popover.opacity>0.9,"hover did not open volume")
      check(musicGlow.artworkMix>0.9,"music spotlight did not load cover colors")
      check(Math.abs(media.height-mediaHeight)<1,"volume hover changed player height")
      var volume=findChild(media,"mediaVolume")
      mouseMove(volume,volume.width/2,volume.height/2)
      wait(200)
      check(popover.visible,"volume closed while moving to slider")
      mouseClick(volume,volume.width*0.25,volume.height/2)
      check(p.volume>0.15 && p.volume<0.35,"volume="+p.volume)
      var face=findChild(toggle,"playPauseFace")
      wait(40)
      var systemRadius=Commons.Style.cornerRadius
      Commons.Style.cornerRadius=0
      wait(60)
      var pixels=face.getContext("2d"), ratio=win.devicePixelRatio
      check(pixels.getImageData(face.width*0.37*ratio,face.height*0.5*ratio,1,1).data[3]===0,"pause bars are not transparent")
      check(pixels.getImageData(2,2,1,1).data[3]>0,"play/pause face is not filled")
      check(toggle.radius===0 && findChild(seek,"sliderKnob").radius===0,"zero system rounding did not apply")
      Commons.Style.cornerRadius=12
      wait(60)
      check(toggle.rounded && toggle.radius===toggle.width/2,"rounded system did not make play/pause circular")
      check(pixels.getImageData(2,2,1,1).data[3]===0,"circular play/pause still has filled corners")
      check(findChild(seek,"sliderKnob").radius>0,"slider did not pick up system rounding")
      Commons.Style.cornerRadius=systemRadius
      var stableCardHeight=card.implicitHeight
      mouseMove(card,card.width/2,card.height/2)
      wait(400)
      check(Math.abs(card.implicitHeight-stableCardHeight)<1,"notification changed height on hover")
      check(!popover.visible,"volume did not close after hover")
      var copy=findChild(card,"copyCode-482913")
      mouseClick(copy)
      check(service.copied==="482913","copy="+service.copied)
      if(!Commons.Style.reduceMotion) check(findChild(card,"notificationSpotlight").rippling,"notification action did not start a ripple")
      check(service.activateCalls===0,"child click opened app")
      var mute=findChild(card,"muteSource")
      mouseClick(mute)
      check(service.muted==="Test","mute="+service.muted)
      check(service.activateCalls===0,"child click opened app")
      var component=Qt.createComponent("Island/Service.qml")
      check(component.status===Component.Ready,component.errorString())
      check(composed.implicitHeight > 0,"composed UI has no height")
      var group=findChild(composed,"notificationGroup-Test")
      mouseMove(group,group.width/2,10)
      wait(180)
      var groupMute=findChild(group,"groupMute")
      check(groupMute !== null && groupMute.opacity>0.9,"group mute does not appear on hover")
      mouseClick(groupMute)
      check(service.muted==="Test","group mute did not target source")
      if(!Commons.Style.reduceMotion) check(findChild(group,"groupSpotlight").rippling,"source mute did not start a group ripple")
      check(findChild(group,"muteSource").visible===false,"duplicate per-notification mute")
      var first = findChild(composed,"notification-n1")
      check(first !== null,"first grouped notification missing")
      check(group.border.width===0,"group retained a permanent outline")
      check(Spotlight.pick(group,first,Qt.point(first.width/2,2))===group,"transparent notification row split the group spotlight")
      check(Spotlight.pick(group,groupMute,Qt.point(groupMute.width/2,groupMute.height/2))===groupMute,"nested action lost its spotlight")
      check(groupMute.background.a===0 && !groupMute.bordered,"nested action retained an idle container")
      composed.expanded = true
      wait(20)
      check(first === findChild(composed,"notification-n1"),"expansion rebuilt notification delegates")
      wait(220)
      findChild(composed,"notificationsOpenDetails").clicked();wait(30)
      var activeTab=findChild(composed,"notificationsActive"),clearButton=findChild(composed,"notificationsClear"),dndButton=findChild(composed,"notificationsDnd")
      check(clearButton.parent===activeTab.parent && dndButton.parent===activeTab.parent,"notification controls are not in the tabs row")
      check(clearButton.x<dndButton.x,"Clear all must precede the bell")
      var stableGroupHeight=group.implicitHeight
      mouseMove(first,first.width/2,first.height/2)
      wait(220)
      check(Math.abs(group.implicitHeight-stableGroupHeight)<1,"grouped notifications changed height on hover")
      check(findChild(findChild(composed,"notification-n2"),"notificationDivider")===null,"Grouped notifications must use spacing, not a divider")
      check(findChild(first,"notificationTime").mapToItem(first,0,0).y<first.height/2,"message timestamp is not at the top")
      check(findChild(group,"groupSpotlight").shown>0.9,"group spotlight did not fade in")
      mouseClick(first,first.width*0.4,first.height*0.25)
      check(service.activateCalls===1,"notification click did not open app")
      if(!Commons.Style.reduceMotion) check(findChild(group,"groupSpotlight").rippling,"notification click did not reach the group ripple")
      var expandedHeight=composed.implicitHeight
      service.latest=service.allEntries[0]
      composed.expanded=false;composed.hovering=false;composed.alertKind="notification"
      wait(80)
      var toast=findChild(composed,"notificationGroup-Test")
      check(toast.compact && toast.color.a===0 && toast.border.width===0,"toast retained a card background")
      check(composed.implicitHeight<expandedHeight,"toast did not compact the notification")
      composed.hovering=true;composed.alertKind=""
      wait(20)
      var panelPlayer=findChild(composed,"islandMediaPlayer")
      var separator=findChild(composed,"islandMediaSeparator")
      p.isPlaying=false; p.playbackState=MprisPlaybackState.Paused
      wait(20)
      check(panelPlayer.visible,"paused track disappeared")
      p.playbackState=MprisPlaybackState.Stopped
      wait(20)
      check(!panelPlayer.visible && separator===null,"stopped player left an empty section")
      p.playbackState=MprisPlaybackState.Playing; p.isPlaying=true
      wait(20)
      check(panelPlayer.visible,"playing track did not return")
      p.trackTitle=""; p.trackArtist=""
      wait(20)
      check(!panelPlayer.visible,"player without a track is visible")
      service.player=null
      wait(20)
      check(!panelPlayer.visible,"disconnected player is visible")
      group=findChild(composed,"notificationGroup-Test")
      mouseMove(group,group.width/2,10)
      wait(160)
      var groupDismiss=findChild(group,"groupDismiss"), groupBell=findChild(group,"groupMute")
      check(groupDismiss.x>groupBell.x && groupDismiss.opacity>0.9,"group close is not to the right of mute")
      mouseClick(groupDismiss)
      check(service.removed.length===4 && service.allEntries.length===0,"group close did not dismiss all source notifications")
      service.allEntries=[{key:"single",app:"Test",summary:"Screenshot saved and copied",body:"583 × 684 · 56.7 kB",ts:1}]
      wait(40)
      var single=findChild(composed,"notificationGroup-Test"),singleHeight=single.implicitHeight
      mouseMove(win.contentItem,1,1);wait(180)
      var singleStamp=findChild(single,"groupTime"),idleStampX=singleStamp.mapToItem(single,0,0).x
      check(idleStampX+singleStamp.width>=single.width-Island.Design.cardPadding-1,"timestamp does not reach the top-right corner at rest")
      check(findChild(single,"groupTime").visible,"single notification timestamp is not in its source header")
      check(!findChild(single,"notificationFooter").visible,"single notification reserves an empty footer")
      check(singleHeight<=Commons.Style.space(112),"single notification is still too tall: "+singleHeight)
      mouseMove(single,single.width/2,single.height/2);wait(160)
      check(single.implicitHeight===singleHeight,"compact single notification changes height on hover")
      check(singleStamp.mapToItem(single,0,0).x<idleStampX-Commons.Style.space(15),"timestamp did not make room for hover actions")
      console.log("COMPACT_SINGLE_NOTIFICATION_PASS",singleHeight)
      composed.expanded=true;composed.hovering=true
      service.allEntries=[{key:"new",app:"Test",summary:"Chat",body:"second",ts:3,codes:"222222"},{key:"different",app:"Test",summary:"Other chat",body:"other",ts:2},{key:"old",app:"Test",summary:"Chat",body:"first",ts:1,codes:"111111"}]
      service.actionRows=["new","old"]
      wait(40)
      var merged=findChild(composed,"notification-new")
      check(merged!==null && merged.members.length===2,"same header did not merge")
      check(findChild(composed,"notification-old")===null,"repeated header still has its own card")
      check(findChild(merged,"notificationBody").text==="first\nsecond","merged bodies are missing or out of order")
      check(merged.senderActions.length===1,"identical actions were duplicated")
      check(findChild(merged,"copyCode-111111")!==null && findChild(merged,"copyCode-222222")!==null,"merging lost a verification code")
      composed.expanded=false;wait(30)
      group=findChild(composed,"notificationGroup-Test");group.limit=1;wait(30)
      check(findChild(findChild(composed,"notification-new"),"notificationBody").text==="second","merged preview exceeded its message budget")
      group.limit=Qt.binding(function(){return composed.expanded ? 100 : composed.hovering ? 3 : 1})
      composed.expanded=true;wait(30)
      service.allEntries=service.allEntries.filter(function(row){return row.key!=="old"});wait(30)
      check(findChild(findChild(composed,"notification-new"),"notificationBody").text==="second","recalled message remained in merged body")
      service.allEntries=service.allEntries.concat([{key:"old",app:"Test",summary:"Chat",body:"first",ts:1}]);wait(30)
      merged=findChild(composed,"notification-new")
      findChild(merged,"notificationAction-read").clicked();wait(30)
      check(service.invokedRows.length===2 && service.allEntries.length===1 && service.allEntries[0].key==="different","merged action did not target exactly its original messages")
      service.allEntries=[{key:"new",app:"Test",summary:"Chat",body:"second",ts:3},{key:"different",app:"Test",summary:"Other chat",body:"other",ts:2},{key:"old",app:"Test",summary:"Chat",body:"first",ts:1}];wait(30)
      findChild(findChild(composed,"notification-new"),"notificationDismiss").clicked();wait(30)
      check(service.allEntries.length===1 && service.allEntries[0].key==="different","merged dismiss removed another header or left a member behind")
      service.allEntries=[{key:"shot-new",app:"Test",summary:"Screenshot saved",body:"new.png",ts:3,execActions:JSON.stringify([{label:"Open",argv:["xdg-open","/tmp/new.png"]},{label:"Edit",argv:["editor","/tmp/new.png"]}])},{key:"shot-old",app:"Test",summary:"Screenshot saved",body:"old.png",ts:1,execActions:JSON.stringify([{label:"Open",argv:["xdg-open","/tmp/old.png"]},{label:"Edit",argv:["editor","/tmp/old.png"]}])}];wait(30)
      var screenshot=findChild(composed,"notification-shot-new")
      check(screenshot.execActions.length===2,"merged screenshots repeated Open/Edit buttons: "+screenshot.execActions.length)
      check(screenshot.execActions[0].row.key==="shot-new" && screenshot.execActions[1].row.key==="shot-new","screenshot actions target an older file")
      findChild(screenshot,"notificationExecAction-0").clicked()
      check(service.executedRow==="shot-new:0","Open did not target the latest screenshot")
      findChild(screenshot,"notificationExecAction-1").clicked()
      check(service.executedRow==="shot-new:1","Edit did not target the latest screenshot")
      service.actionRows=[]
      console.log("MERGED_NOTIFICATIONS_PASS")
      service.allEntries=[]
      composed.expanded=false;composed.hovering=true
      wait(20)
      check(!findChild(composed,"notificationCount").visible,"zero notification count is visible")
      check(!findChild(composed,"notificationsEmpty").visible,"empty state appeared in hover preview")
      check(!findChild(composed,"notificationsScroll").visible,"empty notifications left a scroll area in hover preview")
      if (!findChild(composed,"islandBatteryOverview").present)
        check(composed.implicitHeight===0,"empty hover preview retained blank space")
      composed.expanded=true
      service.historyEntries=[{key:"old",app:"Archive",summary:"Old notification",body:"old",ts:1}]
      wait(30)
      check(findChild(composed,"notificationContent").rows.length===0,"history leaked into active notifications")
      check(findChild(composed,"notificationsEmpty").visible,"empty notifications did not show clapping hands")
      findChild(composed,"notificationsOpenDetails").clicked();wait(30)
      mouseClick(findChild(composed,"notificationsHistory"));wait(30)
      check(findChild(composed,"notificationContent").historyOpen && findChild(composed,"notificationContent").rows.length===1,"history toggle did not reveal archived notifications")
      check(findChild(composed,"notification-old")!==null,"archived notification did not render")
      check(!findChild(composed,"notificationsEmpty").visible,"clapping hands remained above archived notifications")
      service.allEntries=[{key:"unread",app:"Current",summary:"Unread",body:"",ts:2}]
      mouseClick(findChild(composed,"notificationsClear"));wait(30)
      check(service.allEntries.length===1,"history clear removed active notifications")
      check(findChild(composed,"notificationContent").rows.length===0,"history did not clear")
      check(findChild(composed,"notificationsEmpty").visible,"empty history did not show clapping hands")
      composed.expanded=false;composed.hovering=true;wait(30)
      check(!findChild(composed,"notificationContent").historyOpen && findChild(composed,"notificationContent").rows.length===1 && findChild(composed,"notificationContent").rows[0].key==="unread","hover preview retained the history view")
      check(!findChild(composed,"notificationsEmpty").visible,"clapping hands remained above active notifications")
      console.log("NOTIFICATION_HISTORY_UI_PASS")
      calendarWin.visible=true
      calendar.today=new Date(2024,1,29,12)
      calendar.showToday()
      wait(40)
      check(calendar.viewYear===2024 && calendar.viewMonth===1,"calendar did not open current month")
      var calendarHeight=calendar.implicitHeight
      mouseClick(findChild(calendar,"calendarNext"))
      check(calendar.viewMonth===2,"next month button failed")
      wait(40)
      mouseClick(findChild(calendar,"calendarPrevious"))
      check(calendar.viewMonth===1,"previous month button failed")
      wait(40)
      mouseClick(findChild(calendar,"calendar-day-2024-02-29"))
      check(calendar.selectedDay.key==="2024-02-29","date selection failed: "+calendar.selectedDay.key)
      wait(100)
      check(findChild(calendar,"calendarSpotlight").rippleProgress<0.15,"click wave did not slow down")
      var glow=findChild(calendar,"calendarSpotlight")
      if(!Commons.Style.reduceMotion) check(glow.rippling,"calendar click did not start a wave")
      calendar.radialBraille=false
      check(glow.profile===0,"experimental spotlight cannot be reverted")
      calendar.radialBraille=true
      wait(580)
      check(!glow.rippling,"calendar wave did not finish")
      calendar.shiftMonth(-2)
      check(calendar.viewYear===2023 && calendar.viewMonth===11,"calendar year rollover failed")
      mouseClick(findChild(calendar,"calendarCurrentDate"))
      check(calendar.viewYear===2024 && calendar.viewMonth===1 && calendar.selectedDay.key===calendar.todayKey,"current date did not return to today")
      check(findChild(calendar,"calendarToday")===null,"redundant Today button remains")
      var today=findChild(calendar,"calendar-day-2024-02-29")
      wait(150)
      check(today.color===Island.Design.accent && today.foreground===Island.Design.onAccent,"today does not use accent fill with inverse text")
      check(findChild(today,"calendarTodayGlow").active,"today has no braille glow")
      check(findChild(calendar,"calendarMonth").fontSize<findChild(calendar,"calendarCurrentDate").fontSize,"calendar typography hierarchy is reversed")
      check(findChild(calendar,"calendarPrevious").y>=0 && findChild(calendar,"calendarMonth").mapToItem(calendar,0,0).y>today.mapToItem(calendar,0,0).y,"month navigation is not below the grid")
      mouseClick(findChild(calendar,"calendarSettings"));wait(180)
      check(findChild(calendar,"calendarSettingsMenu").opened,"calendar gear did not open settings")
      var sunday=findChild(findChild(calendar,"calendarSettingsMenu").contentItem,"calendarWeekStart-sunday")
      mouseClick(sunday);wait(120)
      check(calendar.firstDay===0 && calendar.cells[0].key==="2024-01-28","Sunday preference did not update calendar")
      check(calendar.weekNumbers.length===6 && calendar.weekNumbers[0]===5 && calendar.weekNumbers[5]===10,"ISO week numbers are incorrect")
      mouseClick(findChild(calendar,"calendarSettings"));wait(180)
      mouseClick(findChild(findChild(calendar,"calendarSettingsMenu").contentItem,"calendarWeekStart-monday"));wait(120)
      check(calendar.firstDay===1 && calendar.cells[0].key==="2024-01-29","Monday preference did not update calendar")
      check(calendar.implicitHeight===calendarHeight,"calendar height changed between months")
      console.log("CALENDAR_LAYOUT_PASS")
      mouseMove(calendarSurface,1,1)
      calendar.forceActiveFocus()
      wait(150)
      calendarSurface.testPages=true
      service.player=p; p.trackTitle="Test track"; p.playbackState=MprisPlaybackState.Playing; p.isPlaying=true
      wait(100)
      var pager=findChild(pages,"islandPageSwipe")
      mouseDrag(pager,pager.width*0.8,pager.height*0.85,-pager.width*0.65,0,Qt.LeftButton)
      tryVerify(function(){return pages.calendar && Math.abs(findChild(pages,"islandCalendar").mapToItem(pager,0,0).x)<1},1200)
      check(pages.calendar,"horizontal swipe did not open calendar")
      check(Math.abs(findChild(pages,"islandCalendar").mapToItem(pager,0,0).x)<1,"calendar content did not move into view after swipe")
      mouseWheel(pager,pager.width/2,pager.height/2,120,0,Qt.NoButton)
      wait(350)
      check(!pages.calendar,"horizontal wheel did not return to inbox")
      check(Math.abs(findChild(pages,"islandMediaPlayer").mapToItem(pager,0,0).x)<1,"inbox content did not move into view after wheel")
      mouseWheel(pager,pager.width/2,pager.height*0.85,0,-120,Qt.NoButton)
      wait(350)
      check(!pages.calendar,"vertical scrolling switched popup pages")
      check(Math.abs(findChild(pages,"islandMediaPlayer").mapToItem(pager,0,0).x)<1,"vertical wheel moved page contents")
      mouseWheel(pager,pager.width/2,pager.height/2,0,-120,Qt.NoButton,Qt.ShiftModifier)
      wait(350)
      check(pages.calendar,"Shift+wheel did not open calendar")
      check(Math.abs(findChild(pages,"islandCalendar").mapToItem(pager,0,0).x)<1,"calendar content did not move into view after wheel")
      mouseDrag(pager,pager.width*0.8,pager.height*0.85,-pager.width*0.65,0,Qt.LeftButton)
      tryVerify(function(){return pages.weather && Math.abs(findChild(pages,"islandWeather").mapToItem(pager,0,0).x)<1},1200)
      check(pages.weather && !pages.calendar,"horizontal swipe did not open weather")
      check(Math.abs(findChild(pages,"islandWeather").mapToItem(pager,0,0).x)<1,"weather content did not move into view after swipe")
      var weatherView=findChild(pages,"islandWeather")
      var overviewButton=findChild(pages,"islandTabOverview"),calendarButton=findChild(pages,"calendarOpen"),weatherButton=findChild(pages,"weatherOpen")
      check(Math.abs(overviewButton.width-calendarButton.width)<=1 && Math.abs(calendarButton.width-weatherButton.width)<=1,"popup tabs have different column widths")
      check(findChild(weatherView,"weatherForecast").count===7,"weather does not show seven future days")
      var unit=findChild(weatherView,"weatherUnit"),temperature=findChild(weatherView,"weatherTemperature")
      check(unit.text==="°C" && temperature.text==="7","initial Celsius temperature is incorrect")
      mouseClick(unit);wait(450)
      check(unit.text==="°C","single click changed the temperature unit")
      mouseDoubleClickSequence(unit);wait(120)
      check(unit.text==="°F" && temperature.text==="45" && pages.settings.weatherTemperatureUnit==="fahrenheit","double click did not select Fahrenheit")
      check(findChild(findChild(weatherView,"weatherDay-0"),"weatherDayHigh").text==="43°","forecast did not convert to Fahrenheit")
      wait(400);mouseDoubleClickSequence(unit);wait(120)
      check(unit.text==="K" && temperature.text==="280","double click did not select Kelvin")
      check(findChild(weatherView,"weatherStat-0").text==="278 K" && findChild(findChild(weatherView,"weatherDay-0"),"weatherDayHigh").text==="279 K","Kelvin was not applied to feels-like and forecast")
      check(findChild(findChild(pages,"weatherOpen"),"weatherChipTemperature").text==="280 K","weather tab did not use the selected unit")
      check(!fakeWeather.useImperial,"temperature cycling changed wind units")
      wait(400);mouseDoubleClickSequence(unit);wait(120)
      check(unit.text==="°C" && temperature.text==="7","temperature unit cycle did not return to Celsius")
      console.log("WEATHER_UNITS_PASS")
      var firstDay=findChild(weatherView,"weatherDay-0"),lastDay=findChild(weatherView,"weatherDay-6")
      check(firstDay && lastDay && Math.abs(firstDay.width-lastDay.width)<=1 && lastDay.x+lastDay.width<=weatherView.width+1,"seven-day columns overflow or have unequal widths")
      check(findChild(weatherView,"weatherHeroScene").condition===5,"weather did not select rain scene")
      check(findChild(weatherView,"weatherTemperature").text.indexOf("7")>=0,"weather temperature missing")
      mouseClick(findChild(weatherView,"weatherLocation"))
      var cityInput=findChild(weatherView,"weatherCityInput")
      check(!findChild(weatherView,"weatherLocation").visible && cityInput.visible,"search did not replace the city row")
      cityInput.text="Paris"
      wait(350)
      check(fakeWeather.searched==="Paris","weather city search did not run")
      mouseClick(findChild(weatherView,"weatherHeroScene"),20,20)
      check(!weatherView.editing && findChild(weatherView,"weatherLocation").visible && cityInput.text==="" && fakeWeather.chosen===null,"panel click did not discard the city draft")
      mouseClick(findChild(weatherView,"weatherLocation"))
      cityInput.text="Paris";wait(350)
      fakeWeather.suggestions=[{name:"Paris",description:"France",latitude:48.85,longitude:2.35}]
      keyClick(Qt.Key_Return)
      check(!weatherView.editing && fakeWeather.chosen && fakeWeather.chosen.name==="Paris","Enter did not commit the city")
      mouseClick(findChild(weatherView,"weatherLocation"))
      mouseClick(findChild(weatherView,"weatherAuto"))
      check(fakeWeather.autoCalls===0,"auto-location was applied before Enter")
      keyClick(Qt.Key_Return)
      check(fakeWeather.autoCalls===1,"weather auto-location control failed")
      var calendarTab=findChild(pages,"calendarOpen")
      calendarTab.clicked()
      wait(350)
      var calendarPageHeight=pages.implicitHeight
      check(findChild(calendarTab,"tabLabel").color===Island.Design.selectedText,"active tab label did not use the theme accent")
      check(pages.calendar && Math.abs(findChild(pages,"islandCalendar").mapToItem(pager,0,0).x)<1,"weather-to-calendar tab switched height without contents")
      var weatherTab=findChild(pages,"weatherOpen")
      weatherTab.clicked()
      wait(350)
      check(Math.abs(pages.implicitHeight-calendarPageHeight)<1,"Calendar and Weather have different popup heights")
      check(pages.weather && Math.abs(weatherView.mapToItem(pager,0,0).x)<1,"calendar-to-weather tab switched height without contents")
      var overviewTab=findChild(pages,"islandTabOverview")
      overviewTab.clicked()
      wait(350)
      check(!pages.weather && !pages.calendar,"weather back did not return to inbox")
      check(Math.abs(pages.implicitHeight-calendarPageHeight)<1,"minimal Overview does not match Calendar/Weather height")
      check(Math.abs(findChild(pages,"islandMediaPlayer").mapToItem(pager,0,0).x)<1,"overview tab did not move contents into view")
      mouseWheel(pager,pager.width/2,pager.height/2,0,-120,Qt.NoButton,Qt.ShiftModifier)
      wait(350)
      check(pages.calendar,"calendar did not reopen after weather")
      var pageCalendar=findChild(pages,"islandCalendar")
      mouseDrag(pager,pager.width*0.15,pager.height*0.45,pager.width*0.65,0,Qt.LeftButton)
      tryVerify(function(){return !pages.calendar && Math.abs(findChild(pages,"islandMediaPlayer").mapToItem(pager,0,0).x)<1},1200)
      check(!pages.calendar,"reverse swipe did not return to inbox")
      check(!findChild(pageCalendar,"calendarSpotlight").rippling,"swipe triggered a calendar click wave")
      var pageSeek=findChild(pages,"mediaCompactProgress")
      mouseDrag(pageSeek,pageSeek.width*0.2,pageSeek.height/2,pageSeek.width*0.5,0,Qt.LeftButton)
      wait(100)
      check(!pages.calendar && p.position>100,"page swipe stole track scrubbing")
      check(!findChild(pages,"mediaSpotlight").rippling,"track dragging triggered a click ripple")
      pages.requestPage(3);wait(350)
      mouseWheel(pager,pager.width/2,pager.height/2,-120,0,Qt.NoButton);wait(350)
      check(pages.controls,"scroll past the last tab did not wrap to Controls")
      mouseWheel(pager,pager.width/2,pager.height/2,120,0,Qt.NoButton);wait(350)
      check(pages.weather,"scroll before Controls did not wrap to Weather")
      pages.requestPage(0);wait(350)
      check(Math.abs(pages.implicitHeight-calendarPageHeight)<1,"Controls does not match Calendar/Weather height")
      mouseDrag(pager,pager.width/2,30,pager.width*0.35,0,Qt.LeftButton)
      tryVerify(function(){return pages.weather},1200)
      check(pages.weather,"edge swipe did not wrap tabs")
      pages.requestPage(1);wait(350)
      var heading=findChild(pages,"mediaSectionHeading")
      check(heading.title==="Media","generic media heading is missing")
      p.identity="Spotify";wait(20)
      check(heading.title==="Spotify","Spotify heading is missing")
      p.identity="Test Music"
      var player=findChild(pages,"islandMediaPlayer")
      mouseClick(player,player.width-2,player.height-2,Qt.RightButton)
      check(calendarSurface.dismissed,"media background right click did not dismiss popup")

      console.log("CYCLIC_TABS_PASS")
      console.log("ISLAND_INTERACTION_PASS")
      if (Quickshell.env("ISLAND_CALENDAR_CAPTURE_PATH")) {
        calendarSurface.grabToImage(function(result) { result.saveToFile(Quickshell.env("ISLAND_CALENDAR_CAPTURE_PATH")); Qt.quit() })
      } else Qt.quit()
    }
  }
  Timer { interval: 300; running: true; onTriggered: {try {test.test_barWidgetLoads();test.test_controls()} catch(error) {console.log("ISLAND_INTERACTION_FAIL",error.stack);Qt.quit()}} }
  Timer { interval: 17000; running: true; onTriggered: { console.log("ISLAND_INTERACTION_TIMEOUT"); Qt.quit() } }
}
