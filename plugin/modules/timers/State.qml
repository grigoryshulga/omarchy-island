import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "../.." as Island
import "Time.mjs" as Time

Item {
  id: root
  readonly property bool allowed: true
  readonly property bool ready: storage.ready
  readonly property string error: storage.error
  property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME")+"/.local/state")+"/omarchy/island"
  property var clock: function(){return Date.now()}
  property var execute: function(argv){Util.execArgv(argv)}
  property double now: clock()
  property var records: ({timer:Time.initial(), pomodoro:Time.initial(), stopwatch:Time.initial()})
  readonly property string activeMode: Time.modes.find(mode => records[mode].status === "running") || ""

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("../../i18n") }
  function replace(mode, record) {
    var next = Object.assign({}, records)
    next[mode] = record
    records = next
    storage.save({version:1, records:next})
  }
  function refresh() {
    now = clock()
    for (var mode of ["timer","pomodoro"]) {
      var state = records[mode]
      if (state.status !== "running" || Time.elapsed(state,now) < Time.limit(mode,state)) continue
      replace(mode,Time.complete(mode,state))
      var key = mode === "timer" ? "timerDone" : Time.phase(state.step) === "focus" ? "focusDone" : "breakDone"
      execute(["omarchy-notification-send","--app-name","Island","-u","normal",strings.t("timers."+key)])
    }
  }
  function toggle(mode, duration) {
    if (!ready || !Time.modes.includes(mode)) return
    var state = records[mode]
    refresh()
    if (state !== records[mode]) return
    if (state.status === "running") {replace(mode,Time.pause(state,now)); return}
    if (mode === "timer" && state.status !== "paused") {
      if (!Number.isInteger(duration) || duration < 1000 || duration > 86400000) return
      state = Object.assign({}, state, {duration:duration})
    }
    replace(mode,Time.start(state,now))
  }
  function reset(mode) {
    if (ready && Time.modes.includes(mode)) replace(mode,Object.assign(Time.initial(),{duration:records[mode].duration}))
  }
  Timer { interval: 1000; repeat: true; running: root.ready && !!root.activeMode; onTriggered: root.refresh() }
  Island.ModuleStorage {
    id: storage
    path: root.stateDir+"/timers.json"; legacyPath: ""
    onLoaded: (text,status) => {
      var saved = JSON.parse(text)
      var data = saved.version === 1 && saved.records || {}
      root.records = {timer:Time.restore(data.timer), pomodoro:Time.restore(data.pomodoro), stopwatch:Time.restore(data.stopwatch)}
      root.refresh()
    }
  }
}
