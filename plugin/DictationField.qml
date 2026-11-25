import QtQuick
import qs.Commons
import "Dictation.js" as Model

Item {
  id: root
  property var history: Model.empty()
  property bool processing: false
  property bool active: false
  readonly property bool still: Preferences.reduceMotion
  readonly property real morph: still ? (processing ? 1 : 0) : animatedMorph
  readonly property real phase: still ? 0 : animatedPhase
  readonly property real cellSize: Style.space(9)
  readonly property bool software: GraphicsInfo.api===GraphicsInfo.Software
  Accessible.ignored: true

  property real animatedMorph: processing ? 1 : 0
  Behavior on animatedMorph {
    enabled: root.active && !root.still
    NumberAnimation {duration: Preferences.duration(300); easing.type: Easing.InOutCubic}
  }
  property real animatedPhase: 0
  NumberAnimation on animatedPhase {
    running: root.active && !root.still
    from: 0; to: 2*Math.PI; duration: 15000; loops: Animation.Infinite
  }

  Loader {
    anchors.fill: parent
    active: !root.software
    sourceComponent: ShaderEffect {
      property vector2d size: Qt.vector2d(width,height)
      property real cellSize: root.cellSize
      property real morph: root.morph
      property real phase: root.phase
      property real still: root.still ? 1 : 0
      property matrix4x4 samplesA: root.still ? Qt.matrix4x4() : Model.matrix(root.history,0)
      property matrix4x4 samplesB: root.still ? Qt.matrix4x4() : Model.matrix(root.history,16)
      property matrix4x4 samplesC: root.still ? Qt.matrix4x4() : Model.matrix(root.history,32)
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
      readonly property real phase: root.phase
      readonly property real morph: root.morph
      readonly property real pitch: root.cellSize
      readonly property var samples: root.still ? null : root.history
      onAccentChanged: requestPaint()
      onPhaseChanged: requestPaint()
      onMorphChanged: requestPaint()
      onPitchChanged: requestPaint()
      onSamplesChanged: if(root.active) requestPaint()
      onPaint: {
        var ctx=getContext("2d")
        ctx.clearRect(0,0,width,height)
        var columns=Math.floor(width/pitch), rows=Math.floor(height/pitch)
        if(!columns || !rows) return
        var left=(width-columns*pitch)/2, top=(height-rows*pitch)/2
        ctx.fillStyle=accent
        for(var column=0;column<columns*2;column++) {
          var x=left+(Math.floor(column/2)+(column%2 ? 0.64 : 0.36))*pitch
          var u=x/width
          var sample=samples ? samples[Math.round(u*47)] : 0.10
          var energy=Math.min(1,Math.sqrt(sample)*1.6)
          var taper=Math.sin(Math.PI*u)
          var center=Math.sin(u*12-phase*3)*(0.10+0.12*energy)*taper
          var span=(0.09+0.22*energy)*taper*(1-morph)
          var processing=Math.sin(u*12-phase*4)*0.19*taper
          center+=(processing-center)*morph
          for(var row=0;row<rows*4;row++) {
            var y=top+(Math.floor(row/4)+0.17+(row%4)*0.22)*pitch
            var distance=Math.abs(y/height-0.5-center)
            var ink=Math.max(0,1-distance/(0.095+span))
            var radius=pitch*(0.039+0.060*ink)
            ctx.globalAlpha=taper*(0.12+0.88*ink)
            ctx.beginPath()
            ctx.arc(x,y,radius,0,2*Math.PI)
            ctx.fill()
          }
        }
      }
    }
  }
}
