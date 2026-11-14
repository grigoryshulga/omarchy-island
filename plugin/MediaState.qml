import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "Model.js" as Model
import "MusicVisual.js" as MusicVisual

Item {
  id:root
  property bool allowed:true
  property string error:""
  property var audioCommand:["python3",String(Qt.resolvedUrl("bin/audio-envelope")).replace(/^file:\/\//,"")]
  // An empty filter accepts every MPRIS source, including browsers and video.
  property var allowedPlayers: []
  property string preferredPlayer: ""
  readonly property var players: !allowed ? [] : (Mpris.players ? Mpris.players.values : []).filter(function(p) { return Model.mediaPlayer(p, root.allowedPlayers) })
  readonly property var player: Model.selectMediaPlayer(players, preferredPlayer, MprisPlaybackState.Stopped)
  readonly property bool playing: player !== null && player.isPlaying
  readonly property bool hasMedia: Model.hasMedia(player,MprisPlaybackState.Stopped)
  readonly property string track: player ? player.dbusName + ":" + player.trackTitle + ":" + player.trackArtist : ""
  // One phase keeps the clock and popup on the same braille shimmer frame.
  property real visualPhase: 0
  readonly property bool samplingAudio:root.allowed && root.playing && !Preferences.reduceMotion && Preferences.visualizers.length>0
  NumberAnimation on visualPhase {
    running: root.samplingAudio
    from: 0; to: 86400; duration: 86400000; loops: Animation.Infinite
  }
  property var visualImpulses: MusicVisual.empty()
  onSamplingAudioChanged: visualImpulses = MusicVisual.empty()
  property real audioLevel: 0
  property real audioBass: 0
  property real audioTreble: 0
  property bool audioFailed: false
  Behavior on audioLevel { NumberAnimation { duration: Preferences.duration(90) } }
  Behavior on audioBass { NumberAnimation { duration: Preferences.duration(90) } }
  Behavior on audioTreble { NumberAnimation { duration: Preferences.duration(90) } }
  onPlayingChanged: if (!playing) { audioLevel = 0; audioBass = 0; audioTreble = 0 }
  onTrackChanged: { audioFailed = false; visualImpulses = MusicVisual.empty() }
  Process {
    running: root.samplingAudio && !root.audioFailed
    command:root.audioCommand
    stdout: SplitParser {
      onRead: data => {
        try {
          var values = JSON.parse(data)
          if (Array.isArray(values) && values.length === 3) {
            root.visualImpulses = MusicVisual.sample(root.visualImpulses, root.visualPhase, Number(values[0]) || 0, Number(values[1]) || 0)
            root.audioLevel = Math.max(0,Math.min(1,Number(values[0]) || 0))
            root.audioBass = Math.max(0,Math.min(1,Number(values[1]) || 0))
            root.audioTreble = Math.max(0,Math.min(1,Number(values[2]) || 0))
          }
        } catch(e) {}
      }
    }
    onExited: function(code) { if (code !== 0 && root.samplingAudio) { root.audioFailed = true; root.error = "audio monitor" } }
  }

  function selectPlayer(name) { preferredPlayer = name }
  function media(action) {
    var p = player
    if (!p) return
    if (action === "next" && p.canGoNext) p.next()
    if (action === "previous" && p.canGoPrevious) p.previous()
    if (action === "toggle" && p.canTogglePlaying) p.togglePlaying()
  }
}
