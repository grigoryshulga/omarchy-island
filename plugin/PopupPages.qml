import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root
  required property var service
  required property var strings
  property var bar: null
  property bool expanded: false
  property bool hovering: false
  property string alertKind: ""
  property bool calendar: false
  property bool weather: false
  property bool compactNotifications: !expanded && !hovering && alertKind==="notification"
  readonly property var weatherData: service && ("weather" in service) ? service.weather : null
  readonly property int lastPage: weatherData && weatherData.allowed ? 2 : 1
  property bool radialBraille: true
  property bool ready: false
  property real wheelDistance: 0
  property int wheelDirection: 0
  property bool wheelLatched: false
  signal expandRequested()
  signal calendarRequested()
  signal weatherRequested()
  signal inboxRequested()
  readonly property real pageProgress: pager.width>0 ? Math.max(0,Math.min(1,Math.abs((pager.contentItem.contentX-pager.contentItem.originX)/pager.width))) : (calendar ? 1 : 0)
  readonly property real contentTop: tabs.visible ? tabs.implicitHeight+Style.space(8) : 0
  implicitHeight: contentTop+(weather ? weatherPage.implicitHeight : calendar ? calendarPage.implicitHeight : inbox.implicitHeight)
  clip: true
  function showToday() { calendarPage.showToday() }
  function handleCalendarKey(event) { return calendarPage.handleKey(event) }
  function syncPage() {
    if (!ready) return
    var next=Math.min(lastPage,weather ? 2 : calendar ? 1 : 0)
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
    var step=(Commons.I18n.rightToLeft ? sign>0 : sign<0) ? 1 : -1
    var next=Math.max(0,Math.min(root.lastPage,pager.currentIndex+step))
    root.wheelLatched=true
    requestPage(next)
  }
  function requestPage(index) {
    if(index===2 && !weather) weatherRequested()
    else if(index===1 && !calendar) calendarRequested()
    else if(index===0 && (calendar || weather)) inboxRequested()
  }
  onCalendarChanged: syncPage()
  onWeatherChanged: syncPage()
  onLastPageChanged: if(ready) {if(weather && lastPage<2) inboxRequested();else syncPage()}
  Component.onCompleted: { ready = true; syncPage() }

  RowLayout {
    id: tabs
    objectName: "islandTabs"
    anchors.left: parent.left; anchors.right: parent.right
    visible: root.expanded || root.hovering
    spacing: Style.space(4)
    Button {
      objectName: "islandTabOverview"
      Layout.fillWidth: true
      text: root.strings.t("tabs.overview")
      selected: !root.calendar && !root.weather
      fontSize: Style.font.bodySmall
      radius: Math.min(Style.cornerRadius,Style.space(6))
      focusable: true
      onClicked: root.requestPage(0)
    }
    Button {
      objectName: "calendarOpen"
      Layout.fillWidth: true
      text: root.strings.t("calendar.open")
      selected: root.calendar
      fontSize: Style.font.bodySmall
      radius: Math.min(Style.cornerRadius,Style.space(6))
      focusable: true
      onClicked: root.requestPage(1)
    }
    WeatherChip {
      objectName: "weatherOpen"
      Layout.fillWidth: true
      visible: root.lastPage===2
      showLabel: true
      weather: root.weatherData
      strings: root.strings
      selected: root.weather
      onClicked: root.requestPage(2)
    }
  }
  Controls.SwipeView {
    id: pager
    objectName: "islandPageSwipe"
    x: 0; y: root.contentTop
    width: parent.width; height: Math.max(0,parent.height-y)
    interactive: root.expanded || root.hovering
    onCurrentIndexChanged: {
      if(!root.ready) return
      if(currentIndex>root.lastPage) { setCurrentIndex(root.lastPage); return }
      root.requestPage(currentIndex)
    }
    Binding { target: pager.contentItem; property: "highlightMoveDuration"; value: Style.duration(230) }
    IslandContent {
      id: inbox
      service: root.service; strings: root.strings; bar: root.bar
      expanded: root.expanded; hovering: root.hovering; alertKind: root.alertKind
      compactNotifications: root.compactNotifications
      weather: root.weatherData
      radialBraille: root.radialBraille
      onExpandRequested: root.expandRequested()
      onCalendarRequested: root.calendarRequested()
      onWeatherRequested: root.weatherRequested()
    }
    CalendarView {
      id: calendarPage
      objectName: "islandCalendar"
      strings: root.strings
      showBack: false
      radialBraille: root.radialBraille
      onBackRequested: root.inboxRequested()
    }
    WeatherView {
      id: weatherPage
      objectName: "islandWeather"
      strings: root.strings
      showBack: false
      weather: root.weatherData
      active: root.weather && (root.expanded || root.hovering)
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
