import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import IslandTest 1.0
import "Island" as Island

ShellRoot {
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  AccessibilityProbe {id:probe}
  QtObject {
    id:mockPlayer
    property real volume:0.5
    property bool volumeSupported:true
    property real position:30
    property real length:120
    property bool canSeek:true
    property bool lengthSupported:true
    property bool positionSupported:true
    property bool isPlaying:false
    property string trackTitle:"Track"
    property string trackArtist:"Artist"
    property string trackArtUrl:""
    property bool canGoPrevious:false
    property bool canTogglePlaying:false
    property bool canGoNext:false
  }
  QtObject {id:mediaBackend;property var player: mockPlayer}
  FloatingWindow {
    visible:true;implicitWidth:680;implicitHeight:1250
    Column {
      width:parent.width
      Island.FeedbackButton {
        id:sample;property int activations:0
        text:"Action";focusable:true;onClicked:activations++
      }
      Island.MediaCard {id:media;width:parent.width;expanded:true;strings:strings;service:mediaBackend}
      Island.SettingsRow {
        id:setting;width:parent.width;spec:({key:"hoverDelay", type:"delay"})
        strings:strings;settings:({hoverDelay:140});onSettingRequested:(key,value)=>settings=({hoverDelay:value})
      }
      Island.AgentLimitsCenter {id:center;width:parent.width;availableHeight:120;backend:null;strings:strings}
      NativeSliders {id:native}
      Island.CalendarView {id:calendar;width:parent.width;strings:strings}
    }
    TestCase {
      id:test;when:false

      function tab(container,label) {
        if ("tabActive" in container && container.label===label) return container
        for (var child of container.children) {
          var match=tab(child,label)
          if (match) return match
        }
        return null
      }

      function checkButton() {
        compare(probe.inspect(sample).name,"Action")
        verify(probe.act(sample,"Press"))
        compare(sample.activations,1)
        sample.enabled=false
        verify(probe.inspect(sample).disabled)
        probe.act(sample,"Press")
        compare(sample.activations,1)
      }

      function checkSliders() {
        var seek=findChild(media,"mediaSeek")
        var a=probe.inspect(seek)
        compare(a.role,Accessible.Slider)
        compare(a.name,strings.t("media.playbackPosition"))
        compare(a.description,strings.t("media.seconds").arg(Commons.I18n.formatNumber(30)))
        compare(a.minimum,0);compare(a.maximum,120);compare(a.value,30);compare(a.step,1)
        verify(probe.setValue(seek,55));compare(mockPlayer.position,55)
        mockPlayer.position=10
        compare(probe.inspect(seek).value,10)
        verify(probe.act(seek,"Increase"));compare(mockPlayer.position,11)
        verify(probe.act(seek,"Decrease"));compare(mockPlayer.position,10)
        verify(probe.setValue(seek,500));compare(mockPlayer.position,120)
        mockPlayer.canSeek=false
        verify(probe.inspect(seek).disabled);probe.setValue(seek,5);compare(mockPlayer.position,120)
        mockPlayer.canSeek=true
        var trigger=findChild(media,"mediaVolumeTrigger")
        compare(probe.inspect(trigger).name,strings.t("media.volume"))
        verify(probe.act(trigger,"Press"))
        var volume=findChild(media,"mediaVolume")
        tryVerify(function(){return volume.visible && probe.inspect(volume).role===Accessible.Slider})
        compare(probe.inspect(volume).name,strings.t("media.volume"))
        verify(probe.setValue(volume,0.7));compare(mockPlayer.volume,0.7)
        compare(probe.inspect(volume).description,Commons.I18n.formatNumber(70)+"%")
        var delay=findChild(setting,"setting-hoverDelay")
        compare(probe.inspect(delay).name,strings.t("settings.hoverDelay"))
        compare(probe.inspect(delay).maximum,1000)
        compare(probe.inspect(delay).description,strings.t("settings.milliseconds").arg(Commons.I18n.formatNumber(140)))
        verify(probe.act(delay,"Increase"));compare(setting.settings.hoverDelay,160)
        verify(probe.setValue(delay,17.9));compare(setting.settings.hoverDelay,18)
        delay.forceActiveFocus();keyClick(Qt.Key_Right);compare(setting.settings.hoverDelay,38)
        setting.spec=({key:"agentLimitsWarning",type:"percent"})
        setting.settings=({agentLimitsWarning:20})
        compare(probe.inspect(delay).description,Commons.I18n.formatNumber(20)+"%")
        media.compactOverview=true
        var compact=findChild(media,"mediaCompactProgress")
        compare(probe.inspect(compact).name,strings.t("media.playbackPosition"))
        verify(probe.setValue(compact,42));compare(mockPlayer.position,42)
      }

      function checkNativeSliders() {
        var labels={"Output":"50%","Microphone":"40%","Player A":"90%","Brightness":"70%","Text size":"14px"}
        for(var slider of native.children) {
          var a=probe.inspect(slider)
          compare(a.role,Accessible.Slider)
          verify(a.name in labels,a.name)
          compare(a.description,labels[a.name])
          delete labels[a.name]
          verify(probe.setValue(slider,0.75))
          compare(native.mockLevel,0.75)
          verify(probe.act(slider,"Set Focus"));keyClick(Qt.Key_Right)
          fuzzyCompare(native.mockLevel,0.8,0.00001)
          native.mockLevel=0.5
        }
        compare(Object.keys(labels).length,0,"Missing built-in slider labels")
      }

      function checkTabs() {
        var limits=tab(center,strings.t("limits.tab.limits")),usage=tab(center,strings.t("limits.tab.usage"))
        var a=probe.inspect(usage)
        compare(a.role,Accessible.PageTab);compare(a.name,strings.t("limits.tab.usage"))
        verify(!a.selected);verify(probe.inspect(limits).selected)
        verify(probe.act(usage,"Press"))
        compare(center.tab,"usage");verify(probe.inspect(usage).selected);verify(!probe.inspect(limits).selected)
      }

      function checkCalendar() {
        var today=findChild(calendar,"calendar-day-"+calendar.todayKey),a=probe.inspect(today)
        compare(a.name,calendar.today.toLocaleDateString(calendar.locale,Locale.LongFormat))
        verify(a.selected);verify(a.description.includes(strings.t("calendar.today")))
        var neighborDate=new Date(calendar.today)
        neighborDate.setDate(neighborDate.getDate()===1 ? 2 : neighborDate.getDate()-1)
        var key=Qt.formatDate(neighborDate,"yyyy-MM-dd")
        var neighbor=findChild(calendar,"calendar-day-"+key)
        verify(probe.act(neighbor,"Press"))
        verify(probe.inspect(neighbor).selected);verify(!probe.inspect(today).selected)
      }

      function run() {
        checkButton();checkSliders();checkNativeSliders();checkTabs();checkCalendar()
        console.log("ACCESSIBILITY_PASS")
      }
    }
    Timer {
      interval:250;running:true
      onTriggered:{try{test.run()}catch(error){console.log("ACCESSIBILITY_FAIL",String(error),error.stack)} Qt.quit()}
    }
  }
}
