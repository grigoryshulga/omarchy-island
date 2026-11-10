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

Item {
  id: root
  property var shell: null
  readonly property alias weather: weatherService
  WeatherService { id: weatherService }
  readonly property alias indicators: indicatorState
  IndicatorState {id:indicatorState}
  ShellIpc {
    target: "island-osd"
    function show(payload: string): string {return indicatorState.showOsd(payload) ? "ok" : "unavailable"}
    function hide(): string {indicatorState.hideOsd();return "ok"}
  }
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
  readonly property var allEntries: Model.collect(entries, history)
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/island"

  // One phase keeps the clock and popup on the same braille shimmer frame.
  property real visualPhase: 0
  NumberAnimation on visualPhase {
    running: root.playing && !Style.reduceMotion
    from: 0; to: 86400; duration: 86400000; loops: Animation.Infinite
  }
  property real audioLevel: 0
  property real audioBass: 0
  property real audioTreble: 0
  property bool audioFailed: false
  Behavior on audioLevel { NumberAnimation { duration: Style.duration(90) } }
  Behavior on audioBass { NumberAnimation { duration: Style.duration(90) } }
  Behavior on audioTreble { NumberAnimation { duration: Style.duration(90) } }
  onPlayingChanged: if (!playing) { audioLevel = 0; audioBass = 0; audioTreble = 0 }
  onTrackChanged: audioFailed = false
  Process {
    running: root.playing && !Style.reduceMotion && !root.audioFailed
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
    onExited: function(code) { if (code !== 0 && root.playing) { root.audioFailed = true; root.error = "audio monitor" } }
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
    if (rest.length >= 99) archive(rest.pop().key, "expired")
    entries = [row].concat(rest)
    if (mutedSources.indexOf(Model.source(row)) < 0 && !doNotDisturb) {
      targetScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      latest = row
      arrival++
    }
    saveSoon.restart()
  }
  function watch(n, key) {
    n.closed.connect(function() {
      if (root.refs[key] !== n) return
      delete root.refs[key]
      root.revision++
      root.archive(key, "closed")
    })
    var queued = false
    var refresh = function() {
      queued = false
      if (root.refs[key] === n) root.receive(n)
    }
    var schedule = function() { if (!queued) { queued = true; Qt.callLater(refresh) } }
    ;[n.summaryChanged,n.bodyChanged,n.appNameChanged,n.appIconChanged,n.imageChanged,n.urgencyChanged,n.expireTimeoutChanged,n.hintsChanged,n.actionsChanged].forEach(function(s) { s.connect(schedule) })
  }
  function archive(key, reason) {
    var row = entries.find(function(r) { return r.key === key })
    if (!row) return
    var n = refs[key]
    delete refs[key]
    revision++
    entries = entries.filter(function(r) { return r.key !== key })
    history = Store.addHistory(history.filter(function(r) { return r.key !== key }), Store.closedEntry(row, reason, Date.now()/1000), Date.now()/1000)
    if (n) { try { reason === "expired" ? n.expire() : n.dismiss() } catch(e) {} }
    saveSoon.restart()
  }
  function remove(key) {
    archive(key, "dismissed")
    history = history.filter(function(r) { return r.key !== key })
    if (latest && latest.key === key) latest = null
    saveSoon.restart()
  }
  function clear() {
    entries.slice().forEach(function(r) { root.archive(r.key, "dismissed") })
    history = []; latest = null
    saveSoon.restart()
  }
  function mute(source) {
    mutedSources = mutedSources.indexOf(source) < 0 ? mutedSources.concat([source]) : mutedSources.filter(function(s) { return s !== source })
    if (latest && Model.source(latest) === source && mutedSources.indexOf(source) >= 0) latest = null
    saveSoon.restart()
  }
  function setDoNotDisturb(value) { doNotDisturb = !!value; saveSoon.restart() }
  function actions(row) {
    var tick = revision
    var n = refs[row.key]
    if (!n) return []
    return (n.actions || []).slice(0,16).map(function(a) { return {id:a.identifier, text:String(a.text || a.identifier).slice(0,256)} })
  }
  function invoke(row, identifier) {
    var n = refs[row.key]
    if (!n) return false
    var a = (n.actions || []).find(function(a) { return a.identifier === identifier })
    if (!a) return false
    a.invoke(); archive(row.key, "activated"); return true
  }
  function activate(row) {
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
    var rows = allEntries.filter(function(r) { return r.ts > cutoff }).map(function(r) { return Store.closedEntry(r,"history",r.closed_ts || r.ts) })
    stateFile.setText(JSON.stringify({version:1, history:rows, muted:mutedSources, dnd:doNotDisturb}))
  }
  function load(text) {
    if (loaded) return
    try {
      if (text.length < 2000000) {
        var data = JSON.parse(text || "{}")
        history = Store.retain(Store.parseHistory(JSON.stringify(data.history || [])),Date.now()/1000)
        mutedSources = Array.isArray(data.muted) ? data.muted.filter(function(s) { return typeof s === "string" && s.length <= 256 }).slice(0,100) : []
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
  // Expiry closes the sender but retains a redacted history snapshot.
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
    function dismissOne(): string { if (root.entries[0]) root.remove(root.entries[0].key); return "ok" }
    function invokeLast(): string { if (root.entries[0]) root.activate(root.entries[0]); return "ok" }
    function act(): string { return invokeLast() }
    function dismiss(summary: string): string { root.allEntries.slice().forEach(function(r) { if(r.summary.indexOf(summary)>=0) root.remove(r.key) }); return "ok" }
    function probe(): string { return JSON.stringify({session:root.sessionKey,stateLoaded:root.loaded,count:root.allEntries.length, live:root.entries.length, muted:root.mutedSources.length, dnd:root.doNotDisturb, player:root.player?root.player.identity:"",playing:root.playing,audioLevel:root.audioLevel,audioFailed:root.audioFailed,error:root.error}) }
  }
}
