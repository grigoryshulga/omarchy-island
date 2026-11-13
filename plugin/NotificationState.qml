// Uses Omarchy's notification sanitizers; see THIRD_PARTY.md.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Commons
import "Store.js" as Store
import "Security.js" as Security
import "Model.js" as Model

Item {
  id:root
  property var host:null
  property bool allowed:true
  property var clock:function(){return Date.now()}
  property var execute:function(argv){Util.execArgv(argv)}
  property var focusedScreen:function(){return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""}
  function openLink(raw) {var url=Security.safeExternalUrl(raw);if(url) execute(["xdg-open",url])}
  property var entries: []
  readonly property string sessionKey: clock().toString(36)
  property var refs: ({})
  property var history: []
  property var mutedSources: []
  property bool doNotDisturb: false
  readonly property bool ready:storage.ready
  property bool loaded: false
  property int revision: 0
  property int arrival: 0
  property var latest: null
  property string targetScreen: ""
  property string error: ""
  readonly property var activeEntries: Model.collect(entries, [])
  readonly property var historyEntries: Model.collect([], history)
  readonly property var allEntries: activeEntries.concat(historyEntries)
  property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/island"

  function receive(n) {
    if(!allowed) return
    n.tracked = true
    var key = Object.keys(refs).find(function(k) { return refs[k] === n }) || "n" + sessionKey + "_" + n.id
    if (!refs[key]) watch(n, key)
    refs[key] = n
    revision++
    var row = Store.snapshot(n, key, NotificationUrgency)
    row.ts = clock() / 1000
    row.duration = n.expireTimeout === 0 ? 0 : n.expireTimeout > 0 ? Math.min(n.expireTimeout,300000) : 300000
    // Keep a finite live set, even if a sender never closes its notifications.
    var rest = entries.filter(function(r) { return r.key !== key })
    history = history.filter(function(r) { return r.key !== key })
    entries = [row].concat(rest)
    if (entries.length > Store.LIVE_LIMIT) archive(entries[entries.length-1].key, "expired")
    pruneHistory()
    if (mutedSources.indexOf(Model.source(row)) < 0 && !doNotDisturb) {
      targetScreen = focusedScreen()
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
    history = Store.retain(history, clock()/1000)
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
      history = Store.addHistory(history, Store.closedEntry(row, reason, clock()/1000), clock()/1000)
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
  function setDoNotDisturb(value) {if(doNotDisturb===!!value)return;doNotDisturb=!!value;if(host && host.indicators) host.indicators.announceMode("dnd",doNotDisturb);saveSoon.restart()}
  function actions(row) {
    if(!allowed) return []
    var tick = revision
    var n = refs[row.key]
    if (!n) return []
    return (n.actions || []).slice(0,16).map(function(a) { return {id:a.identifier, text:String(a.text || a.identifier).slice(0,256)} })
  }
  function invoke(row, identifier) {
    if(!allowed) return false
    var n = refs[row.key]
    if (!n) return false
    var a = (n.actions || []).find(function(a) { return a.identifier === identifier })
    if (!a) return false
    a.invoke(); archive(row.key, "activated"); return true
  }
  function activate(row) {
    if(!allowed) return
    if (invoke(row,"default")) return
    var argv = Security.parseExecArgv(row.execArgv)
    if (argv) execute(argv)
    else if (row.link) openLink(row.link)
    else if (row.app) execute(["omarchy-hyprland-focus-app", row.app])
  }
  function execAction(row, index) {
    if(!allowed) return
    var list = Security.parseExecActions(row.execActions) || []
    if (index >= 0 && index < list.length) { execute(list[index].argv); archive(row.key,"activated") }
  }
  property string copiedSecret: ""
  function copyCode(row, code) {
    if(!allowed) return
    if (String(row.codes || "").split(" ").indexOf(code) < 0) return
    clip.running = false
    clip.command = ["wl-copy", "--sensitive", "--", code]
    clip.running = true
    copiedSecret = code
    secretLife.restart()
  }
  function save() {
    if (!loaded) return
    var cutoff = clock()/1000 - Store.RETENTION_HOURS*3600
    var rows = allEntries.filter(function(r) { return !r.transient && r.ts > cutoff }).map(function(r) { return Store.closedEntry(r,r.closed_reason || "restart",r.closed_ts || r.ts) })
    rows = Store.retain(rows.sort(function(a,b) { return b.closed_ts-a.closed_ts }), clock()/1000)
    storage.save({version:1, history:rows, muted:mutedSources, dnd:doNotDisturb})
  }
  function load(data) {
    if(loaded) return
    history=Store.retain(Store.parseHistory(JSON.stringify(data.history || [])),clock()/1000)
    mutedSources=Array.isArray(data.muted) ? data.muted.filter(function(s){return typeof s==="string" && s.length<=256}).slice(0,100) : []
    doNotDisturb=data.dnd===true
    loaded=true
    // Sanitize legacy history before publishing the independent store.
    save()
  }
  Loader {
    active:root.allowed
    sourceComponent:Component { NotificationServer {
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    persistenceSupported: true
    onNotification: n => root.receive(n)
  } }
  }
  // Presentation expiry archives the card without invalidating the sender ID.
  Timer {
    interval: 1000; repeat: true; running: root.allowed && root.entries.length > 0
    onTriggered: {
      var now = clock()/1000
      root.entries.slice().forEach(function(r) {
        var timeout = r.duration
        if (r.urgency !== 2 && timeout > 0 && now-r.ts > timeout/1000) root.archive(r.key,"expired")
      })
    }
  }
  Timer { interval: 60000; repeat: true; running: root.allowed && root.history.length > 0; onTriggered: root.pruneHistory() }
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
  property alias storageCommand:storage.prepareCommand
  ModuleStorage {
    id:storage;enabled:root.allowed
    clock:function(){return root.clock()/1000}
    path:root.stateDir+"/notifications.json";legacyPath:root.stateDir+"/state.json"
    onLoaded:(text,status)=>root.load(JSON.parse(text))
    onErrorChanged:if(error || root.error==="state") root.error=error
  }
  onAllowedChanged: {
    if(!allowed) {
      entries.slice().forEach(function(row){root.archive(row.key,"disabled")})
      save();saveSoon.stop();clip.running=false;secretLife.stop()
      clipReader.running=!!copiedSecret
      refs=({});entries=[];latest=null;revision++
    }
  }
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
    function probe(): string { return JSON.stringify({session:root.sessionKey,stateLoaded:root.loaded,count:root.allEntries.length, live:root.entries.length, muted:root.mutedSources.length, dnd:root.doNotDisturb, player:root.host && root.host.player ? root.host.player.identity:"",playing:root.host ? root.host.playing : false,audioLevel:root.host ? root.host.audioLevel : 0,audioFailed:root.host ? root.host.audioFailed : false,error:root.error}) }
  }
}
