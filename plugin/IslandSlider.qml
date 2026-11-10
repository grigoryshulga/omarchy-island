// Adapted from Omarchy PanelSlider; see THIRD_PARTY.md.
import QtQuick
import qs.Commons
import qs.Ui
import qs.Commons as Commons

Item {
  id: root

  property bool islandHandlesHorizontalKeys:true
  activeFocusOnTab:true
  Keys.onPressed:event=>{
    if(event.modifiers & (Qt.AltModifier|Qt.ControlModifier|Qt.MetaModifier)) {event.accepted=false;return}
    var text=String(event.text || "").toLowerCase(),delta=0,next=root.liveValue
    if(event.key===Qt.Key_Left || text==="h" || text==="р") delta=root.mirrored ? root.step : -root.step
    else if(event.key===Qt.Key_Right || text==="l" || text==="д") delta=root.mirrored ? -root.step : root.step
    else if(event.key===Qt.Key_Home) next=root.minimum
    else if(event.key===Qt.Key_End) next=root.maximum
    else {event.accepted=false;return}
    next=Math.max(root.minimum,Math.min(root.maximum,next+delta))
    if(root.integer) next=Math.round(next)
    root.liveValue=next;root.moved(next);root.released(next)
    event.accepted=true
  }
  BorderSurface {anchors.fill:parent;color:"transparent";borderSpec:Border.controlSpec("focus",Commons.Color.foreground,Commons.Color.accent);radius:Style.cornerRadius;visible:root.activeFocus}
  property QtObject bar: null
  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 0.05
  property bool integer: false
  property color trackColor: bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "#333"
  property color fillColor: bar ? bar.foreground : Commons.Color.foreground
  property color knobColor: bar ? bar.foreground : Commons.Color.foreground
  property bool dragging: false
  property real trackHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
  property real knobSize: Math.max(14, Math.round(Style.spacing.controlHeight * 0.38))
  property real liveValue: value

  // macOS-style notches. When > 1, that many evenly-spaced tick marks are cut
  // into the track (drawn in the panel background color, so only the part
  // crossing the track shows). Purely visual — snapping is the caller's job via
  // `integer`/`step` or an index-based value. Default 0 leaves the track plain.
  property int tickCount: 0
  property color tickColor: bar ? bar.background : Commons.Color.background

  onValueChanged: if (!dragging) liveValue = value

  signal moved(real value)
  signal released(real value)

  // Right-click is a secondary action on the whole track — audio uses it to
  // mute the channel the slider belongs to. Dragging stays left-button only.
  signal rightClicked()
  signal clicked(point position)

  implicitWidth: Style.space(200)
  implicitHeight: Math.max(Style.space(22), knobSize + Style.spacing.md)

  readonly property real range: Math.max(0.0001, maximum - minimum)
  readonly property real progress: Math.max(0, Math.min(1, (liveValue - minimum) / range))
  readonly property bool _hot: mouseArea.containsMouse || root.dragging
  // In a mirrored (right-to-left) layout the anchored fill already starts at
  // the right; the knob, ticks, and pointer are placed by x, so they flip here.
  readonly property bool mirrored: LayoutMirroring.enabled
  function trackX(fraction) {
    return track.x + track.width * (root.mirrored ? 1 - fraction : fraction)
  }

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.knobSize / 2
    anchors.rightMargin: root.knobSize / 2
    height: root.trackHeight
    radius: Style.cornerRadius > 0 ? height / 2 : 0
    color: root.trackColor
  }

  Rectangle {
    id: fill
    anchors.verticalCenter: track.verticalCenter
    anchors.left: track.left
    height: track.height
    radius: track.radius
    color: root.fillColor
    width: track.width * root.progress

    Behavior on width {
      enabled: !root.dragging
      NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
    }
  }

  Repeater {
    model: root.tickCount > 1 ? root.tickCount : 0
    Rectangle {
      required property int index
      width: Math.max(1, Style.space(2))
      height: root.trackHeight + Style.space(4)
      radius: Style.cornerRadius > 0 ? 1 : 0
      color: root.tickColor
      anchors.verticalCenter: track.verticalCenter
      x: root.trackX(index / (root.tickCount - 1)) - width / 2
    }
  }

  BorderSurface {
    id: knob
    objectName: "sliderKnob"
    width: root.knobSize
    height: root.knobSize
    radius: Style.cornerRadius > 0 ? root.knobSize / 2 : 0
    color: root.knobColor
    borderSpec: Border.flat(root.bar ? root.bar.background : "#101315", Math.max(1, Style.space(2)))
    anchors.verticalCenter: track.verticalCenter
    x: root.trackX(root.progress) - width / 2
    scale: root._hot ? 1.15 : 1.0

    Behavior on x {
      enabled: !root.dragging
      NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
    }

    Behavior on scale {
      NumberAnimation { duration: Style.duration(110); easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    id: mouseArea
    property point pressPosition: Qt.point(0,0)
    property bool movedBeyondTap: false
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function valueFromX(x) {
      if (track.width <= 0) return root.minimum
      var fraction = Math.max(0, Math.min(1, (x - track.x) / track.width))
      if (root.mirrored) fraction = 1 - fraction
      var raw = root.minimum + fraction * root.range
      if (root.integer) raw = Math.round(raw)
      return Math.max(root.minimum, Math.min(root.maximum, raw))
    }

    onPressed: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      pressPosition=Qt.point(mouse.x,mouse.y)
      movedBeyondTap=false
      root.dragging = true
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.rightClicked()
    }
    onPositionChanged: function(mouse) {
      if (!root.dragging) return
      if(Math.hypot(mouse.x-pressPosition.x,mouse.y-pressPosition.y)>Qt.styleHints.startDragDistance) movedBeyondTap=true
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onReleased: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      root.dragging = false
      root.released(root.liveValue)
      root.liveValue = root.value
      if(!movedBeyondTap) root.clicked(Qt.point(mouse.x,mouse.y))
    }
    onCanceled: root.dragging=false
    onWheel: function(wheel) {
      var delta = wheel.angleDelta.y > 0 ? root.step : -root.step
      var next = Math.max(root.minimum, Math.min(root.maximum, root.liveValue + delta))
      if (root.integer) next = Math.round(next)
      root.liveValue = next
      root.moved(next)
      root.released(next)
    }
  }
}
