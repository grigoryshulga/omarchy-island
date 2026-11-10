import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons

Item {
  id: root
  required property var service
  required property var strings
  property var bar: null
  property bool expanded: false
  property bool hovering: false
  property string alertKind: ""
  property bool calendar: false
  property bool radialBraille: true
  property bool ready: false
  property real wheelDistance: 0
  property int wheelDirection: 0
  property bool wheelLatched: false
  signal expandRequested()
  signal calendarRequested()
  signal inboxRequested()
  readonly property real pageProgress: pager.width>0 ? Math.max(0,Math.min(1,Math.abs((pager.contentItem.contentX-pager.contentItem.originX)/pager.width))) : (calendar ? 1 : 0)
  implicitHeight: calendar ? calendarPage.implicitHeight : inbox.implicitHeight
  clip: true
  function showToday() { calendarPage.showToday() }
  function handleCalendarKey(event) { return calendarPage.handleKey(event) }
  function syncPage() {
    if (!ready) return
    var next=calendar ? 1 : 0
    if (pager.currentIndex!==next) { pager.contentItem.cancelFlick(); pager.setCurrentIndex(next) }
  }
  function handleWheel(event) {
    var x=event.pixelDelta.x || event.angleDelta.x
    var y=event.pixelDelta.y || event.angleDelta.y
    if (event.modifiers & Qt.ShiftModifier) x=x || y
    if (!(root.expanded || root.hovering) || !x || (!(event.modifiers & Qt.ShiftModifier) && Math.abs(x)<Math.abs(y))) { event.accepted=false; return }
    event.accepted=true
    var sign=x<0 ? -1 : 1
    if (sign!==root.wheelDirection) { root.wheelDistance=0; root.wheelLatched=false }
    root.wheelDirection=sign
    wheelIdle.restart()
    if (root.wheelLatched) return
    root.wheelDistance+=x
    var threshold=event.pixelDelta.x || event.pixelDelta.y ? 40 : 90
    if (Math.abs(root.wheelDistance)<threshold) return
    var next=Commons.I18n.rightToLeft ? sign>0 : sign<0
    root.wheelLatched=true
    if (next!==root.calendar) { if (next) root.calendarRequested(); else root.inboxRequested() }
  }
  onCalendarChanged: syncPage()
  Component.onCompleted: { ready = true; syncPage() }

  Controls.SwipeView {
    id: pager
    objectName: "islandPageSwipe"
    anchors.fill: parent
    interactive: root.expanded || root.hovering
    onCurrentIndexChanged: {
      if (!root.ready || root.calendar === (currentIndex === 1)) return
      if (currentIndex === 1) root.calendarRequested()
      else root.inboxRequested()
    }
    Binding { target: pager.contentItem; property: "highlightMoveDuration"; value: Style.duration(230) }
    IslandContent {
      id: inbox
      service: root.service; strings: root.strings; bar: root.bar
      expanded: root.expanded; hovering: root.hovering; alertKind: root.alertKind
      radialBraille: root.radialBraille
      onExpandRequested: root.expandRequested()
      onCalendarRequested: root.calendarRequested()
    }
    CalendarView {
      id: calendarPage
      objectName: "islandCalendar"
      strings: root.strings
      radialBraille: root.radialBraille
      onBackRequested: root.inboxRequested()
    }
  }
  // Wheel-only overlay: horizontal events reach us before child Flickables;
  // pointer presses and vertical scrolling continue to the page underneath.
  Item {
    anchors.fill: parent
    z: 100
    WheelHandler {
      target: null
      orientation: Qt.Horizontal
      acceptedModifiers: Qt.NoModifier
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => root.handleWheel(event)
    }
    WheelHandler {
      target: null
      orientation: Qt.Vertical
      acceptedModifiers: Qt.ShiftModifier
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => root.handleWheel(event)
    }
  }
  Timer { id: wheelIdle; interval: 180; onTriggered: { root.wheelDistance=0; root.wheelLatched=false; root.wheelDirection=0 } }
}
