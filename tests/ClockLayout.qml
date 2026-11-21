import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/ClockLayout.mjs" as Layout

ShellRoot {
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  QtObject {
    id:service
    property var modules:({sample:sample,weather:weather,t3:{allowed:true,workingCount:1,waitingCount:0},herdr:{allowed:true,workingCount:1,waitingCount:0},agentLimits:{allowed:true,indicatorVisible:true,tightest:{remaining:10,name:"Codex",label:"Weekly",stale:false}},battery:{allowed:true,present:true,lowCharge:true,fraction:0.1,icon:"󰁺"}})
    property var t3:QtObject {property bool connected:true;property var rows:[]}
    property var downloads:[]
    property bool playing:false
    property var player:null
    property bool doNotDisturb:true
    property var indicators:QtObject {
      property bool recording:true
      property bool remoteActive:true
      property bool updateAvailable:true
      property bool microphoneMuted:true
      property bool nightLight:true
      property bool stayAwake:true
    }
  }
  QtObject {
    id:weather
    property bool allowed:true
    property bool activated:false
    property int activations:0
    property var report:null
    property string temperatureUnit:"celsius"
    property bool stale:false
    function activate(){activated=true;activations++}
  }
  QtObject {id:sample;property bool allowed:true}
  FloatingWindow {
    visible:true;implicitWidth:600;implicitHeight:900
    Island.SettingsView {
      id:settingsView;width:500;height:850;strings:strings;service:service;category:1
      onSettingRequested:(key,value)=>{var next=Object.assign({},settings);next[key]=value;settings=next}
    }
    Island.ClockIndicatorStrip {
      id:liveStrip;y:860;property int openedPage:0
      property var actions:[]
      property var openedActivity:null
      onNowRequested:activity=>openedActivity=activity
      property string openedModule:""
      onActivate:mode=>actions=actions.concat([mode])
      onDetailsRequested:moduleId=>openedModule=moduleId
      onPageRequested:index=>openedPage=index
      strings:strings;service:service
      elements:[{id:"module:sample",kind:"indicator",side:"left"},{id:"dnd",kind:"indicator",side:"left"}]
    }
    TestCase {
      id:test;when:false
      function test_editor() {
        compare(liveStrip.tooltips,'Sample · '+strings.t('dnd'))
        var savedElements=liveStrip.elements
        var previewRows=savedElements.concat([{id:"remote",kind:"indicator"},{id:"separator:1",kind:"separator"},{id:"space:1",kind:"space"}])
        liveStrip.editing=true
        liveStrip.elements=previewRows
        for(var vertical of [false,true]) {
          liveStrip.vertical=vertical;wait(30)
          var previous=null
          for(var row of previewRows) {
            var button=findChild(liveStrip,"clockElement-"+row.id)
            compare(button.width,liveStrip.barHeight);compare(button.height,liveStrip.barHeight)
            var center=button.mapToItem(liveStrip,button.width/2,button.height/2)
            var axis=vertical ? center.y : center.x
            if(previous!==null) compare(axis-previous,liveStrip.barHeight+(vertical ? liveStrip.rowSpacing : liveStrip.columnSpacing))
            previous=axis
          }
        }
        liveStrip.editing=false
        var toggles=["microphone","dnd","nightLight","stayAwake"]
        liveStrip.elements=toggles.map(function(id){return {id:id,kind:"indicator",side:"left"}})
        for(var vertical of [false,true]) {
          liveStrip.vertical=vertical
          wait(30)
          var end=-Infinity
          for(var id of toggles) {
            var target=findChild(liveStrip,"indicatorAction-"+id)
            var pos=target.mapToItem(liveStrip,0,0)
            var start=vertical ? pos.y : pos.x
            verify(target.width>=Commons.Style.space(24) && target.height>=Commons.Style.space(24),"Small "+id+" target")
            verify(start>=end,"Adjacent "+id+" target overlaps its neighbor")
            end=start+(vertical ? target.height : target.width)
          }
        }
        liveStrip.vertical=false
        for(var mode of ["recording","remote","update","microphone","nightLight","stayAwake","dnd"]) {
          liveStrip.elements=[{id:mode,kind:"indicator",side:"left"}];wait(20)
          var action=findChild(liveStrip,"indicatorAction-"+mode)
          verify(action.visible)
          verify(action.height>=liveStrip.barHeight)
          mouseClick(action,action.width/2,action.height/2)
          compare(liveStrip.actions.slice(-1)[0],mode)
          action.forceActiveFocus();keyClick(Qt.Key_Return)
          compare(liveStrip.actions.length,2*(["recording","remote","update","microphone","nightLight","stayAwake","dnd"].indexOf(mode)+1))
          liveStrip.editing=true;wait(10)
          verify(!action.visible)
          liveStrip.editing=false
        }
        liveStrip.elements=[{id:"module:battery",kind:"indicator",side:"left"}];wait(20)
        findChild(liveStrip,"batteryIndicatorButton").clicked()
        compare(liveStrip.openedModule,"battery")
        for(var moduleId of ["t3","herdr","agentLimits"]) {
          liveStrip.elements=[{id:"module:"+moduleId,kind:"indicator",side:"left"}];wait(20)
          var moduleAction=findChild(liveStrip,"moduleIndicatorAction")
          verify(moduleAction.visible)
          mouseClick(moduleAction,moduleAction.width/2,moduleAction.height/2)
          compare(liveStrip.openedModule,moduleId)
          liveStrip.openedModule=""
          moduleAction.forceActiveFocus();keyClick(Qt.Key_Space)
          compare(liveStrip.openedModule,moduleId)
        }
        liveStrip.elements=[{id:"now",kind:"indicator",side:"right"}]
        wait(20)
        var now=findChild(liveStrip,"islandNowIndicator")
        compare(liveStrip.implicitWidth,0)
        service.player={trackTitle:"Long track title ".repeat(12),trackArtist:"Artist",dbusName:"test"}
        service.playing=true;wait(20)
        verify(now.visible && now.width<=Commons.Style.space(136))
        mouseClick(now,now.width/2,now.height/2)
        compare(liveStrip.openedActivity.kind,"media")
        service.downloads=[{key:"file",downloadPath:"/downloads/file",filename:"cover",downloadedBytes:4096,active:true,ts:1}]
        wait(20)
        compare(now.text,"4 KiB")
        liveStrip.vertical=true;wait(20)
        compare(now.text,"")
        verify(now.Accessible.name.includes("cover") && now.Accessible.name.includes("4 KiB"))
        verify(now.width<=liveStrip.barSize)
        now.forceActiveFocus();keyClick(Qt.Key_Space)
        compare(liveStrip.openedActivity.row.key,"file")
        service.t3.rows=[{id:"thread",requestId:"q",requestKind:"user_input",project:"Island",request:{questions:[{text:"Which option?"}]}}]
        wait(20)
        verify(now.Accessible.name.includes("Island") && now.Accessible.name.includes("Which option?"))
        now.Accessible.pressAction()
        compare(liveStrip.openedActivity.row.id,"thread")
        service.t3.rows=service.t3.rows.concat([{id:"other",requestId:"r"}])
        liveStrip.vertical=false;wait(20)
        verify(now.text.includes(Commons.I18n.formatNumber(2)))
        now.forceActiveFocus();keyClick(Qt.Key_Return)
        compare(liveStrip.openedActivity.count,2)
        liveStrip.editing=true;wait(20)
        verify(!now.enabled)
        liveStrip.openedActivity=null
        now.Accessible.pressAction()
        compare(liveStrip.openedActivity,null)
        liveStrip.editing=false;service.t3.rows=[];service.downloads=[];service.playing=false
        liveStrip.elements=savedElements;wait(20)
        verify(liveStrip.implicitWidth>20)
        sample.allowed=false;wait(30)
        compare(liveStrip.tooltips,strings.t('dnd'))
        service.doNotDisturb=false;wait(30)
        compare(liveStrip.implicitWidth,0)
        liveStrip.settings={indicatorDnd:false}
        service.doNotDisturb=true;wait(30)
        compare(liveStrip.implicitWidth,0)
        liveStrip.settings={indicatorDnd:false,clockLayout:liveStrip.elements};wait(30)
        verify(liveStrip.implicitWidth>0)
        sample.allowed=true;wait(30)
        verify(liveStrip.implicitWidth>20)
        liveStrip.vertical=true;wait(30)
        verify(liveStrip.implicitHeight>20)
        var editor=findChild(settingsView,'clockLayoutEditor')
        compare(editor.selectedId,'clock')
        var dnd=findChild(editor,'clockElement-dnd')
        verify(dnd)
        var clock=findChild(editor,'clockElement-clock')
        var destination=clock.mapToItem(dnd,-20,clock.height/2)
        mouseDrag(dnd,dnd.width/2,dnd.height/2,destination.x-dnd.width/2,0,Qt.LeftButton)
        wait(50)
        compare(settingsView.settings.clockLayout.find(r=>r.id==='dnd').side,'left')
        dnd=findChild(editor,'clockElement-dnd');dnd.clicked()
        compare(editor.selectedId,'dnd')
        findChild(editor,'clockSwitchSide').clicked();wait(30)
        compare(settingsView.settings.clockLayout.find(r=>r.id==='dnd').side,'right')
        verify(findChild(editor,'clockTile-dnd').activeFocus)
        var tile=findChild(editor,"clockTile-dnd"),lane=findChild(editor,"clockLane-left")
        compare(tile.iconText,editor.entries.find(entry=>entry.id==="dnd").icon)
        verify(tile.width>=44 && tile.height>=44)
        var dest=lane.mapToItem(tile,lane.width/2,tile.mapToItem(lane,0,tile.height/2).y)
        mouseDrag(tile,tile.width/2,tile.height/2,dest.x-tile.width/2,0,Qt.LeftButton);wait(50)
        compare(editor.selectedRow.side,"left","Dragging the labeled tile did not cross the clock")
        tile=findChild(editor,"clockTile-dnd")
        var other=findChild(editor,"clockLane-right")
        var drop=other.mapToItem(tile,other.width/2,tile.mapToItem(other,0,tile.height/2).y)
        var order=JSON.stringify(editor.elements)
        mousePress(tile,tile.width/2,tile.height/2)
        mouseMove(tile,drop.x,drop.y,30)
        verify(editor.ownsKeys,"Drag did not become active")
        compare(JSON.stringify(editor.elements),order,"Drag saved before release")
        keyClick(Qt.Key_Escape)
        mouseRelease(tile,drop.x,drop.y);wait(30)
        compare(JSON.stringify(editor.elements),order,"Escape committed the drag")
        editor.add('separator');wait(30)
        compare(editor.selectedRow.kind,'separator')
        editor.add('space');wait(30)
        compare(editor.selectedRow.kind,'space')
        var id=editor.selectedId
        var removeAction=findChild(editor,"clockRemove")
        removeAction.forceActiveFocus(Qt.TabFocusReason)
        var removeTip=findChild(removeAction,"islandButtonTooltip")
        tryCompare(removeTip,"opened",true,1200)
        compare(removeTip.text,strings.t("clock.remove"))
        compare(removeAction.Accessible.name,removeTip.text)
        keyClick(Qt.Key_Escape)
        tryCompare(removeTip,"visible",false,400)
        compare(editor.selectedId,id,"Reading the remove hint changed the selection")
        findChild(editor,"clockElement-"+id).forceActiveFocus()
        keyClick(Qt.Key_Left,Qt.ControlModifier);wait(30)
        compare(editor.selectedId,id)
        verify(findChild(editor,'clockTile-'+id).activeFocus)
        editor.remove();wait(30)
        compare(editor.selectedId,'clock')
        verify(!settingsView.settings.clockLayout.some(r=>r.id===id))
        editor.vertical=true;wait(30)
        verify(editor.height>0)
        findChild(editor,'clockFormat').changed('HH\nmm');wait(30)
        compare(settingsView.settings.verticalFormat,'HH\nmm')
        editor.vertical=false
        findChild(editor,'clockFormat').changed('HH:mm:ss');wait(30)
        compare(settingsView.settings.format,'HH:mm:ss')
        // A disabled indicator remains selectable; no native action is triggered.
        service.doNotDisturb=false;wait(30)
        verify(findChild(editor,'clockElement-dnd').visible)
        findChild(editor,'clockReset').clicked();wait(30)
        compare(settingsView.settings.clockLayout,null)
        verify(!editor.elements.some(r=>r.id==="now"))
        editor.add("now");wait(30)
        verify(findChild(editor,"clockTile-now").activeFocus)
        compare(settingsView.settings.clockLayout.filter(r=>r.id==="now").length,1)
        editor.remove();wait(30)
        verify(!editor.elements.some(r=>r.id==="now"))
        // Weather is opt-in, shares its backend and routes to the Weather page.
        verify(!editor.elements.some(r=>r.id==='module:weather'))
        editor.add('module:weather');wait(30)
        compare(weather.activations,1)
        var weatherView=findChild(editor,'islandWeatherIndicator')
        compare(weatherView.temperatureText,'—')
        weather.report={current:{temperature:0,code:0,isDay:true}};wait(30)
        compare(weatherView.temperatureText,Commons.I18n.formatNumber(0)+'°')
        weather.temperatureUnit='fahrenheit';wait(30)
        compare(weatherView.temperatureText,Commons.I18n.formatNumber(32)+'°')
        weather.temperatureUnit='kelvin';wait(30)
        compare(weatherView.temperatureText,Commons.I18n.formatNumber(273)+' K')
        weather.stale=true;wait(30)
        verify(findChild(weatherView,'weatherIndicatorTemperature').text.endsWith(' ·'))
        liveStrip.elements=[{id:'module:weather',kind:'indicator',side:'left'}];wait(30)
        compare(weather.activations,1)
        findChild(liveStrip,'islandWeatherIndicator').detailsRequested()
        compare(liveStrip.openedPage,3)
        weather.allowed=false;wait(30)
        compare(liveStrip.implicitWidth,0)
        verify(findChild(editor,'clockElement-module:weather').visible)
        // Narrow panel, large typography and square corners.
        settingsView.width=280;Commons.Style.cornerRadius=0
        Commons.Style.fontBaseSize*=1.4;wait(30)
        verify(editor.width<=settingsView.width)
        var narrowRight=findChild(editor,"clockLane-right"),narrowLeft=findChild(editor,"clockLane-left")
        verify(narrowRight.y>=narrowLeft.y+narrowLeft.height && narrowRight.width===narrowLeft.width,"Narrow lanes should stack")
        editor.add('separator');wait(30)
        verify(findChild(editor,'clockTile-'+editor.selectedId).activeFocus)
        // Both targets remain usable when one side has no indicators.
        settingsView.width=500
        editor.save([{id:"dnd",kind:"indicator",side:"left"},{id:"update",kind:"indicator",side:"left"}],"update")
        wait(40)
        var updateTile=findChild(editor,"clockTile-update"), firstTile=findChild(editor,"clockTile-dnd")
        var before=firstTile.mapToItem(updateTile,firstTile.width/2,4)
        mouseDrag(updateTile,updateTile.width/2,updateTile.height/2,before.x-updateTile.width/2,before.y-updateTile.height/2,Qt.LeftButton)
        wait(40)
        compare(editor.elements[0].id,"update","Drop before the first tile did not reorder the side")
        updateTile=findChild(editor,"clockTile-update")
        var emptyLane=findChild(editor,"clockLane-right")
        var emptyPoint=emptyLane.mapToItem(updateTile,emptyLane.width/2,emptyLane.height/2)
        mouseDrag(updateTile,updateTile.width/2,updateTile.height/2,emptyPoint.x-updateTile.width/2,emptyPoint.y-updateTile.height/2,Qt.LeftButton)
        wait(40)
        compare(editor.selectedRow.side,"right","Empty side did not accept the drop")
        settingsView.width=280;wait(60)
        updateTile=findChild(editor,"clockTile-update")
        firstTile=findChild(editor,"clockTile-dnd")
        var topSlot=firstTile.mapToItem(updateTile,firstTile.width/2,4)
        mouseDrag(updateTile,updateTile.width/2,updateTile.height/2,topSlot.x-updateTile.width/2,topSlot.y-updateTile.height/2,Qt.LeftButton)
        wait(40)
        compare(editor.elements[0].id,"update","Dragging between stacked lanes chose the wrong insertion point")
        compare(editor.selectedRow.side,"left")
        console.log('CLOCK_LAYOUT_PASS')
      }
      function run(){try{test_editor()}catch(e){console.log('MODULES_FAIL',String(e),e.stack)}Qt.quit()}
    }
  }
  Timer {interval:200;running:true;onTriggered:test.run()}
}
