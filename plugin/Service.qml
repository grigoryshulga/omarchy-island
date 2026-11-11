// Uses Omarchy's notification sanitizers; see THIRD_PARTY.md.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import qs.Commons
import "Store.js" as Store
import "Security.js" as Security
import "Markup.js" as Markup
import "Model.js" as Model
import "Downloads.js" as Downloads

Item {
  id: root
  property var shell: null
  readonly property alias weather: weatherService
  WeatherService { id: weatherService }
  readonly property alias indicators: indicatorState
  IndicatorState {id:indicatorState}
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
  readonly property string downloadsDir: Quickshell.env("HOME") + "/downloads"
  property var downloads: []
  property int activeDownloads: 0
  property int downloadSequence: 0
  function downloadEvent(data) {
    var event
    try {event=JSON.parse(data)} catch(e) {return}
    if(!event || typeof event!=="object") return
    if(event.event==="active" && Array.isArray(event.files)) {
      var previous=downloads
      var active=event.files.filter(function(f){return f && Downloads.validPath(f.path,root.downloadsDir)}).map(function(f){
        var old=previous.find(function(r){return r.active && r.downloadPath===f.path})
        return Downloads.row(f.path,old ? old.ts : Date.now()/1000,f.bytes,true)
      })
      downloads=active.concat(downloads.filter(function(r){return !r.active}))
      activeDownloads=active.length
      indicatorState.downloading=activeDownloads>0
    } else if(event.event==="complete" && Downloads.validPath(event.path,downloadsDir)) {
      var row=Downloads.row(event.path,Date.now()/1000+(++downloadSequence)/1000000,event.bytes,false)
      var remaining=downloads.filter(function(r){return r.downloadPath!==event.path})
      downloads=remaining.filter(function(r){return r.active}).concat(Downloads.retain([row].concat(remaining.filter(function(r){return !r.active})),downloadsDir,Date.now()/1000))
      if(!doNotDisturb) {
        targetScreen=Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        latest=row;arrival++
      }
      saveSoon.restart()
    }
  }
  function openDownload(row) {
    if(!Downloads.validPath(row.downloadPath,downloadsDir)) return false
    Util.execArgv(["xdg-open",row.downloadPath.substring(0,row.downloadPath.lastIndexOf("/"))])
    if(!row.active) remove(row.key)
    return true
  }
  Process {
    id:downloadWatcher
    running:root.loaded
    command:["python3",String(Qt.resolvedUrl("bin/watch-downloads")).replace(/^file:\/\//,""),root.downloadsDir]
    stdout:SplitParser {onRead:data=>root.downloadEvent(data)}
    onExited:code=>{root.activeDownloads=0;root.downloads=root.downloads.filter(function(r){return !r.active});indicatorState.downloading=false;if(code!==0) root.error="download watcher";downloadRetry.restart()}
  }
  Timer {id:downloadRetry;interval:5000;onTriggered:downloadWatcher.running=true}
  property var entries: []
  readonly property string sessionKey: Date.now().toString(36)
  property var refs: ({})
  property var history: []
  property var mutedSources: []
  property bool doNotDisturb: false
  property bool ready: false
  property bool loaded: false
  property int revision: 0
  property int arrival: 0
  property var latest: null
  property string targetScreen: ""
  property string error: ""
  property var allowedPlayers: ["spotifast", "spotify", "strawberry", "clementine", "lollypop", "amberol", "audacious", "elisa", "tauon", "rhythmbox", "music"]
  property string preferredPlayer: ""
  readonly property var players: (Mpris.players ? Mpris.players.values : []).filter(function(p) { return Model.musicPlayer(p, root.allowedPlayers) })
  readonly property var player: {
    var preferred = players.find(function(p) { return p.dbusName === root.preferredPlayer })
    return preferred || players.find(function(p) { return p.isPlaying }) || players[0] || null
  }
  readonly property bool playing: player !== null && player.isPlaying
  readonly property bool hasMedia: Model.hasMedia(player,MprisPlaybackState.Stopped)
  readonly property string track: player ? player.dbusName + ":" + player.trackTitle + ":" + player.trackArtist : ""
  readonly property var activeEntries: Model.collect(entries, [])
  readonly property var historyEntries: Model.collect([], history)
  readonly property var allEntries: activeEntries.concat(historyEntries)
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/island"

  // One phase keeps the clock and popup on the same braille shimmer frame.
  property real visualPhase: 0
  readonly property bool samplingAudio:root.playing && !Preferences.reduceMotion && Preferences.visualizers.length>0
  NumberAnimation on visualPhase {
    running: root.samplingAudio
    from: 0; to: 86400; duration: 86400000; loops: Animation.Infinite
  }
  property real audioLevel: 0
  property real audioBass: 0
  property real audioTreble: 0
  property bool audioFailed: false
  Behavior on audioLevel { NumberAnimation { duration: Preferences.duration(90) } }
  Behavior on audioBass { NumberAnimation { duration: Preferences.duration(90) } }
  Behavior on audioTreble { NumberAnimation { duration: Preferences.duration(90) } }
  onPlayingChanged: if (!playing) { audioLevel = 0; audioBass = 0; audioTreble = 0 }
  onTrackChanged: audioFailed = false
  Process {
    running: root.samplingAudio && !root.audioFailed
    command: ["python3",String(Qt.resolvedUrl("bin/audio-envelope")).replace(/^file:\/\//, "")]
    stdout: SplitParser {
      onRead: data => {
        try {
          var values = JSON.parse(data)
          if (Array.isArray(values) && values.length === 3) {
            root.audioLevel = Math.max(0,Math.min(1,Number(values[0]) || 0))
            root.audioBass = Math.max(0,Math.min(1,Number(values[1]) || 0))
            root.audioTreble = Math.max(0,Math.min(1,Number(values[2]) || 0))
          }
        } catch(e) {}
      }
    }
    onExited: function(code) { if (code !== 0 && root.samplingAudio) { root.audioFailed = true; root.error = "audio monitor" } }
  }

  function receive(n) {
    n.tracked = true
    var key = Object.keys(refs).find(function(k) { return refs[k] === n }) || "n" + sessionKey + "_" + n.id
    if (!refs[key]) watch(n, key)
    refs[key] = n
    revision++
    var row = Store.snapshot(n, key, NotificationUrgency)
    row.ts = Date.now() / 1000
    row.duration = n.expireTimeout === 0 ? 0 : n.expireTimeout > 0 ? Math.min(n.expireTimeout,300000) : 300000
    // Keep a finite live set, even if a sender never closes its notifications.
    var rest = entries.filter(function(r) { return r.key !== key })
    history = history.filter(function(r) { return r.key !== key })
    entries = [row].concat(rest)
    if (entries.length > Store.LIVE_LIMIT) archive(entries[entries.length-1].key, "expired")
    pruneHistory()
    if (mutedSources.indexOf(Model.source(row)) < 0 && !doNotDisturb) {
      targetScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      latest = row
      arrival++
    }
    saveSoon.restart()
  }
  function watch(n, key) {
    n.closed.connect(function(reason) {
      if (root.refs[key] !== n) return
      delete root.refs[key]
      root.revision++
      if (reason === NotificationCloseReason.CloseRequested) root.remove(key)
      else root.archive(key, reason === NotificationCloseReason.Expired ? "expired" : "dismissed")
    })
    var queued = false
    var refresh = function() {
      queued = false
      if (root.refs[key] === n) root.receive(n)
    }
    var schedule = function() { if (!queued) { queued = true; Qt.callLater(refresh) } }
    ;[n.summaryChanged,n.bodyChanged,n.appNameChanged,n.appIconChanged,n.imageChanged,n.urgencyChanged,n.expireTimeoutChanged,n.hintsChanged,n.actionsChanged].forEach(function(s) { s.connect(schedule) })
  }
  // Keep timed-out objects tracked: senders can still withdraw their history
  // entries after a chat is read. Bound those references to retained history.
  function pruneHistory() {
    history = Store.retain(history, Date.now()/1000)
    var kept = {}
    entries.concat(history).forEach(function(r) { kept[r.key] = true })
    Object.keys(refs).forEach(function(key) {
      if (kept[key]) return
      var n = refs[key]
      delete refs[key]
      revision++
      try { n.expire() } catch(e) {}
    })
  }
  function archive(key, reason) {
    var row = entries.find(function(r) { return r.key === key }) || history.find(function(r) { return r.key === key })
    if (!row) return
    var n = refs[key]
    entries = entries.filter(function(r) { return r.key !== key })
    history = history.filter(function(r) { return r.key !== key })
    if (!row.transient)
      history = Store.addHistory(history, Store.closedEntry(row, reason, Date.now()/1000), Date.now()/1000)
    if (latest && latest.key === key) latest = null
    if (reason !== "expired" || row.transient) {
      delete refs[key]
      revision++
      if (n) { try { reason === "expired" ? n.expire() : n.dismiss() } catch(e) {} }
    }
    pruneHistory()
    saveSoon.restart()
  }
  function remove(key) {
    var n = refs[key]
    delete refs[key]
    revision++
    entries = entries.filter(function(r) { return r.key !== key })
    history = history.filter(function(r) { return r.key !== key })
    downloads = downloads.filter(function(r) { return r.key !== key })
    if (latest && latest.key === key) latest = null
    if (n) { try { n.dismiss() } catch(e) {} }
    saveSoon.restart()
  }
  function clear() {
    entries.slice().forEach(function(r) { root.archive(r.key, "dismissed") })
    latest = null
    saveSoon.restart()
  }
  function clearHistory() {
    history.slice().forEach(function(r) { root.remove(r.key) })
  }
  function mute(source) {
    mutedSources = mutedSources.indexOf(source) < 0 ? mutedSources.concat([source]) : mutedSources.filter(function(s) { return s !== source })
    if (latest && Model.source(latest) === source && mutedSources.indexOf(source) >= 0) latest = null
    saveSoon.restart()
  }
  function setDoNotDisturb(value) {if(doNotDisturb===!!value)return;doNotDisturb=!!value;indicatorState.announceMode("dnd",doNotDisturb);saveSoon.restart()}
  function actions(row) {
    if(row.downloadPath) return [{id:"openFolder",text:"Open folder"}]
    var tick = revision
    var n = refs[row.key]
    if (!n) return []
    return (n.actions || []).slice(0,16).map(function(a) { return {id:a.identifier, text:String(a.text || a.identifier).slice(0,256)} })
  }
  function invoke(row, identifier) {
    if(row.downloadPath) return identifier==="openFolder" ? openDownload(row) : false
    var n = refs[row.key]
    if (!n) return false
    var a = (n.actions || []).find(function(a) { return a.identifier === identifier })
    if (!a) return false
    a.invoke(); archive(row.key, "activated"); return true
  }
  function activate(row) {
    if(row.downloadPath) {openDownload(row);return}
    if (invoke(row,"default")) return
    var argv = Security.parseExecArgv(row.execArgv)
    if (argv) Util.execArgv(argv)
    else if (row.link) Security.openExternalUrl(row.link)
    else if (row.app) Util.execArgv(["omarchy-hyprland-focus-app", row.app])
  }
  function execAction(row, index) {
    var list = Security.parseExecActions(row.execActions) || []
    if (index >= 0 && index < list.length) { Util.execArgv(list[index].argv); archive(row.key,"activated") }
  }
  property string copiedSecret: ""
  function copyCode(row, code) {
    if (String(row.codes || "").split(" ").indexOf(code) < 0) return
    clip.running = false
    clip.command = ["wl-copy", "--sensitive", "--", code]
    clip.running = true
    copiedSecret = code
    secretLife.restart()
  }
  function selectPlayer(name) { preferredPlayer = name }
  function media(action) {
    var p = player
    if (!p) return
    if (action === "next" && p.canGoNext) p.next()
    if (action === "previous" && p.canGoPrevious) p.previous()
    if (action === "toggle" && p.canTogglePlaying) p.togglePlaying()
  }
  function save() {
    if (!loaded) return
    var cutoff = Date.now()/1000 - Store.RETENTION_HOURS*3600
    var rows = allEntries.filter(function(r) { return !r.transient && r.ts > cutoff }).map(function(r) { return Store.closedEntry(r,r.closed_reason || "restart",r.closed_ts || r.ts) })
    rows = Store.retain(rows.sort(function(a,b) { return b.closed_ts-a.closed_ts }), Date.now()/1000)
    stateFile.setText(JSON.stringify({version:1, history:rows, downloads:Downloads.retain(downloads,downloadsDir,Date.now()/1000), muted:mutedSources, dnd:doNotDisturb}))
  }
  function load(text) {
    if (loaded) return
    try {
      if (text.length < 2000000) {
        var data = JSON.parse(text || "{}")
        history = Store.retain(Store.parseHistory(JSON.stringify(data.history || [])),Date.now()/1000)
        mutedSources = Array.isArray(data.muted) ? data.muted.filter(function(s) { return typeof s === "string" && s.length <= 256 }).slice(0,100) : []
        downloads = Downloads.retain(data.downloads || data.recents,downloadsDir,Date.now()/1000)
        doNotDisturb = data.dnd === true
      }
    } catch(e) { error = "state" }
    loaded = true
  }
  NotificationServer {
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    persistenceSupported: true
    onNotification: n => root.receive(n)
  }
  // Presentation expiry archives the card without invalidating the sender ID.
  Timer {
    interval: 1000; repeat: true; running: root.entries.length > 0
    onTriggered: {
      var now = Date.now()/1000
      root.entries.slice().forEach(function(r) {
        var timeout = r.duration
        if (r.urgency !== 2 && timeout > 0 && now-r.ts > timeout/1000) root.archive(r.key,"expired")
      })
    }
  }
  Timer { interval: 60000; repeat: true; running: root.history.length > 0; onTriggered: root.pruneHistory() }
  Process { id: clip; onExited: function(code) { if (code !== 0) root.error = "clipboard" } }
  Timer { id: secretLife; interval: 60000; onTriggered: clipReader.running = true }
  Process {
    id: clipReader
    command: ["wl-paste","--no-newline"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.copiedSecret && text === root.copiedSecret) {
          clip.running = false; clip.command = ["wl-copy","--clear"]; clip.running = true
        }
        root.copiedSecret = ""
      }
    }
  }
  Timer {interval:1000;repeat:true;running:root.loaded && root.downloads.length>0;onTriggered:{var kept=root.downloads.filter(function(r){return r.active || r.ts>Date.now()/1000-1800});if(kept.length!==root.downloads.length) {root.downloads=kept;saveSoon.restart()}}}
  Timer { id: saveSoon; interval: 300; onTriggered: root.save() }
  FileView {
    id: stateFile
    path: root.ready ? root.stateDir + "/state.json" : ""
    atomicWrites: true; printErrors: false
    onLoaded: root.load(text())
    onLoadFailed: root.load("")
    onSaveFailed: root.error = "state"
  }
  Process {
    id: prepare
    command: ["bash","-c",'umask 077; mkdir -p -- "$1" && chmod 700 -- "$1" && touch -- "$1/state.json" && chmod 600 -- "$1/state.json"',"island-state",root.stateDir]
    onExited: function(code) { root.ready = code === 0; if (code !== 0) root.error = "state" }
  }
  Component.onCompleted: prepare.running = true
  Component.onDestruction: save()
  ShellIpc {
    target: "notifications"
    function ping(): string { return "ok" }
    function isDnd(): string { return root.doNotDisturb ? "on" : "off" }
    function toggleDnd(): string { root.setDoNotDisturb(!root.doNotDisturb); return isDnd() }
    function setDnd(value: string): string { root.setDoNotDisturb(/^(true|1|on|yes)$/i.test(value)); return isDnd() }
    function remove(key: string): void { root.remove(key) }
    function count(): string { return String(root.entries.length) }
    function dismissAll(): string { root.clear(); return "ok" }
    function clearHistory(): string { root.clearHistory(); return "ok" }
    function dismissOne(): string { if (root.entries[0]) root.remove(root.entries[0].key); return "ok" }
    function invokeLast(): string { if (root.entries[0]) root.activate(root.entries[0]); return "ok" }
    function act(): string { return invokeLast() }
    function dismiss(summary: string): string { root.allEntries.slice().forEach(function(r) { if(r.summary.indexOf(summary)>=0) root.remove(r.key) }); return "ok" }
    function probe(): string { return JSON.stringify({session:root.sessionKey,stateLoaded:root.loaded,count:root.allEntries.length, live:root.entries.length, muted:root.mutedSources.length, dnd:root.doNotDisturb, player:root.player?root.player.identity:"",playing:root.playing,audioLevel:root.audioLevel,audioFailed:root.audioFailed,error:root.error}) }
  }
}
