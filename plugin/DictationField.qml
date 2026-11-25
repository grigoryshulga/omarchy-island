import QtQuick
import qs.Commons
import "Dictation.js" as Model

Item {
  id: root
  property real peak: 0
  property bool processing: false
  property bool active: false
  property real reveal: 1
  readonly property bool still: Preferences.reduceMotion
  readonly property bool moving: active && visible && !still
  readonly property bool flowing: moving && (energy>0 || processing || morph>0)
  readonly property real morph: still ? (processing ? 1 : 0) : animatedMorph
  readonly property real phase: still ? 0 : animatedPhase
  readonly property real energy: still ? 0 : smoothedEnergy
  readonly property real voiceEnergy: Model.voiceStrength(peak)
  readonly property bool inputOnLeft: !I18n.rightToLeft
  // Fit whole braille cells while keeping a single pitch across their boundaries.
  readonly property int pixel: Math.max(1,Math.min(Style.space(1),Math.floor(height/24)))
  readonly property int pitch: 3*pixel
  readonly property int columns: 2*Math.floor(width/(2*pitch))
  readonly property int rows: 4*Math.floor(height/(4*pitch))
  readonly property bool software: GraphicsInfo.api===GraphicsInfo.Software
  readonly property real processingTint: 0.62*morph
  readonly property color waveColor: Qt.rgba(
    Design.accent.r+(Design.info.r-Design.accent.r)*processingTint,
    Design.accent.g+(Design.info.g-Design.accent.g)*processingTint,
    Design.accent.b+(Design.info.b-Design.accent.b)*processingTint,1)
  Accessible.ignored: true

  property real smoothedEnergy: 0
  Binding on smoothedEnergy {
    when: root.moving && !root.processing
    value: root.voiceEnergy
    restoreMode: Binding.RestoreNone
  }
  Behavior on smoothedEnergy {
    enabled: root.moving
    NumberAnimation {duration: Preferences.duration(root.voiceEnergy>0 ? 65 : 155); easing.type: Easing.OutCubic}
  }
  property real animatedMorph: processing ? 1 : 0
  Behavior on animatedMorph {
    enabled: root.moving
    NumberAnimation {duration: Preferences.duration(240); easing.type: Easing.OutCubic}
  }
  property real animatedPhase: 0
  NumberAnimation on animatedPhase {
    running: root.flowing
    from: 0
    to: 2*Math.PI
    duration: Preferences.duration(4200)
    loops: Animation.Infinite
  }

  Loader {
    anchors.fill: parent
    active: !root.software
    sourceComponent: ShaderEffect {
      property vector2d size: Qt.vector2d(width,height)
      property vector2d grid: Qt.vector2d(root.columns,root.rows)
      property real pixel: root.pixel
      property real morph: root.morph
      property real phase: root.phase
      property real energy: root.energy
      property real inputOnLeft: root.inputOnLeft ? 1 : 0
      property real reveal: root.reveal
      property color accent: root.waveColor
      property color highlight: Design.text
      vertexShader: Qt.resolvedUrl("shaders/dictation.vert.qsb")
      fragmentShader: Qt.resolvedUrl("shaders/dictation.frag.qsb")
    }
  }

  Loader {
    anchors.fill: parent
    active: root.software
    sourceComponent: Canvas {
      readonly property color accent: root.waveColor
      readonly property color highlight: Design.text
      readonly property var frame: [root.pixel,root.columns,root.rows,root.inputOnLeft,root.energy,
                                    root.phase,root.morph,root.reveal,accent,highlight]
      onFrameChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx=getContext("2d")
        ctx.clearRect(0,0,width,height)
        if(!root.columns || !root.rows || root.reveal<=0) return
        var pixel=root.pixel, pitch=root.pitch, side=2*pixel
        var left=Math.floor((width-root.columns*pitch+pixel)/2)
        var top=Math.floor((height-root.rows*pitch+pixel)/2)
        var centerY=top+(root.rows*pitch-pixel)/2
        for(var column=0;column<root.columns;column++) {
          var x=left+column*pitch
          var position=(x+pixel)/width
          var u=root.inputOnLeft ? 1-position : position
          var wave=Model.waveAt(u,root.energy,root.phase,root.morph,root.reveal,pitch/height)
          for(var row=0;row<root.rows;row++) {
            var y=top+row*pitch
            var heightPosition=(y+pixel-centerY)/height
            var ink=Model.waveInk(heightPosition,wave)
            if(ink<=0) continue
            var shine=0.12+(0.30+0.42*wave.definition+0.17*wave.sweep)*Model.waveEdge(heightPosition,wave)
            ctx.fillStyle=Qt.rgba(accent.r+(highlight.r-accent.r)*shine,
                                  accent.g+(highlight.g-accent.g)*shine,
                                  accent.b+(highlight.b-accent.b)*shine,ink)
            ctx.fillRect(x,y,side,side)
          }
        }
      }
    }
  }
}
