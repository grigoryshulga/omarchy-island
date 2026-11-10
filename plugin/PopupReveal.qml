import QtQuick
import qs.Commons

// One entrance timeline for the main panel and the smaller in-panel popovers.
// Geometry grows from a real seed rectangle; the content is clipped, not scaled.
Item {
  id: root
  property bool open: false
  property real targetWidth: 1
  property real targetHeight: 1
  property real seedWidth: Style.space(56)
  property real seedHeight: Style.space(24)
  property real fallDistance: Style.space(18)
  property real drop: 0
  property real stretch: 0
  property real shown: 0
  property real contentShown: 0
  property bool ready: false
  readonly property real drawnWidth: Math.min(seedWidth,targetWidth)+(targetWidth-Math.min(seedWidth,targetWidth))*stretch
  readonly property real drawnHeight: Math.min(seedHeight,targetHeight)+(targetHeight-Math.min(seedHeight,targetHeight))*stretch
  readonly property real offsetY: -fallDistance*(1-drop)

  function sync() {
    if (!ready) return
    if (open) {
      leaving.stop()
      if (shown <= 0) { drop = 0; stretch = 0; contentShown = 0 }
      entering.restart()
    } else {
      entering.stop()
      leaving.restart()
    }
  }
  Component.onCompleted: { ready = true; sync() }
  onOpenChanged: sync()

  ParallelAnimation {
    id: entering
    NumberAnimation { target: root; property: "shown"; to: 1; duration: Style.duration(100); easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "drop"; to: 1; duration: Style.duration(200); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    SequentialAnimation {
      PauseAnimation { duration: Style.duration(45) }
      NumberAnimation { target: root; property: "stretch"; to: 1; duration: Style.duration(230); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
    }
    SequentialAnimation {
      PauseAnimation { duration: Style.duration(95) }
      NumberAnimation { target: root; property: "contentShown"; to: 1; duration: Style.duration(150); easing.type: Easing.OutCubic }
    }
  }
  SequentialAnimation {
    id: leaving
    ParallelAnimation {
      NumberAnimation { target: root; property: "shown"; to: 0; duration: Style.duration(110); easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "contentShown"; to: 0; duration: Style.duration(75); easing.type: Easing.OutCubic }
      NumberAnimation { target: root; property: "drop"; to: 0.8; duration: Style.duration(110); easing.type: Easing.OutCubic }
    }
    ScriptAction { script: { root.stretch = 0; root.drop = 0 } }
  }
}
