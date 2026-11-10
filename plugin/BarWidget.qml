import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "gshulga.island"
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  property bool pinned: false
  property bool contentExpanded: false
  property bool calendarMode: false
  property bool hoverOpen: false
  property string alertKind: ""
  property bool hoverSuppressed: false
  property date now: new Date()
  readonly property bool opened: pinned
  readonly property string screenName: root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name : ""
  readonly property bool alertOnScreen: !service || !service.targetScreen || service.targetScreen === screenName
  readonly property bool showAlert: alertKind !== "" && alertOnScreen
  readonly property string clockText: now.toLocaleString(Qt.locale(Commons.I18n.formatLocale), setting("format", "dddd HH:mm"))
  readonly property string barText: showAlert && service ? (alertKind === "notification" && service.latest ? "󰂚  " + service.latest.summary : "󰝚  " + strings.t("nowPlaying")) : clockText
  readonly property bool isHovered: trigger.tooltipHovered || preview.containsMouse
  readonly property string signature: service ? service.track + ":" + service.playing : ""

  function open() { calendarMode = false; contentExpanded = true; pinned = true; hoverOpen = false; alertKind = ""; Qt.callLater(function() { previewContent.forceActiveFocus() }) }
  function openCalendar() {
    calendarMode = true; contentExpanded = true; pinned = true; hoverOpen = false; alertKind = ""
    previewContent.showToday()
    Qt.callLater(function() { previewContent.forceActiveFocus() })
  }
  function toggleCalendar() { if (pinned && calendarMode) close(); else openCalendar() }
  function close() { hoverSuppressed = true; pinned = false; hoverOpen = false; alertKind = ""; hoverDelay.stop() }
  function toggle() { pinned ? close() : open() }
  function showNotification() {
    if (!service || !service.latest || !alertOnScreen || pinned) return
    contentExpanded = false; alertKind = "notification"; alertLife.interval = Number(setting("notificationDuration",5000)); alertLife.restart()
  }
  function syncSettings() {
    if (service && Array.isArray(setting("musicApps",null))) service.allowedPlayers = setting("musicApps",[])
  }
  onServiceChanged: syncSettings()
  onSettingsChanged: syncSettings()
  onSignatureChanged: {
    if (service && service.playing && !pinned && alertKind !== "notification") {
      alertKind = "media"; alertLife.interval = 3000; alertLife.restart()
    }
  }
  onIsHoveredChanged: {
    if (isHovered) { leaveGrace.stop(); if (!pinned && !hoverSuppressed) hoverDelay.restart() }
    else { hoverSuppressed = false; hoverDelay.stop(); leaveGrace.restart() }
  }
  implicitWidth: vertical ? barSize : Math.min(Style.space(360),Math.max(Style.space(190), clockMeasure.implicitWidth + Style.space(42), showAlert ? Style.space(290) : 0))
  implicitHeight: vertical ? Style.space(80) : barSize
  Behavior on implicitWidth { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  Connections { target: root.service; function onHasMediaChanged() { if (root.service && !root.service.hasMedia && root.alertKind === "media") { root.alertKind = ""; alertLife.stop() } } function onArrivalChanged() { root.showNotification() } function onLatestChanged() { if (root.service && !root.service.latest && root.alertKind === "notification") root.alertKind = "" } }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
  Timer { id: hoverDelay; interval: 140; onTriggered: if (!root.pinned && root.isHovered) { root.contentExpanded = false; root.hoverOpen = true } }
  Timer { id: leaveGrace; interval: 220; onTriggered: if (!root.pinned && !root.isHovered) root.hoverOpen = false }
  Timer { id: alertLife; interval: 3000; onTriggered: root.alertKind = "" }
  PlainText { id: clockMeasure; text: root.clockText; visible: false }
  WidgetButton {
    id: trigger
    objectName: "islandClock"
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.implicitWidth
    fixedHeight: root.implicitHeight
    pressFeedbackButtons: Qt.NoButton
    onPressed: button => { if (button === Qt.RightButton && root.service) root.service.setDoNotDisturb(!root.service.doNotDisturb); else if (button === Qt.MiddleButton) root.toggleCalendar(); else root.toggle() }
    ArtworkBackground {
      objectName: "islandClockArtwork"
      anchors.fill: parent
      visible: !root.showAlert
      service: root.service
      monochrome: true
      horizontalFade: true
    }
    PlainText {
      anchors.centerIn: parent
      width: parent.width - Style.space(18)
      horizontalAlignment: Text.AlignHCenter
      text: root.vertical ? root.now.toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH\nmm") : root.barText
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      color: root.showAlert ? Commons.Color.accent : root.bar ? root.bar.barForeground : Commons.Color.foreground
    }
    Rectangle {
      visible: root.service !== null && root.service.doNotDisturb
      width: Style.space(3); height: width; radius: Style.cornerRadius > 0 ? width/2 : 0
      color: Commons.Color.muted
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
    }
  }
  IslandPopup {
    id: preview
    objectName: "islandPopup"
    anchorItem: trigger
    bar: root.bar
    owner: root
    triggerMode: root.pinned ? "click" : "hover"
    centerOnBar: true
    open: root.pinned || root.hoverOpen || root.showAlert
    onVisibleChanged: if (!visible) { root.contentExpanded = false; root.calendarMode = false }
    contentWidth: fittedContentWidth(Style.space(root.contentExpanded ? 480 : root.hoverOpen ? 420 : 370))
    contentHeight: fittedContentHeight(previewContent.implicitHeight)
    ArtworkBackground {
      objectName: "islandPopupArtwork"
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.leftMargin: -preview.padding; anchors.rightMargin: -preview.padding; anchors.topMargin: -preview.padding
      height: Math.min(preview.contentHeight,Style.space(root.contentExpanded ? 250 : 145))
      reveal: 1-previewContent.pageProgress
      visible: reveal>0 && (root.pinned || root.hoverOpen || root.alertKind === "media")
      service: root.service
    }
    PopupPages {
      id: previewContent
      calendar: root.calendarMode
      radialBraille: root.setting("radialBraille",true)
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      service: root.service; strings: strings; bar: root.bar
      expanded: root.contentExpanded
      hovering: root.hoverOpen || root.pinned
      alertKind: root.alertKind
      focus: root.pinned
      Keys.onEscapePressed: root.close()
      Keys.onSpacePressed: event => { if (!root.calendarMode && root.service) root.service.media("toggle"); else event.accepted = false }
      Keys.onPressed: event => { if (root.calendarMode) event.accepted = previewContent.handleCalendarKey(event); else event.accepted = false }
      onExpandRequested: root.open()
      onCalendarRequested: root.openCalendar()
      onInboxRequested: root.open()
    }
  }
  ShellIpc {
    target: "island"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function calendar(): void { root.openCalendar() }
    function toggle(): void { root.toggle() }
    function hover(): void { root.hoverOpen = !root.hoverOpen }
    function status(): string { return JSON.stringify({pinned:root.pinned,page:root.calendarMode ? "calendar" : "inbox",hover:root.hoverOpen,alert:root.alertKind,service:root.service!==null,screen:root.screenName,appearance:preview.entranceStyle || "legacy"}) }
  }
}
