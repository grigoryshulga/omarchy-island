import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "WeatherModel.js" as Model

Item {
  id: root
  property bool allowed: true
  property bool activated: false
  property string unitOverride: ""
  property string temperatureOverride: ""
  property int refreshOverride: 0
  property var nativePreferences: ({unit:"",refreshMinutes:15})
  property var report: null
  property string error: ""
  property var clock:function(){return Date.now()/1000}
  property var locationCommand:["omarchy-weather-location"]
  property string cachePath:Quickshell.env("HOME")+"/.local/state/omarchy/island/weather.json"
  property string locationPath:Quickshell.env("HOME")+"/.local/state/omarchy/settings/weather.json"
  property string preferencesPath:Quickshell.env("HOME")+"/.config/omarchy/shell.json"
  property real now:clock()
  property string locationKey: ""
  property var suggestions: []
  property string searchQuery: ""
  property bool received: false
  property bool refreshPending: false
  property string requestLocationKey: ""
  readonly property bool loading: forecast.running
  readonly property bool searching: geocode.running
  readonly property bool saving: locationSave.running
  readonly property bool stale: report!==null && (error!=="" || now-report.fetchedAt>refreshMinutes*60+60)
  readonly property int refreshMinutes: Math.max(1,Math.min(120,refreshOverride || nativePreferences.refreshMinutes || 15))
  readonly property bool useImperial: Model.imperial(unitOverride || nativePreferences.unit,Commons.I18n.formatLocale,report ? report.country : "")
  readonly property string temperatureUnit: Model.temperatureUnit(temperatureOverride,useImperial)
  property string helper: String(Qt.resolvedUrl("bin/weather-data")).replace(/^file:\/\//,"")
  function activate() {
    if(!allowed) return
    activated=true
    now=clock()
    if(!report || stale || report.days.length<8) refresh()
  }
  function refresh() {
    if(!allowed || !activated || forecast.running) return
    received=false
    requestLocationKey=locationKey
    forecast.running=true
  }
  function scheduleRefresh() {
    if(!allowed || !activated) return
    if(forecast.running) refreshPending=true
    else Qt.callLater(refresh)
  }
  function search(query) {
    searchQuery=String(query).trim().slice(0,128)
    geocode.running=false
    suggestions=[]
    if(!allowed || searchQuery.length<2) return
    geocode.command=["python3",helper,"search",searchQuery,String(Commons.I18n.formatLocale).slice(0,2).toLowerCase()]
    geocode.running=true
  }
  function cancelSearch() {
    searchQuery="";geocode.running=false;suggestions=[]
  }
  function choose(place) {
    if(!allowed || !place || !Model.coordinates(place) || locationSave.running) return
    locationSave.command=locationCommand.concat(["--set",String(place.name).slice(0,128),place.latitude+","+place.longitude])
    locationSave.running=true
    suggestions=[]
  }
  function autoLocate() {
    if(!allowed || locationSave.running) return
    locationSave.command=locationCommand.concat(["--clear"])
    locationSave.running=true
    suggestions=[]
  }
  function locationChanged(raw) {
    var key=JSON.stringify(Model.location(raw))
    if(key===locationKey) return
    locationKey=key
    scheduleRefresh()
  }
  onAllowedChanged: {
    if(!allowed) {refreshPending=false;forecast.running=false;geocode.running=false;locationSave.running=false;suggestions=[]}
    else {locationFile.reload();nativeSettingsFile.reload();if(activated) refresh()}
  }
  Process {
    id: forecast
    command: ["python3",root.helper,"forecast"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed=Model.parseReport(text)
        if(parsed && root.requestLocationKey===root.locationKey) {
          root.received=true; root.report=parsed; root.error=""; root.now=root.clock()
          cache.setText(text)
        }
      }
    }
    onExited: code => Qt.callLater(function() {
      if(!root.allowed) return
      if(root.refreshPending) {root.refreshPending=false;root.refresh()}
      else if(code!==0 || !root.received) root.error="network"
    })
  }
  Timer { interval: 25000; running: forecast.running; onTriggered: { forecast.running=false; root.error="network" } }
  Timer { interval: root.refreshMinutes*60000; running: root.activated && root.allowed; repeat: true; onTriggered: root.refresh() }
  Timer { interval: 60000; running: root.activated && root.allowed; repeat: true; onTriggered: root.now=root.clock() }
  FileView {
    id: cache
    path:root.cachePath
    atomicWrites: true; printErrors: false
    onLoaded: {
      var parsed=Model.parseReport(text())
      if(!root.report && parsed && parsed.fetchedAt<Date.now()/1000+600) root.report=parsed
    }
  }
  FileView {
    id: locationFile
    path:root.locationPath
    watchChanges:root.allowed; printErrors: false
    onFileChanged: reload()
    onLoaded: root.locationChanged(text())
    onLoadFailed: root.locationChanged("")
  }
  FileView {
    id:nativeSettingsFile
    path:root.preferencesPath
    watchChanges:root.allowed; printErrors: false
    onFileChanged: reload()
    onLoaded: root.nativePreferences=Model.nativeSettings(text())
  }
  Process {
    id: geocode
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.suggestions=Model.parseSuggestions(text,root.searchQuery) }
  }
  Process {
    id: locationSave
    onExited: code => {
      if(code!==0) { root.error="location"; return }
      locationFile.reload()
      root.scheduleRefresh()
    }
  }
}
