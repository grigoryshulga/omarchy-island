import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  QtObject {
    id:fakeControls
    property var panelCommand:["python3",decodeURIComponent(Qt.resolvedUrl("Island/controls/build-panel.py").toString().replace(/^file:\/\//,""))]
    function watch(item,visible){}
    function available(key){return false}
    function enabledState(key){return false}
    function toggle(key){}
    function execute(argv){}
    function systemCall(target,method,args){return {ran:true}}
  }
  QtObject {
    id:fakeWeather
    property bool allowed:true
    property bool loading:false
    property bool searching:false
    property bool saving:false
    property bool stale:false
    property bool useImperial:false
    property string temperatureUnit:"celsius"
    property string error:""
    property var report:null
    property var suggestions:[]
    function search(query){}
    function cancelSearch(){suggestions=[]}
    function choose(place){}
    function autoLocate(){}
    function activate(){}
    function refresh(){}
  }
  QtObject {
    id:states
    property var microphone:({})
    property bool microphoneMuted:false
    property bool nightLight:false
    property bool stayAwake:false
    property bool recording:false
    property bool remoteActive:false
  }
  QtObject {
    id:player
    property string identity:"Test music"
    property string trackTitle:"Track"
    property string trackArtist:"Artist"
    property string trackArtUrl:""
    property bool isPlaying:false
    property bool canGoPrevious:true
    property bool canGoNext:true
    property bool canTogglePlaying:true
    property bool canSeek:true
    property bool lengthSupported:true
    property bool positionSupported:true
    property bool volumeSupported:true
    property real length:180
    property real position:20
    property real volume:0.5
  }
  QtObject {
    id:service
    // The real service always provides a bridge, even when T3 is disabled.
    readonly property var modules:({controls:fakeControls,weather:("weather" in service) ? service.weather : null,calendar:{allowed:true,calendars:("calendars" in service) ? service.calendars : null,reminders:("reminders" in service) ? service.reminders : null},notifications:service,media:service,t3:t3})
    property var t3:({allowed:false,connected:false,canRespond:false,responsesEnabled:false,rows:[]})
    property var indicators:states
    property var weather:fakeWeather
    property var player:player
    property bool hasMedia:true
    property bool playing:false
    property var players:[]
    property var latest:null
    property var mutedSources:[]
    readonly property var activeEntries: allEntries
    property var historyEntries: []
    property var allEntries:[{key:"test",app:"Keyboard test",summary:"Notification",body:"Body",codes:"123456",ts:1}]
    property string error:""
    property bool doNotDisturb:false
    property int activations:0
    function setDoNotDisturb(value){doNotDisturb=value}
    function actions(row){return []}
    function media(action){}
    function activate(row){activations++}
    function mute(source){}
    function clear(){}
  }
  QtObject {id:shell;function firstPartyServiceFor(id){return null}}
  QtObject {
    id:bar
    property var shell:shell
    property color foreground:"white"
    property color background:"black"
    property color barForeground:"white"
    property color urgent:"red"
    property string fontFamily:"monospace"
    property bool vertical:false
    property string position:"top"
    property int barSize:30
    property bool foregroundAnimationEnabled:true
    function registerClickTarget(t){}
    function unregisterClickTarget(t){}
    function showTooltip(t,s){}
    function hideTooltip(t){}
    function moduleWidgets(id){return []}
  }
  PanelWindow {
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.Exclusive
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.namespace:"island-keyboard-test"
    exclusionMode:ExclusionMode.Ignore
    anchors {top:true;left:true}
    visible:true;implicitWidth:560;implicitHeight:700
    Island.PopupPages {
      id:pages;anchors.fill:parent;anchors.margins:16
      expanded:true;keyboardActive:true
      service:service;bar:bar;strings:translations
        onPageRequested:index=>pages.selectedPage=index
      onSettingRequested:(key,value)=>{var updated=Object.assign({},pages.settings);updated[key]=value;pages.settings=updated}
    }
    Commons.Translations {id:translations;directory:Qt.resolvedUrl("Island/i18n")}
    TestCase {
      id:test;when:false
      function check(ok,message){if(!ok){console.log("KEYBOARD_FAIL:",message);Qt.quit();throw new Error(message)}}
      function test_keyboard(){
        pages.forceActiveFocus();wait(150)
        var overviewTab=findChild(pages,"islandTabOverview")
        var gear=findChild(pages,"overviewCustomize")
        var tabWidth=overviewTab.width,tabsHeight=findChild(pages,"islandTabs").height
        mouseMove(pages,pages.width-1,pages.height-1);wait(30)
        check(!gear.visible,"Overview gear is permanently visible")
        check(!findChild(pages,"overviewDone").visible,"Overview summary still has a settings heading")
        mouseMove(overviewTab,overviewTab.width/2,overviewTab.height/2);wait(30)
        check(gear.visible,"Hovering active Overview did not reveal its gear")
        check(overviewTab.width===tabWidth && findChild(pages,"islandTabs").height===tabsHeight,"Gear changed tab geometry")
        var gearPosition=gear.mapToItem(overviewTab,0,0)
        check(gearPosition.x>=0 && gearPosition.x+gear.width<=tabWidth,"Gear extends outside its tab")
        mouseMove(pages,pages.width-1,pages.height-1);wait(30)
        check(!gear.visible && overviewTab.width===tabWidth,"Gear stayed visible after hover or changed tab width")
        pages.anchors.rightMargin=200;wait(50)
        mouseMove(overviewTab,overviewTab.width/2,overviewTab.height/2);wait(30)
        gearPosition=gear.mapToItem(overviewTab,0,0)
        check(gear.visible && gearPosition.x>=0 && gearPosition.x+gear.width<=overviewTab.width,"Gear overflows a narrow tab")
        pages.anchors.rightMargin=16;wait(50)
        mouseMove(gear,gear.width/2,gear.height/2);wait(30)
        mouseClick(gear);wait(40)
        check(findChild(pages,"overviewDone").visible,"Gear click did not open customization")
        check(pages.selectedPage===1,"Gear changed the selected page")
        check(pages.back(),"Customization did not consume Back");wait(40)
        check(overviewTab.activeFocus,"Customization did not restore the tab focus")
        mouseMove(pages,pages.width-1,pages.height-1);wait(30)
        check(gear.visible,"Keyboard focus did not reveal Overview gear")
        keyClick(Qt.Key_Tab);wait(30)
        check(gear.activeFocus,"Tab did not reach the gear")
        keyClick(Qt.Key_Return);wait(30)
        check(findChild(pages,"overviewDone").visible,"Keyboard did not open customization")
        pages.back();wait(30)
        pages.selectedPage=0;wait(280)
        mouseMove(overviewTab,overviewTab.width/2,overviewTab.height/2);wait(30)
        check(!gear.visible,"Inactive Overview revealed its gear")
        mouseClick(overviewTab);wait(280)
        check(pages.selectedPage===1 && !findChild(pages,"overviewDone").visible,"Tab click unexpectedly opened customization")
        pages.forceActiveFocus()
        keyClick(Qt.Key_1,Qt.AltModifier);wait(280)
        check(pages.controls,"Alt+1 did not open Controls")
        var audio=findChild(pages,"controlOpen-audio"),bluetooth=findChild(pages,"controlOpen-bluetooth")
        check(findChild(pages,"overviewBack").activeFocus,"detail switch did not focus its Back button")
        audio.forceActiveFocus()
        keyClick(Qt.Key_Right);check(bluetooth.activeFocus,"right arrow did not move between tiles: "+findChild(pages,"islandKeyboardNavigation").focused.objectName)
        keyClick(Qt.Key_J);check(findChild(pages,"controlOpen-tailscale").activeFocus,"Vim J did not move down")
        var dnd=findChild(pages,"controlDnd")
        dnd.forceActiveFocus();keyClick(Qt.Key_Return)
        check(service.doNotDisturb,"Enter did not activate focused control")
        keyClick(Qt.Key_Tab);check(findChild(pages,"controlNightLight").activeFocus,"Tab did not advance through current page controls")
        keyClick(Qt.Key_Backtab,Qt.ShiftModifier);check(dnd.activeFocus,"Shift+Tab did not reverse focus")
        audio.forceActiveFocus();keyClick(Qt.Key_Return);tryVerify(function(){var control=findChild(pages,"islandNativeControl");return control.item && control.item.opened && control.item.keyboardTarget && control.item.keyboardTarget.activeFocus},4000)
        var loader=findChild(pages,"islandNativeControl")
        check(loader.item && loader.item.opened,"keyboard did not open native audio detail")
        keyClick(Qt.Key_J);check(loader.item.cursorActive,"native Vim cursor navigation stopped working")
        keyClick(Qt.Key_Tab)
        check(!loader.item.keyboardTarget.activeFocus,"Tab is trapped by the native panel")
        keyClick(Qt.Key_Backtab,Qt.ShiftModifier)
        check(loader.item.keyboardTarget.activeFocus,"Shift+Tab did not return to native navigation")
        keyClick(Qt.Key_2,Qt.AltModifier);wait(280)
        check(!pages.controls && !pages.calendar && !pages.weather,"Alt+2 from a native panel did not open Overview")
        var seek=findChild(pages,"mediaCompactProgress")
        seek.forceActiveFocus();keyClick(Qt.Key_Right)
        check(player.position===21,"focused track slider did not handle right arrow")
        keyClick(Qt.Key_H);check(player.position===20,"focused track slider did not handle Vim H")
        var card=findChild(pages,"notification-test")
        card.forceActiveFocus();wait(180)
        check(card.keyboardFocused,"notification keyboard focus is not visible")
        keyClick(Qt.Key_Return);check(service.activations===1,"Enter did not activate notification")
        check(findChild(card,"copyCode-123456").enabled,"notification actions did not appear for keyboard focus")
        keyClick(Qt.Key_Tab)
        check(findChild(card,"copyCode-123456").activeFocus,"notification action is unreachable via Tab")
        keyClick(Qt.Key_3,Qt.AltModifier);wait(280)
        check(pages.calendar,"Alt+3 did not open Calendar")
        var calendar=findChild(pages,"islandCalendar"),before=calendar.selectedDay.key
        keyClick(Qt.Key_J);wait(40);check(calendar.selectedDay.key!==before,"Vim calendar day navigation failed")
        check(findChild(calendar,"calendar-day-"+calendar.selectedDay.key).activeFocus,"calendar date selection did not follow keyboard focus")
        keyClick(Qt.Key_4,Qt.AltModifier);wait(280)
        check(pages.weather,"Alt+4 did not open Weather")
        findChild(pages,"weatherLocation").clicked();wait(40)
        var field=findChild(pages,"weatherCityInput")
        field.forceActiveFocus();for(var key of [Qt.Key_H,Qt.Key_J,Qt.Key_K,Qt.Key_L]) keyClick(key)
        check(field.text==="hjkl","Vim bindings stole text input")
        var cursor=field.cursorPosition
        keyClick(Qt.Key_Left)
        check(field.cursorPosition===cursor-1,"arrow navigation stole the editor caret")
        keyClick(Qt.Key_1,Qt.AltModifier);wait(280)
        check(pages.controls,"Alt+1 did not switch away from a text editor")
        fakeWeather.allowed=false
        keyClick(Qt.Key_4,Qt.AltModifier);wait(50)
        check(pages.controls,"disabled weather tab still had an active shortcut")
        var settingsTile=findChild(pages,"controlOpen-settings")
        var popupHeight=pages.implicitHeight
        settingsTile.forceActiveFocus();keyClick(Qt.Key_Return);wait(60)
        check(!findChild(pages,"islandTabs").visible && pages.implicitHeight===popupHeight,"Settings did not hide main tabs with stable popup geometry")
        var settingsView=findChild(pages,"islandSettings")
        check(settingsView.visible,"keyboard did not open Settings")
        var previewToggle=findChild(settingsView,"setting-hoverPreview")
        previewToggle.forceActiveFocus();keyClick(Qt.Key_Space);wait(30)
        check(pages.settings.hoverPreview===false && previewToggle.activeFocus,"settings update lost focus or ignored Space")
        findChild(settingsView,"settingsTab-alerts").clicked();wait(20)
        var notificationStyle=findChild(settingsView,"setting-notificationStyle")
        notificationStyle.open();wait(180)
        check(notificationStyle.popupOpen,"notification style chooser did not open")
        keyClick(Qt.Key_Down);keyClick(Qt.Key_Return);wait(160)
        check(pages.settings.notificationStyle==="bar" && !notificationStyle.popupOpen,"page navigation stole dropdown keys")
        var settingsHeight=findChild(pages,"islandControls").implicitHeight
        pages.settings={overviewEnabled:false,calendarEnabled:false,weatherEnabled:false};wait(80)
        check(findChild(pages,"islandPageSwipe").count===1 && pages.enabledPages.join(",")==="1","disabled pages remained in swipe navigation")
        keyClick(Qt.Key_3,Qt.AltModifier);keyClick(Qt.Key_4,Qt.AltModifier);wait(30)
        check(pages.controls && findChild(pages,"islandControls").implicitHeight===settingsHeight,"disabled shortcuts navigated or resized Settings")
        pages.settings={calendarEnabled:false,weatherEnabled:false};wait(80)
        pages.back();pages.back();wait(280)
        check(!pages.controls && Math.abs(findChild(pages,"islandMediaPlayer").mapToItem(findChild(pages,"islandPageSwipe"),0,0).x)<1,"re-enabling Overview lost its content")
        keyClick(Qt.Key_1,Qt.AltModifier);wait(280)
        findChild(pages,"controlOpen-settings").clicked();wait(30)
        pages.back();wait(30)
        check(findChild(pages,"islandTabs").visible,"back did not restore main tabs")
        check(findChild(pages,"controlOpen-settings").activeFocus,"back did not restore Settings tile focus")
        pages.keyboardActive=false
        keyClick(Qt.Key_2,Qt.AltModifier);wait(50)
        check(pages.controls,"shortcuts remained enabled outside persistent menu")
        console.log("KEYBOARD_PASS");Qt.quit()
      }
    }
    Timer {interval:300;running:true;onTriggered:test.test_keyboard()}
  }
}
