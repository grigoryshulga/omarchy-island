import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "SettingsModel.js" as Settings

Item {
  id: root
  required property var service
  required property var strings
  property var bar: null
  property var settings: ({})
  property var externalFeedback: null
  readonly property bool musicHovered: !controls && !calendar && !weather && inbox.musicHovered
  property bool keyboardActive: false
  property bool expanded: false
  property bool hovering: false
  property string alertKind: ""
  readonly property var notificationIcon: inbox.toastIcon
  property bool controls: false
  property bool calendar: false
  property bool weather: false
  property bool compactNotifications: !expanded && !hovering && alertKind==="notification"
  readonly property var weatherData: service && ("weather" in service) ? service.weather : null
  readonly property int lastPage: weatherData && weatherData.allowed ? 3 : 2
  readonly property string pageSignature:{
    var result=Settings.pages(settings,lastPage===3)
    if(!expanded && alertKind && result.indexOf(1)<0) result.splice(1,0,1)
    return result.join(",")
  }
  readonly property var enabledPages:pageSignature.split(",").map(Number)
  readonly property int selectedPage:controls ? 0 : calendar ? 2 : weather ? 3 : 1
  property bool radialBraille: true
  property bool ready: false
  property real wheelDistance: 0
  property int wheelDirection: 0
  property bool wheelLatched: false
  property bool positioned: false
  property bool navigating: false
  property bool gesturing: false
  property int edgeTarget: -1
  property bool wrapping: false
  signal dismissRequested()
  signal settingRequested(string key, var value)
  signal expandRequested()
  signal controlsRequested()
  signal calendarRequested()
  signal weatherRequested()
  signal inboxRequested()
  readonly property real pageProgress: wrapping ? 1 : pager.width>0 && pager.itemAt(enabledPages.indexOf(1)) ? Math.max(0,Math.min(1,Math.abs((pager.contentItem.contentX-pager.itemAt(enabledPages.indexOf(1)).x)/pager.width))) : (controls || calendar || weather ? 1 : 0)
  readonly property real contentTop: tabs.visible ? tabs.implicitHeight+Design.gap.section : 0
  implicitHeight: contentTop+Math.max(root.expanded ? calendarWeatherHeight : 0,controls ? controlsPage.implicitHeight : weather || calendar ? calendarWeatherHeight : inbox.implicitHeight)
  readonly property real calendarWeatherHeight:Math.max(calendarPage.implicitHeight,weatherPage.implicitHeight,controlsPage.implicitHeight)
  clip: true
  function showToday() { calendarPage.showToday() }
  function back() {if(controls && controlsPage.section==="settings") {controlsPage.back();return true}return false}
  function pageHolder(index) {return [controlsHolder,inboxHolder,calendarHolder,weatherHolder][index]}
  function updatePages() {
    if(!ready) return
    for(var i=pager.count-1;i>=0;i--) {
      var item=pager.itemAt(i)
      if(enabledPages.indexOf(item.pageIndex)<0) {pager.takeItem(i);item.parent=parking}
    }
    for(var at=0;at<enabledPages.length;at++) {
      var target=pageHolder(enabledPages[at]),from=-1
      for(var j=0;j<pager.count;j++) if(pager.itemAt(j)===target) {from=j;break}
      if(from<0) pager.insertItem(at,target)
      else if(from!==at) pager.moveItem(from,at)
    }
    scheduleSync()
  }
  function cancelEdits() {weatherPage.cancelEditing()}
  function handleCalendarKey(event) { return calendarPage.handleKey(event) }
  function currentPage() {return controls ? controlsPage : weather ? weatherPage : calendar ? calendarPage : inbox}
  function keyboardPage(index) {
    if(!keyboardActive || enabledPages.indexOf(index)<0) return
    requestPage(index)
    Qt.callLater(function(){if(root.calendar) calendarPage.focusSelectedDay();else navigation.first(root.currentPage())})
  }
  function directionEnabled(horizontal) {
    return keyboardActive && !controlsPage.settingsOwnKeys && navigation.contains(root,navigation.focused) && !navigation.editing(navigation.focused) && !navigation.nativeFocus() && !(horizontal && navigation.focused && "islandHandlesHorizontalKeys" in navigation.focused)
  }
  function keyboardDirection(x,y) {
    if(calendar && navigation.focused && "islandCalendarDay" in navigation.focused) {
      calendarPage.handleKey({key:x<0 ? Qt.Key_Left : x>0 ? Qt.Key_Right : y<0 ? Qt.Key_Up : Qt.Key_Down})
      Qt.callLater(calendarPage.focusSelectedDay)
    }
    else navigation.move(x,y)
  }
  function handleKeyboard(event) {
    if(!keyboardActive || navigation.editing(navigation.focused)) return false
    var direction=navigation.direction(event)
    if(calendar && navigation.focused && "islandCalendarDay" in navigation.focused) {
      if(direction) return calendarPage.handleKey({key:direction.key})
      return calendarPage.handleKey(event)
    }
    if(direction) return navigation.move(direction.x,direction.y)
    return false
  }
  KeyboardNavigation {id:navigation;scope:root;containers:[tabs,root.currentPage()]}
  Shortcut {sequence:"Alt+1";context:Qt.WindowShortcut;enabled:root.keyboardActive;onActivated:root.keyboardPage(0)}
  Shortcut {sequence:"Alt+2";context:Qt.WindowShortcut;enabled:root.keyboardActive;onActivated:root.keyboardPage(1)}
  Shortcut {sequence:"Alt+3";context:Qt.WindowShortcut;enabled:root.keyboardActive;onActivated:root.keyboardPage(2)}
  Shortcut {sequence:"Alt+4";context:Qt.WindowShortcut;enabled:root.keyboardActive && root.lastPage===3;onActivated:root.keyboardPage(3)}
  Shortcut {sequence:"Tab";context:Qt.WindowShortcut;enabled:root.keyboardActive && navigation.contains(root,navigation.focused);onActivated:navigation.tab(1)}
  Shortcut {sequence:"Shift+Tab";context:Qt.WindowShortcut;enabled:root.keyboardActive && navigation.contains(root,navigation.focused);onActivated:navigation.tab(-1)}
  Shortcut {sequences:["Left","H","Р"];context:Qt.WindowShortcut;enabled:root.directionEnabled(true);onActivated:root.keyboardDirection(-1,0)}
  Shortcut {sequences:["Right","L","Д"];context:Qt.WindowShortcut;enabled:root.directionEnabled(true);onActivated:root.keyboardDirection(1,0)}
  Shortcut {sequences:["Up","K","Л"];context:Qt.WindowShortcut;enabled:root.directionEnabled(false);onActivated:root.keyboardDirection(0,-1)}
  Shortcut {sequences:["Down","J","О"];context:Qt.WindowShortcut;enabled:root.directionEnabled(false);onActivated:root.keyboardDirection(0,1)}
  Keys.priority:Keys.AfterItem
  Keys.onPressed:event=>{event.accepted=root.handleKeyboard(event)}
  function syncPage() {
    if(!ready || pager.width<=0) return
    var view=pager.contentItem
    if(view.dragging || view.flicking) return
    var next=Math.max(0,enabledPages.indexOf(selectedPage))
    pageMotion.stop()
    var from=view.contentX
    pager.setCurrentIndex(next)
    view.forceLayout()
    var page=pager.itemAt(next)
    if(!page) return
    var target=page.x
    if(!positioned || Math.abs(from-target)<0.5 || Preferences.reduceMotion) {view.contentX=target;wrapping=false}
    else {
      view.contentX=from
      pageMotion.from=from;pageMotion.to=target;pageMotion.restart()
    }
    positioned=true
  }
  function scheduleSync() { if(ready) Qt.callLater(syncPage) }
  function finishGesture() {
    if(navigating || !gesturing) return
    gesturing=false
    if(edgeTarget>=0) {var target=edgeTarget;edgeTarget=-1;requestPage(target);return}
    var closest=0,distance=Infinity
    pager.contentItem.forceLayout()
    for(var i=0;i<enabledPages.length;i++) {
      var page=pager.itemAt(i),delta=page ? Math.abs(pager.contentItem.contentX-page.x) : Infinity
      if(delta<distance) {distance=delta;closest=i}
    }
    requestPage(enabledPages[closest])
  }
  function handleWheel(event) {
    var x=event.pixelDelta.x || event.angleDelta.x
    var y=event.pixelDelta.y || event.angleDelta.y
    if (event.modifiers & Qt.ShiftModifier) x=x || y
    if (!root.expanded || !x || (!(event.modifiers & Qt.ShiftModifier) && Math.abs(x)<Math.abs(y))) { event.accepted=false; return }
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
    var next=Settings.nextPage(enabledPages,selectedPage,step)
    root.wheelLatched=true
    requestPage(next)
  }
  function requestPage(index) {
    if(enabledPages.indexOf(index)<0) return
    wrapping=(pager.currentIndex===0 && index===enabledPages[enabledPages.length-1]) || (pager.currentIndex===enabledPages.length-1 && index===0)
    edgeTarget=-1
    gesturing=false
    navigating=true
    pageMotion.stop()
    pager.contentItem.cancelFlick()
    navigating=false
    if(index===3 && !weather) weatherRequested()
    else if(index===2 && !calendar) calendarRequested()
    else if(index===0 && !controls) controlsRequested()
    else if(index===1 && (controls || calendar || weather)) inboxRequested()
    scheduleSync()
  }
  onControlsChanged: scheduleSync()
  onCalendarChanged: scheduleSync()
  onWeatherChanged: scheduleSync()
  onWidthChanged: scheduleSync()
  onHeightChanged: scheduleSync()
  onLastPageChanged: if(ready) {if(weather && lastPage<3) inboxRequested();else scheduleSync()}
  onEnabledPagesChanged:Qt.callLater(updatePages)
  Component.onCompleted: { ready = true; updatePages(); scheduleSync() }

  RowLayout {
    id: tabs
    objectName: "islandTabs"
    anchors.left: parent.left; anchors.right: parent.right
    visible: root.expanded
    spacing:Design.gap.tight
    uniformCellSizes: true
    TabButton {
      feedback: root.externalFeedback

      objectName: "islandTabControls"
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 1
      Layout.minimumWidth: 0
      label: root.strings.t("tabs.controls")
      tabActive: root.controls
      fontSize: Design.type.label
      radius: Design.controlRadius
      focusable: true
      onClicked: root.requestPage(0)
    }
    TabButton {
      feedback: root.externalFeedback

      objectName: "islandTabOverview"
      visible:root.enabledPages.indexOf(1)>=0
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 1
      Layout.minimumWidth: 0
      label: root.strings.t("tabs.overview")
      tabActive: !root.controls && !root.calendar && !root.weather
      fontSize: Design.type.label
      radius: Design.controlRadius
      focusable: true
      onClicked: root.requestPage(1)
    }
    TabButton {
      feedback: root.externalFeedback

      objectName: "calendarOpen"
      visible:root.enabledPages.indexOf(2)>=0
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 1
      Layout.minimumWidth: 0
      label: root.strings.t("calendar.open")
      tabActive: root.calendar
      fontSize: Design.type.label
      radius: Design.controlRadius
      focusable: true
      onClicked: root.requestPage(2)
    }
    WeatherChip {
      feedback: root.externalFeedback

      objectName: "weatherOpen"
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredWidth: 1
      Layout.minimumWidth: 0
      visible: root.enabledPages.indexOf(3)>=0
      showLabel: true
      weather: root.weatherData
      strings: root.strings
      selected: root.weather
      onClicked: root.requestPage(3)
    }
  }
  Controls.SwipeView {
    id: pager
    objectName: "islandPageSwipe"
    currentIndex: 1
    x: 0; y: root.contentTop
    width: parent.width; height: Math.max(0,parent.height-y)
    interactive: root.expanded
    // Native flicking owns gestures; explicit navigation owns the settled
    // position. Do not let ListView's highlight fight the page transition.
    Binding {target:pager.contentItem;property:"boundsBehavior";value:Flickable.DragOverBounds}
    Binding { target: pager.contentItem; property: "highlightRangeMode"; value: ListView.NoHighlightRange }
    Binding { target: pager.contentItem; property: "highlightFollowsCurrentItem"; value: false }
  }
  Item {id:parking;visible:false}
  Item {id:controlsHolder;property int pageIndex:0}
  Item {id:inboxHolder;property int pageIndex:1}
  Item {id:calendarHolder;property int pageIndex:2}
  Item {id:weatherHolder;property int pageIndex:3}
  ControlsView {
    id: controlsPage
    parent:root.pageHolder(0)
    anchors.fill:parent
    settings: root.settings
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
    objectName: "islandControls"
    service: root.service; strings: root.strings; bar: root.bar
    externalFeedback: root.externalFeedback
    active: root.controls && root.visible && (root.expanded || root.hovering)
    onDismissRequested: root.dismissRequested()
  }
  IslandContent {
    id: inbox
    parent:root.pageHolder(1)
    anchors.fill:parent
    overviewActive:!root.controls && !root.calendar && !root.weather
    externalFeedback: root.externalFeedback
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
    parent:root.pageHolder(2)
    anchors.fill:parent
    externalFeedback: root.externalFeedback
    objectName: "islandCalendar"
    strings: root.strings
    showBack: false
    active: root.calendar && root.visible && (root.expanded || root.hovering)
    weekStart: String(root.settings.calendarWeekStart || "")
    onWeekStartRequested: value => root.settingRequested("calendarWeekStart",value)
    radialBraille: root.radialBraille
    onBackRequested: root.inboxRequested()
  }
  WeatherView {
    id: weatherPage
    parent:root.pageHolder(3)
    anchors.fill:parent
    externalFeedback: root.externalFeedback
    objectName: "islandWeather"
    strings: root.strings
    showBack: false
    weather: root.weatherData
    active: root.weather && (root.expanded || root.hovering)
    radialBraille: root.radialBraille
    onTemperatureUnitRequested: value => root.settingRequested("weatherTemperatureUnit",value)
    onBackRequested: root.inboxRequested()
  }

  NumberAnimation { id: pageMotion; onFinished:root.wrapping=false; target: pager.contentItem; property: "contentX"; duration: Preferences.duration(230); easing.type: Easing.OutCubic }
  Connections {target:Preferences;function onReduceMotionChanged(){if(Preferences.reduceMotion) {pageMotion.stop();root.scheduleSync()}}}
  Connections {
    target: pager.contentItem
    function onDraggingChanged() {if(pager.contentItem.dragging) {root.gesturing=true;root.edgeTarget=-1;pageMotion.stop()}}
    function onContentXChanged() {
      var view=pager.contentItem
      if(!root.gesturing || !view.dragging) return
      var first=pager.itemAt(0),last=pager.itemAt(root.enabledPages.length-1)
      if(!first || !last) return
      var low=Math.min(first.x,last.x),high=Math.max(first.x,last.x),threshold=Style.space(40)
      root.edgeTarget=view.contentX<low-threshold ? (first.x<last.x ? root.enabledPages[root.enabledPages.length-1] : 0) : view.contentX>high+threshold ? (first.x<last.x ? 0 : root.enabledPages[root.enabledPages.length-1]) : -1
    }
    function onMovementEnded() {root.finishGesture()}
    function onContentWidthChanged() {root.scheduleSync()}
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
