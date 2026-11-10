import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "gshulga.island"
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var indicators: service && ("indicators" in service) ? service.indicators : null
  property var registeredIndicators: null
  readonly property bool showOsd: indicators && indicators.osdActive && (!indicators.osdScreen || indicators.osdScreen===screenName)
  readonly property real indicatorGutter: Math.max(leftIndicators.implicitWidth,rightIndicators.implicitWidth)>0 ? Math.max(leftIndicators.implicitWidth,rightIndicators.implicitWidth)+Style.space(6) : 0
  function connectIndicators() {
    if(registeredIndicators===indicators) return
    if(registeredIndicators) registeredIndicators.detach(root)
    registeredIndicators=indicators
    if(registeredIndicators) registeredIndicators.attach(root)
  }
  onIndicatorsChanged: connectIndicators()
  Component.onCompleted: connectIndicators()
  Component.onDestruction: if(registeredIndicators) registeredIndicators.detach(root)
  property bool pinned: false
  property bool contentExpanded: false
  property bool calendarMode: false
  property bool weatherMode: false
  property bool hoverOpen: false
  property string alertKind: ""
  property bool hoverSuppressed: false
  property date now: new Date()
  readonly property bool opened: pinned
  readonly property string screenName: root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name : ""
  readonly property bool alertOnScreen: !service || !service.targetScreen || service.targetScreen === screenName
  readonly property bool showAlert: alertKind !== "" && alertOnScreen
  readonly property bool notificationToast: alertKind==="notification" && !pinned && !hoverOpen
  readonly property string clockText: now.toLocaleString(Qt.locale(Commons.I18n.formatLocale), setting("format", "dddd HH:mm"))
  readonly property string barText: showAlert && service ? (alertKind === "notification" && service.latest ? "󰂚  " + service.latest.summary : "󰝚  " + strings.t("nowPlaying")) : clockText
  readonly property bool isHovered: trigger.tooltipHovered || preview.containsMouse
  readonly property string signature: service ? service.track + ":" + service.playing : ""

  function activateWeather() { if(service && ("weather" in service)) service.weather.activate() }
  function syncContentPresentation() {
    // Coalesce interaction changes so an exit never applies the closed
    // presentation before its fade. A reopen uses the latest state instead.
    if (!preview.open) return
    previewContent.hovering = hoverOpen || pinned
    previewContent.alertKind = alertKind
  }
  function open() { weatherMode = false; calendarMode = false; contentExpanded = true; pinned = true; hoverOpen = false; alertKind = ""; activateWeather(); Qt.callLater(function() { previewContent.forceActiveFocus() }) }
  function openCalendar() {
    weatherMode = false; calendarMode = true; contentExpanded = true; pinned = true; hoverOpen = false; alertKind = ""
    activateWeather()
    previewContent.showToday()
    Qt.callLater(function() { previewContent.forceActiveFocus() })
  }
  function openWeather() {
    calendarMode = false; weatherMode = true; contentExpanded = true; pinned = true; hoverOpen = false; alertKind = ""
    activateWeather()
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
    if(service && ("weather" in service)) {
      service.weather.allowed=setting("weatherEnabled",true)!==false
      service.weather.unitOverride=String(setting("weatherUnit",""))
      service.weather.refreshOverride=Number(setting("weatherRefreshMinutes",0)) || 0
    }
  }
  onHoverOpenChanged: { if(hoverOpen) activateWeather(); Qt.callLater(syncContentPresentation) }
  onPinnedChanged: Qt.callLater(syncContentPresentation)
  onAlertKindChanged: Qt.callLater(syncContentPresentation)
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
  implicitWidth: vertical ? barSize : Math.min(Style.space(420),Math.max(Style.space(190), clockMeasure.implicitWidth + 2*indicatorGutter + Style.space(18), showAlert ? Style.space(290) : 0))
  implicitHeight: vertical ? Style.space(80) : barSize
  Behavior on implicitWidth { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  Connections { target: root.service; function onHasMediaChanged() { if (root.service && !root.service.hasMedia && root.alertKind === "media") { root.alertKind = ""; alertLife.stop() } } function onArrivalChanged() { root.showNotification() } function onLatestChanged() { if (root.service && !root.service.latest && root.alertKind === "notification") root.alertKind = "" } }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
  Timer { id: hoverDelay; interval: 140; onTriggered: if (!root.pinned && !root.showOsd && root.isHovered) { root.contentExpanded = false; root.hoverOpen = true } }
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
    tooltipText: [root.indicators && root.indicators.recording ? strings.t("indicator.recording") : "",root.indicators && root.indicators.remoteActive ? strings.t("indicator.remote") : "",root.indicators && root.indicators.microphoneMuted ? strings.t("indicator.microphoneMuted") : "",root.service && root.service.doNotDisturb ? strings.t("dnd") : "",root.indicators && root.indicators.nightLight ? strings.t("indicator.nightLight") : "",root.indicators && root.indicators.stayAwake ? strings.t("indicator.stayAwake") : ""].filter(function(s){return s!==""}).join(" · ")
    onPressed: button => { if (button === Qt.RightButton && root.service) root.service.setDoNotDisturb(!root.service.doNotDisturb); else if (button === Qt.MiddleButton) root.toggleCalendar(); else root.toggle() }
    ArtworkBackground {
      objectName: "islandClockArtwork"
      anchors.fill: parent
      visible: !root.showAlert
      service: root.service
      monochrome: true
      horizontalFade: true
    }
    RowLayout {
      id:leftIndicators
      objectName:"islandLeftIndicators"
      anchors.right:centerContent.left;anchors.rightMargin:Style.space(6);anchors.verticalCenter:parent.verticalCenter
      spacing:Style.space(5)
      StatusBeacon {id:recordingBeacon;objectName:"islandRecordingIndicator";Layout.preferredHeight:trigger.height;visible:root.indicators && root.indicators.recording;tint:"#f7768e";waveWidth:Math.max(0,trigger.width-leftIndicators.x-recordingBeacon.x)}
      StatusBeacon {id:remoteBeacon;objectName:"islandRemoteIndicator";Layout.preferredHeight:trigger.height;visible:root.indicators && root.indicators.remoteActive;tint:"#9ece6a";waveWidth:Math.max(0,trigger.width-leftIndicators.x-remoteBeacon.x)}
    }
    Item {
      id:centerContent
      anchors.centerIn:parent
      width:Math.max(1,parent.width-2*root.indicatorGutter-Style.space(18));height:parent.height
      z:1
      PlainText {
        objectName:"islandClockText"
        anchors.fill:parent
        horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
        visible:!root.showOsd
        text: root.vertical ? root.now.toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH\nmm") : root.barText
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        color: root.showAlert ? Commons.Color.accent : root.bar ? root.bar.barForeground : Commons.Color.foreground
      }
      BrailleGauge {objectName:"islandOsdGauge";anchors.fill:parent;visible:root.showOsd;kind:root.indicators ? root.indicators.osdKind : "volume";value:root.indicators ? root.indicators.osdValue : 0;muted:root.indicators ? root.indicators.osdMuted : false}
    }
    RowLayout {
      id:rightIndicators
      objectName:"islandRightIndicators"
      anchors.right:parent.right;anchors.rightMargin:Style.space(9);anchors.verticalCenter:parent.verticalCenter
      spacing:Style.space(5)
      z:1
      PlainText {objectName:"islandMicrophoneIndicator";visible:root.indicators && root.indicators.microphoneMuted;text:"󰍭";font.pixelSize:Style.font.icon;color:Commons.Color.accent}
      PlainText {objectName:"islandDndIndicator";visible:root.service !== null && root.service.doNotDisturb;text:"󰂛";font.pixelSize:Style.font.icon;color:Commons.Color.accent}
      PlainText {objectName:"islandNightLightIndicator";visible:root.indicators && root.indicators.nightLight;text:"󰔎";font.pixelSize:Style.font.icon;color:Commons.Color.accent}
      PlainText {objectName:"islandStayAwakeIndicator";visible:root.indicators && root.indicators.stayAwake;text:"";font.pixelSize:Style.font.icon;color:Commons.Color.accent}
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
    frameless: root.notificationToast
    onBackgroundClicked: position => panelGlow.pulse(Qt.point(position.x+(preview.layoutWidth-preview.drawnWidth)/2,position.y))
    onVisibleChanged: if (!visible) { root.contentExpanded = false; root.calendarMode = false; root.weatherMode = false }
    contentWidth: fittedContentWidth(Style.space(root.contentExpanded ? 480 : root.hoverOpen ? 420 : root.notificationToast ? 300 : 370))
    contentHeight: fittedContentHeight(previewContent.implicitHeight)
    ToastWaves {
      objectName: "islandToastWaves"
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.leftMargin: -preview.padding; anchors.rightMargin: -preview.padding; anchors.topMargin: -preview.padding
      height: preview.layoutHeight
      active: preview.frameSuppressed && preview.visible
    }
    ArtworkBackground {
      objectName: "islandPopupArtwork"
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.leftMargin: -preview.padding; anchors.rightMargin: -preview.padding; anchors.topMargin: -preview.padding
      height: Math.min(preview.contentHeight,Style.space(root.contentExpanded ? 250 : 145)+previewContent.contentTop)
      reveal: 1-previewContent.pageProgress
      visible: reveal>0 && preview.visible && !preview.frameSuppressed
      service: root.service
    }
    BrailleSpotlight {
      id: panelGlow
      objectName: "islandPanelSpotlight"
      x: -preview.insetLeft; y: -preview.insetTop
      width: preview.layoutWidth; height: preview.layoutHeight
      z: 10
      active: preview.containsMouse && preview.visible
      pointer: Qt.point(preview.hoverPosition.x+(preview.layoutWidth-preview.drawnWidth)/2,preview.hoverPosition.y)
      adaptive: root.setting("radialBraille",true)
      artworkUrl: root.service && root.service.player ? root.service.player.trackArtUrl : ""
      artworkStrength: previewContent.musicHovered ? 1 : 0
    }
    BrailleFeedback {id:panelFeedback;surface:panelGlow;effect:panelGlow;hover:null}
    PopupPages {
      id: previewContent
      externalFeedback: panelFeedback
      calendar: root.calendarMode
      weather: root.weatherMode
      compactNotifications: preview.frameSuppressed && !root.pinned && !root.hoverOpen
      radialBraille: root.setting("radialBraille",true)
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      service: root.service; strings: strings; bar: root.bar
      expanded: root.contentExpanded
      focus: root.pinned
      Keys.onEscapePressed: root.close()
      Keys.onSpacePressed: event => { if (!root.calendarMode && !root.weatherMode && root.service) root.service.media("toggle"); else event.accepted = false }
      Keys.onPressed: event => { if (root.calendarMode) event.accepted = previewContent.handleCalendarKey(event); else event.accepted = false }
      onExpandRequested: root.open()
      onCalendarRequested: root.openCalendar()
      onWeatherRequested: root.openWeather()
      onInboxRequested: root.open()
    }
  }
  ShellIpc {
    target: "island"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function calendar(): void { root.openCalendar() }
    function weather(): void { root.openWeather() }
    function toggle(): void { root.toggle() }
    function hover(): void { root.hoverOpen = !root.hoverOpen }
    function status(): string { return JSON.stringify({pinned:root.pinned,page:root.weatherMode ? "weather" : root.calendarMode ? "calendar" : "inbox",hover:root.hoverOpen,alert:root.alertKind,service:root.service!==null,screen:root.screenName,appearance:preview.entranceStyle || "legacy"}) }
  }
}
