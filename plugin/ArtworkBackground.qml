import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
  id: root
  required property var service
  property bool monochrome: false
  property bool horizontalFade: false
  property real reveal: 1
  property real artworkReveal: Math.max(0,Math.min(1,reveal))
  Behavior on artworkReveal { NumberAnimation { duration: Preferences.duration(280); easing.type: Easing.OutCubic } }
  readonly property real phase: service ? service.visualPhase : 0
  readonly property bool active: service !== null && service.hasMedia && service.playing && Preferences.visualizationAllowed(horizontalFade)
  readonly property bool sampling:active && visible && opacity>0 && reveal>0 && !Preferences.reduceMotion
  onSamplingChanged:Preferences.watchVisualizer(root,sampling)
  Component.onCompleted:Preferences.watchVisualizer(root,sampling)
  Component.onDestruction:Preferences.watchVisualizer(root,false)
  clip: true
  layer.enabled: true
  layer.effect: ShaderEffect {
    property real horizontal: root.horizontalFade ? 1 : 0
    property vector2d size: Qt.vector2d(root.width,root.height)
    property real cornerRadius: root.horizontalFade ? 0 : Style.cornerRadius
    vertexShader: Qt.resolvedUrl("shaders/fade.vert.qsb")
    fragmentShader: Qt.resolvedUrl("shaders/fade.frag.qsb")
  }
  opacity: active ? 0.7 : 0
  Behavior on opacity { NumberAnimation { duration: Preferences.duration(180); easing.type: Easing.OutCubic } }
  Image {
    id: artwork
    anchors.fill: parent
    source: !root.monochrome && root.service && root.service.player && root.service.player.trackArtUrl
      ? root.service.player.trackArtUrl : Qt.resolvedUrl("assets/dot-field.svg")
    sourceSize: Qt.size(240,240)
    fillMode: Image.PreserveAspectCrop
    verticalAlignment: Image.AlignTop
    asynchronous: true
    visible: false
    layer.enabled: true
    layer.smooth: true
  }
  ShaderEffect {
    anchors.fill: parent
    property var source: artwork
    property vector2d size: Qt.vector2d(width,height)
    property real phase: Preferences.reduceMotion ? 0 : root.phase
    property real level: root.service ? root.service.audioLevel : 0
    property real bass: root.service ? root.service.audioBass : 0
    property real treble: root.service ? root.service.audioTreble : 0
    property color accent: Commons.Color.accent
    property real monochrome: root.monochrome ? 1 : 0
    property real reveal: root.horizontalFade ? 1 : root.artworkReveal
    vertexShader: Qt.resolvedUrl("shaders/braille.vert.qsb")
    fragmentShader: Qt.resolvedUrl("shaders/braille.frag.qsb")
  }
}
