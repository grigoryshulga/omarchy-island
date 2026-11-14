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
    property var modules:({sample:sample,weather:weather})
    property bool doNotDisturb:true
    property var indicators:null
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
      onPageRequested:index=>openedPage=index
      strings:strings;service:service
      elements:[{id:"module:sample",kind:"indicator",side:"left"},{id:"dnd",kind:"indicator",side:"left"}]
    }
    TestCase {
      id:test;when:false
      function test_editor() {
        compare(liveStrip.tooltips,'Sample · '+strings.t('dnd'))
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
        var editor=findChild(settingsView,'clockAdd').parent
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
        verify(findChild(editor,'clockElement-dnd').activeFocus)
        editor.add('separator');wait(30)
        compare(editor.selectedRow.kind,'separator')
        editor.add('space');wait(30)
        compare(editor.selectedRow.kind,'space')
        var id=editor.selectedId
        keyClick(Qt.Key_Left,Qt.ControlModifier);wait(30)
        compare(editor.selectedId,id)
        verify(findChild(editor,'clockElement-'+id).activeFocus)
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
        editor.add('separator');wait(30)
        verify(findChild(editor,'clockElement-'+editor.selectedId).activeFocus)
        console.log('CLOCK_LAYOUT_PASS')
      }
      function run(){try{test_editor()}catch(e){console.log('MODULES_FAIL',String(e),e.stack)}Qt.quit()}
    }
  }
  Timer {interval:200;running:true;onTriggered:test.run()}
}
