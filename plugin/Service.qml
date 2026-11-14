import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

Item {
  id:root
  property var shell: null
  property var moduleStateProperties:({})
  ModuleRegistry {id:moduleRegistry;stateProperties:root.moduleStateProperties;host:root}
  readonly property var modules:moduleRegistry.backends
  // Existing activity/IPC consumers retain their established names.
  readonly property var t3:modules.t3 || null
  property var latestT3:null
  property string t3TargetScreen:""
  property string activeAppId:ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.appId : ""
  readonly property bool t3Focused:activeAppId.toLowerCase()==="com.t3tools.t3code"
  onT3FocusedChanged:if(t3Focused) latestT3=null
  signal t3Arrival()
  Connections {
    target:root.t3
    function onActivityChanged(session) {
      if(root.doNotDisturb || root.t3Focused) return
      root.t3TargetScreen=Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      root.latestT3=session
      root.t3Arrival()
    }
  }
  readonly property alias indicators: indicatorState
  IndicatorState {id:indicatorState;downloading:root.activeDownloads>0}
  DictationState {id:dictationState;active:indicatorState.consumers.length>0}
  readonly property alias dictation:dictationState
  ShellIpc {
    target: "island-update"
    function refresh(): void {indicatorState.refreshUpdate()}
    function clear(): void {indicatorState.clearUpdate()}
  }
  ShellIpc {
    target: "island-osd"
    function show(payload: string): string {return indicatorState.showOsd(payload) ? "ok" : "unavailable"}
    function hide(): string {indicatorState.hideOsd();return "ok"}
  }
  readonly property var notifications:modules.notifications || null
  readonly property var downloadsState:modules.downloads || null
  // Cross-module presentation belongs to the host, not either backend.
  property var latestDownload:null
  property bool downloadAlert:false
  property string downloadTargetScreen:""
  property int arrival:0
  Connections {
    target:root.downloadsState
    function onCompleted(row) {
      if(root.doNotDisturb) return
      root.latestDownload=row
      root.downloadAlert=true
      root.downloadTargetScreen=Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      root.arrival++
    }
    function onLatestChanged(){if(!root.downloadsState.latest) root.latestDownload=null}
    function onAllowedChanged(){if(!root.downloadsState.allowed) root.latestDownload=null}
  }
  Connections {
    target:root.notifications
    function onArrivalChanged(){root.downloadAlert=false;root.latestDownload=null;root.arrival++}
  }
  onDoNotDisturbChanged:if(doNotDisturb) latestDownload=null
  readonly property var mediaState:modules.media || null
  readonly property var weather:modules.weather || null
  readonly property var calendars:modules.calendar ? modules.calendar.calendars : null
  readonly property var reminders:modules.calendar ? modules.calendar.reminders : null
  readonly property var entries:notifications ? notifications.entries : []
  readonly property var history:notifications ? notifications.history : []
  readonly property var refs:notifications ? notifications.refs : ({})
  readonly property var sessionKey:notifications ? notifications.sessionKey : ""
  readonly property var mutedSources:notifications ? notifications.mutedSources : []
  readonly property var doNotDisturb:notifications ? notifications.doNotDisturb : false
  readonly property var ready:notifications ? notifications.ready : false
  readonly property var loaded:notifications ? notifications.loaded : false
  readonly property var latest:downloadAlert ? latestDownload : (notifications ? notifications.latest : null)
  readonly property var targetScreen:downloadAlert ? downloadTargetScreen : (notifications ? notifications.targetScreen : "")
  readonly property string error:moduleRegistry.error
  readonly property var activeEntries:notifications ? notifications.activeEntries : []
  readonly property var historyEntries:notifications ? notifications.historyEntries : []
  readonly property var allEntries:notifications ? notifications.allEntries : []
  readonly property var downloads:downloadsState ? downloadsState.downloads : []
  readonly property var downloadsDir:downloadsState ? downloadsState.downloadsDir : ""
  readonly property var activeDownloads:downloadsState ? downloadsState.activeDownloads : 0
  readonly property var players:mediaState ? mediaState.players : []
  readonly property var player:mediaState ? mediaState.player : null
  readonly property var playing:mediaState ? mediaState.playing : false
  readonly property var hasMedia:mediaState ? mediaState.hasMedia : false
  readonly property var track:mediaState ? mediaState.track : ""
  readonly property var visualPhase:mediaState ? mediaState.visualPhase : 0
  readonly property var visualImpulses:mediaState ? mediaState.visualImpulses : null
  readonly property var audioLevel:mediaState ? mediaState.audioLevel : 0
  readonly property var audioBass:mediaState ? mediaState.audioBass : 0
  readonly property var audioTreble:mediaState ? mediaState.audioTreble : 0
  readonly property var audioFailed:mediaState ? mediaState.audioFailed : false
  function setDoNotDisturb(value) {return notifications ? notifications.setDoNotDisturb(value) : undefined}
  function remove(key) {if(downloadsState && downloads.some(function(row){return row.key===key})) return downloadsState.remove(key);return notifications ? notifications.remove(key) : undefined}
  function clear() {return notifications ? notifications.clear() : undefined}
  function clearHistory() {return notifications ? notifications.clearHistory() : undefined}
  function mute(source) {return notifications ? notifications.mute(source) : undefined}
  function actions(row) {if(row.downloadPath) return downloadsState && downloadsState.allowed ? [{id:"openFolder",text:"Open folder"}] : [];return notifications ? notifications.actions(row) : []}
  function invoke(row,identifier) {if(row.downloadPath) return identifier==="openFolder" && openDownload(row);return notifications ? notifications.invoke(row,identifier) : false}
  function activate(row) {if(row.downloadPath) return openDownload(row);return notifications ? notifications.activate(row) : undefined}
  function execAction(row,index) {return notifications ? notifications.execAction(row,index) : undefined}
  function copyCode(row,code) {return notifications ? notifications.copyCode(row,code) : undefined}
  function save() {return notifications ? notifications.save() : undefined}
  function pruneHistory() {return notifications ? notifications.pruneHistory() : undefined}
  function media(action) {if(mediaState) mediaState.media(action)}
  function selectPlayer(name) {if(mediaState) mediaState.selectPlayer(name)}
  function downloadEvent(data) {if(downloadsState) downloadsState.downloadEvent(data)}
  function openDownload(row) {return downloadsState ? downloadsState.openDownload(row) : false}
}
