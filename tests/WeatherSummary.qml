import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  QtObject {
    id: provider
    property bool loading: false
    property bool searching: false
    property bool stale: false
    property bool useImperial: false
    property string temperatureUnit: "celsius"
    property string error: ""
    property var suggestions: []
    property var report: ({location:"Екатеринбург",fetchedAt:1794476400,utcOffset:18000,
      current:{temperature:-3,feels:-7,wind:12,humidity:81,code:71,isDay:true},
      days:[
        {date:"2026-11-12",min:-6,max:-2,code:71,sunrise:"2026-11-12T08:35",sunset:"2026-11-12T16:42"},
        {date:"2026-11-13",min:-6,max:-2,code:71},
        {date:"2026-11-14",min:-8,max:-4,code:71},
        {date:"2026-11-15",min:-5,max:0,code:3},
        {date:"2026-11-16",min:-3,max:2,code:2},
        {date:"2026-11-17",min:-4,max:1,code:3},
        {date:"2026-11-18",min:-7,max:-2,code:71},
        {date:"2026-11-19",min:-6,max:-1,code:2}
      ]})
    function cancelSearch() {suggestions=[]}
    function search(query) {}
    function refresh() {}
  }
  FloatingWindow {
    id: window
    visible: true
    implicitWidth: view.width+32
    implicitHeight: view.implicitHeight+32
    color: Island.Design.canvas
    Item {
      id: surface
      anchors.fill: parent
      Rectangle { anchors.fill: parent; color: Island.Design.opaqueCanvas }
      Island.WeatherView {
        id: view
        x:16; y:16; width:420; height:implicitHeight
        showBack:false; strings:translations; weather:provider
        onTemperatureUnitRequested: value => provider.temperatureUnit=value
      }
    }
    Commons.Translations {id:translations;directory:Qt.resolvedUrl("Island/i18n")}
    TestCase {
      id:test;when:false
      function check(ok,message) {if(!ok)throw new Error(message)}
      function item(name) {return findChild(view,name)}
      function capture(name) {
        var directory=Quickshell.env("ISLAND_WEATHER_CAPTURE")
        if(!directory)return
        mouseMove(surface,0,0);wait(30)
        var saved=false
        surface.grabToImage(function(image){saved=image.saveToFile(directory+"/"+name+".png")})
        tryVerify(function(){return saved},2000)
      }
      function geometry() {
        var summary=item("weatherSummary"),scene=item("weatherHeroScene")
        check(scene.width>view.width*0.25,"illustration lost its column: "+scene.width)
        check(Commons.I18n.rightToLeft ? summary.x>=scene.x+scene.width : scene.x>=summary.x+summary.width,"summary and artwork overlap")
        for(var i=0;i<7;i++) {
          var day=item("weatherDay-"+i),track=findChild(day,"weatherRangeTrack"),bar=findChild(day,"weatherRange")
          check(day.mapToItem(view,0,0).x>=-1 && day.mapToItem(view,day.width,0).x<=view.width+1,"forecast overflows horizontally")
          check(bar.y>=0 && bar.height>0 && bar.y+bar.height<=track.height+0.01,"range escapes its track")
          check(!findChild(day,"weatherDayHigh").truncated && !findChild(day,"weatherDayLow").truncated,"forecast value was truncated")
        }
        var footer=item("weatherSunset")
        check(footer.mapToItem(view,0,footer.height).y<=view.height+1,"solar footer clipped")
      }
      function run() {
        Commons.Style.fontOverrides=({});Commons.Style.fontBaseSize=12
        Commons.Style.reduceMotion=true
        view.clockNow=Date.parse("2026-11-12T14:40:00+05:00")
        wait(100)
        check(item("weatherForecast").count===7,"not seven future days")
        check(item("weatherCondition").text===translations.t("weather.condition.6"),"missing condition description")
        check(item("weatherCondition").effectiveHorizontalAlignment===(Commons.I18n.rightToLeft ? Text.AlignRight : Text.AlignLeft),"condition text did not follow text direction")
        check(view.solar.sunrise.getHours()===8 && view.solar.sunset.getMinutes()===42,"city solar time shifted")
        var palettes=[
          {name:"dark",bg:"#11151a",fg:"#eeeeee",accent:"#a5b88a",muted:"#8c929d"},
          {name:"light",bg:"#f5f5ef",fg:"#22222a",accent:"#3855a8",muted:"#666666"},
          {name:"mono",bg:"#191919",fg:"#eeeeee",accent:"#aaaaaa",muted:"#888888"}
        ]
        for(var palette of palettes) {
          Commons.Color.background=palette.bg;Commons.Color.foreground=palette.fg
          Commons.Color.popups.background=palette.bg;Commons.Color.popups.text=palette.fg
          Commons.Color.accent=palette.accent;Commons.Color.muted=palette.muted
          wait(60);geometry()
          check(item("weatherHeroScene").accent===Island.Design.accent,"artwork ignores theme")
          capture(palette.name)
        }
        var bar=findChild(item("weatherDay-0"),"weatherRange"),barY=bar.y,barHeight=bar.height
        var unit=item("weatherUnit")
        unit.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
        check(provider.temperatureUnit==="fahrenheit","Enter did not cycle units")
        check(bar.y===barY && bar.height===barHeight,"unit change moved ranges")
        keyClick(Qt.Key_Space);wait(30)
        check(provider.temperatureUnit==="kelvin","Space did not cycle units")
        for(var width of [320,420]) {
          view.width=width
          for(var size of [12,18]) {
            Commons.Style.fontBaseSize=size;wait(70);geometry()
          }
        }
        Commons.Style.fontBaseSize=12;view.width=420
        Commons.Style.cornerRadius=0;wait(40)
        check(findChild(item("weatherDay-0"),"weatherRange").radius===0,"square theme got round range bars")
        var scene=item("weatherHeroScene"),phase=scene.phase
        wait(80);check(scene.phase===phase,"reduced motion animates weather")
        Commons.Style.reduceMotion=false;wait(100)
        check(scene.phase!==phase,"visible weather does not animate")
        view.active=false;phase=scene.phase;wait(80)
        check(scene.phase===phase,"inactive weather keeps animating")
        view.active=true;view.visible=false;phase=scene.phase;wait(80)
        check(scene.phase===phase,"hidden weather keeps animating")
        view.visible=true;Commons.Style.reduceMotion=true
        provider.stale=true;provider.error="offline";wait(30)
        check(item("weatherTemperature").visible,"stale report lost last temperature")
        provider.report=null;wait(30)
        check(!item("weatherTemperature").visible && item("weatherForecast").count===0,"empty report kept temperature or forecast")
        check(item("weatherCondition").text===translations.t("weather.noData"),"empty state missing")
        provider.loading=true;wait(30)
        check(item("weatherCondition").text===translations.t("weather.loading"),"loading state missing")
        console.log("WEATHER_SUMMARY_PASS");Qt.quit()
      }
    }
    Timer {interval:250;running:true;onTriggered:{try{test.run()}catch(error){console.log("WEATHER_SUMMARY_FAIL",error.stack);Qt.quit()}}}
    Timer {interval:12000;running:true;onTriggered:{console.log("WEATHER_SUMMARY_FAIL timeout");Qt.quit()}}
  }
}
