import QtQuick
import qs.Commons
import "Dictation.js" as Model

Item {
  id: root
  property var history: Model.empty()
  property bool processing: false
  property bool active: false
  property real reveal: 1
  readonly property bool still: Preferences.reduceMotion
  readonly property bool moving: active && visible && !still
  readonly property bool sampling: moving && !processing
  readonly property bool flowing: moving && (processing || morph>0 || samples!==null)
  readonly property real morph: still ? (processing ? 1 : 0) : animatedMorph
  readonly property real phase: still ? 0 : animatedPhase
  readonly property bool inputOnLeft: !I18n.rightToLeft
  readonly property real pitch: Style.space(3)
  readonly property int columns: Math.floor(width/pitch)
  // Keep a row of pixels centered on the quiet ribbon.
  readonly property int rows: Math.max(0,2*Math.floor((height/pitch-1)/2)+1)
  readonly property bool software: GraphicsInfo.api===GraphicsInfo.Software
  Accessible.ignored: true

  readonly property var silence: Model.empty()
  property var samples: null
  Binding on samples {
    when: root.sampling
    value: Model.hasSignal(root.history) ? root.history : null
    restoreMode: Binding.RestoreNone
  }
  onSamplesChanged: if(sampling && samples!==null) sampleScroll.restart()
  onSamplingChanged: if(!sampling) sampleScroll.stop()
  property real sampleOffset: 0
  NumberAnimation {
    id: sampleScroll
    target: root
    property: "sampleOffset"
    from: 1
    to: 0
    duration: Preferences.duration(45)
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
    duration: Preferences.duration(3800)
    loops: Animation.Infinite
  }

  Loader {
    anchors.fill: parent
    active: !root.software
    sourceComponent: ShaderEffect {
      property vector2d size: Qt.vector2d(width,height)
      property vector2d grid: Qt.vector2d(root.columns,root.rows)
      property real pitch: root.pitch
      property real morph: root.morph
      property real phase: root.phase
      property real inputOnLeft: root.inputOnLeft ? 1 : 0
      property real reveal: root.reveal
      property real sampleOffset: root.sampleOffset
      property real still: root.still ? 1 : 0
      property matrix4x4 samplesA: Model.matrix(root.samples || root.silence,16)
      property matrix4x4 samplesB: Model.matrix(root.samples || root.silence,32)
      property color accent: Design.accent
      property color highlight: Design.text
      vertexShader: Qt.resolvedUrl("shaders/dictation.vert.qsb")
      fragmentShader: Qt.resolvedUrl("shaders/dictation.frag.qsb")
    }
  }

  Loader {
    anchors.fill: parent
    active: root.software
    sourceComponent: Canvas {
      readonly property color accent: Design.accent
      readonly property color highlight: Design.text
      readonly property var frame: [root.pitch,root.columns,root.rows,root.inputOnLeft,root.still,root.samples,
                                    root.sampleOffset,root.phase,root.morph,root.reveal,accent,highlight]
      onFrameChanged: requestPaint()
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx=getContext("2d")
        ctx.clearRect(0,0,width,height)
        if(!root.columns || !root.rows) return
        var pitch=root.pitch, tile=pitch*0.78
        var left=(width-root.columns*pitch)/2, top=(height-root.rows*pitch)/2
        for(var column=0;column<root.columns;column++) {
          var x=left+(column+0.5)*pitch
          var u=root.inputOnLeft ? 1-x/width : x/width
          var peak=root.still || !root.samples || root.morph===1 ? 0 : Model.samplePeak(root.samples,u,root.sampleOffset)
          var ribbon=Model.ribbonAt(u,peak,root.phase,root.morph,root.reveal)
          if(ribbon.opacity<=0) continue
          for(var row=0;row<root.rows;row++) {
            var y=top+(row+0.5)*pitch
            var depth=y/height-0.5-ribbon.center
            var ink=Model.ribbonInk(depth,ribbon)
            if(ink<=0) continue
            var shine=Model.ribbonShine(depth,ribbon)
            ctx.fillStyle=Qt.rgba(accent.r+(highlight.r-accent.r)*shine,
                                  accent.g+(highlight.g-accent.g)*shine,
                                  accent.b+(highlight.b-accent.b)*shine,
                                  ink*ribbon.opacity*(0.52+0.48*shine))
            ctx.fillRect(x-tile/2,y-tile/2,tile,tile)
          }
        }
      }
    }
  }
}
