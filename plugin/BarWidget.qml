import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "ClockModel.js" as Clock
import "SettingsModel.js" as Settings

BarWidget {
  id: root
  moduleName: "gshulga.island"
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var indicators: service && ("indicators" in service) ? service.indicators : null
  readonly property var t3:service && ("t3" in service) ? service.t3 : null
  property var registeredIndicators: null
  readonly property bool showOsd: indicators && indicators.osdActive && (!indicators.osdScreen || indicators.osdScreen===screenName)
  property real osdShown:showOsd ? 1 : 0
  readonly property bool osdTransitioning: osdShown>0 && osdShown<1 && !Preferences.reduceMotion && Preferences.get("panelAnimation")
  Behavior on osdShown {NumberAnimation {duration:Preferences.panelDuration(root.showOsd ? 240 : 200);easing.type:Easing.OutCubic}}
  readonly property real indicatorGutter: vertical ? 0 : Math.max(leftIndicators.implicitWidth,rightIndicators.implicitWidth)>0 ? Math.max(leftIndicators.implicitWidth,rightIndicators.implicitWidth)+Style.space(11) : 0
  function activateIndicator(mode) {
    if(mode==="dnd") {if(service) service.setDoNotDisturb(false);return}
    if(mode==="nightLight" || mode==="stayAwake") {
      IpcRegistry.call(mode==="nightLight" ? "nightlight" : "idle","toggle",[])
      indicators.refreshControls()
      return
    }
    var commands={
      microphone:"omarchy-audio-input-mute",
      recording:"omarchy-capture-screenrecording --stop-recording",
      update:"omarchy-launch-floating-terminal-with-presentation omarchy-update"
    }
    if(bar && commands[mode]) bar.run(commands[mode])
  }
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
  property int lastOpenedPage:1
  readonly property bool stripNotification: !vertical && notificationToast && Settings.get(settings,"notificationStyle")==="bar"
  property bool contentExpanded: false
  property bool controlsMode: false
  property bool calendarMode: false
  property bool weatherMode: false
  property bool hoverOpen: false
  property bool hoverContentAvailable:false
  property string alertKind: ""
  property bool hoverSuppressed: false
  property date now: new Date()
  readonly property bool opened: pinned
  readonly property string screenName: root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name : ""
  readonly property bool alertOnScreen: !service || !(alertKind==="t3" ? service.t3TargetScreen : service.targetScreen) || (alertKind==="t3" ? service.t3TargetScreen : service.targetScreen) === screenName
  readonly property bool showAlert: alertKind !== "" && alertOnScreen
  readonly property bool notificationToast: alertKind==="notification" && !pinned && !hoverOpen
  readonly property real displayScale: root.QsWindow.window ? root.QsWindow.window.devicePixelRatio : 1
  readonly property string configuredFormat: String(setting(vertical ? "verticalFormat" : "format",vertical ? "HH\n—\nmm" : "dddd HH:mm"))
  readonly property string clockText: formattedClock(configuredFormat)
  function formattedClock(format) {
    var week=Clock.isoWeekLiteral(now.getFullYear(),now.getMonth(),now.getDate()).split("").map(function(d){return Commons.I18n.formatNumber(d)}).join("")
    return now.toLocaleString(Qt.locale(Commons.I18n.formatLocale),format.replace(/ww/g,week))
  }
  function cycleClockFormat() {
    var ring=Clock.clockFormatRing(configuredFormat,setting(vertical ? "verticalFormatAlt" : "formatAlt",vertical ? "dd\nMMM\n'W'ww\n''yy" : "d MMMM 'W'ww yyyy"),Clock.clockFormats(vertical))
    updateSetting(vertical ? "verticalFormat" : "format",Clock.nextClockFormat(ring,configuredFormat))
  }
  function cyclePage(step) {
    var index=controlsMode ? 0 : calendarMode ? 2 : weatherMode ? 3 : 1
    previewContent.requestPage(Settings.nextPage(previewContent.enabledPages,index,step))
  }
  readonly property string barText: showAlert && alertKind!=="t3" && service && (alertKind!=="notification" || stripNotification) ? (alertKind === "notification" && service.latest ? (service.latest.downloadPath ? "󰇚  " : "󰂚  ") + service.latest.summary : "󰝚  " + strings.t("nowPlaying")) : clockText
  readonly property bool isHovered: trigger.tooltipHovered || preview.containsMouse
  readonly property string signature: service ? service.track + ":" + service.playing : ""

  function activateWeather() { if(Settings.get(settings,"weatherEnabled") && service && ("weather" in service)) service.weather.activate() }
  function syncContentPresentation() {
    // Coalesce interaction changes so an exit never applies the closed
    // presentation before its fade. A reopen uses the latest state instead.
    if (!preview.open) return
    previewContent.hovering = hoverOpen || pinned
    previewContent.alertKind = alertKind
  }
  function openPage(index) {
    if(Settings.pages(settings, !service || !("weather" in service) || service.weather.allowed).indexOf(index)<0) index=0
    controlsMode=index===0;calendarMode=index===2;weatherMode=index===3
    contentExpanded=true;pinned=true;hoverOpen=false;alertKind="";lastOpenedPage=index
    activateWeather()
    Qt.callLater(function(){previewContent.forceActiveFocus()})
  }
  function open() {openPage(Settings.openingPage(settings,lastOpenedPage))}
  function openOverview() {openPage(1)}
  function openCalendar() {
    openPage(2)
    if(calendarMode) previewContent.showToday()
  }
  function openWeather() {
    openPage(3)
  }
  function openControls() {
    openPage(0)
  }
  function toggleCalendar() { if (pinned && calendarMode) close(); else openCalendar() }
  function close() { hoverSuppressed = true; pinned = false; hoverOpen = false; alertKind = ""; hoverDelay.stop() }
  function toggle() { pinned ? close() : open() }
  function showT3Activity() {
    if(!service || !service.latestT3 || service.doNotDisturb || pinned || hoverOpen || alertKind==="notification" || !Settings.get(settings,"overviewEnabled")) return
    if(service.t3TargetScreen && service.t3TargetScreen!==screenName) return
    contentExpanded=false;controlsMode=false;calendarMode=false;weatherMode=false
    alertKind="t3";alertLife.interval=4000;alertLife.restart()
  }
  function showNotification() {
    if (!service || !service.latest || (service.targetScreen && service.targetScreen!==screenName) || pinned) return
    contentExpanded = false; alertKind = "notification"; alertLife.interval = Number(setting("notificationDuration",5000)); alertLife.restart()
  }
  function syncSettings() {
    Preferences.values=root.settings
    if(!Settings.get(settings,"hoverPreview") || !Settings.get(settings,"overviewEnabled")) {hoverDelay.stop();hoverOpen=false}
    if(!Settings.get(settings,"trackAlerts") && alertKind==="media") {alertKind="";alertLife.stop()}
    if(pinned && Settings.pages(settings).indexOf(controlsMode ? 0 : calendarMode ? 2 : weatherMode ? 3 : 1)<0) openControls()
    if (service && Array.isArray(setting("musicApps",null))) service.allowedPlayers = setting("musicApps",[])
    if(service && ("weather" in service)) {
      service.weather.allowed=setting("weatherEnabled",true)!==false
      service.weather.unitOverride=String(setting("weatherUnit",""))
      service.weather.temperatureOverride=String(setting("weatherTemperatureUnit",""))
      service.weather.refreshOverride=Number(setting("weatherRefreshMinutes",0)) || 0
    }
  }
  function updateSetting(key,value) {
    if(key==="calendarWeekStart" && value!=="sunday" && value!=="monday") return
    if(key==="weatherTemperatureUnit" && ["celsius","fahrenheit","kelvin"].indexOf(value)<0) return
    if(["recentMullvadRegions","calendarWeekStart","weatherTemperatureUnit","format","verticalFormat"].indexOf(key)<0 && !Settings.valid(key,value)) return
    var entry={id:root.moduleName}
    for(var name in root.settings) if(name!=="id") entry[name]=root.settings[name]
    entry[key]=value
    root.settings=entry
    if(root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName,entry)
  }
  onHoverOpenChanged: {
    Qt.callLater(function(){
      if(root.hoverOpen) {
        if(!root.pinned) {root.contentExpanded=false;root.controlsMode=false;root.calendarMode=false;root.weatherMode=false}
        root.activateWeather()
      }
      root.syncContentPresentation()
    })
  }
  onPinnedChanged: Qt.callLater(syncContentPresentation)
  onAlertKindChanged: Qt.callLater(syncContentPresentation)
  onServiceChanged: syncSettings()
  onSettingsChanged: syncSettings()
  onSignatureChanged: {
    if (Settings.get(settings,"trackAlerts") && service && service.playing && !pinned && alertKind !== "notification" && alertKind !== "t3") {
      alertKind = "media"; alertLife.interval = 3000; alertLife.restart()
    }
  }
  onIsHoveredChanged: {
    if (isHovered) { leaveGrace.stop(); if (!pinned && !hoverSuppressed && Settings.get(settings,"hoverPreview") && Settings.get(settings,"overviewEnabled")) hoverDelay.restart() }
    else { hoverSuppressed = false; hoverDelay.stop(); leaveGrace.restart() }
  }
  implicitWidth: vertical ? barSize : Math.min(Style.space(600),Math.max(Style.space(fixedEdge === "center" ? 360 : 0), clockMeasure.implicitWidth + 2*indicatorGutter + Style.space(fixedEdge === "center" ? 120 : 32), showAlert ? Style.space(420) : 0, showOsd ? osdMeasure.implicitWidth+2*indicatorGutter+Style.space(50) : 0))
  implicitHeight: vertical ? Math.max(Style.space(80),clockMeasure.implicitHeight+leftIndicators.implicitHeight+rightIndicators.implicitHeight+Style.space(24)) : barSize
  Behavior on implicitWidth { NumberAnimation { duration: Preferences.panelDuration(180); easing.type: Easing.OutCubic } }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  Connections { target: root.service; ignoreUnknownSignals:true; function onT3Arrival() {root.showT3Activity()} function onHasMediaChanged() { if (root.service && !root.service.hasMedia && root.alertKind === "media") { root.alertKind = ""; alertLife.stop() } } function onArrivalChanged() { root.showNotification() } function onLatestChanged() { if (root.service && !root.service.latest && root.alertKind === "notification") root.alertKind = "" } }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
  Timer { id: hoverDelay; interval: Settings.get(root.settings,"hoverDelay"); onTriggered: if (!root.pinned && !root.showOsd && !dictationOverlay.requested && root.isHovered && Settings.get(root.settings,"hoverPreview") && Settings.get(root.settings,"overviewEnabled")) { root.contentExpanded = false; root.hoverOpen = true } }
  Timer { id: leaveGrace; interval: 220; onTriggered: if (!root.pinned && !root.isHovered) root.hoverOpen = false }
  Timer { id: alertLife; objectName:"islandAlertLife"; interval: 3000; onTriggered: root.alertKind = "" }
  PlainText {id:osdMeasure;visible:false;text:root.indicators && ("osdMessage" in root.indicators) ? root.indicators.osdMessage : "";typeRole:"bar"}
  PlainText { id: clockMeasure; typeRole:"bar"; text: root.clockText; visible: false }
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
    tooltipText: [root.indicators && root.indicators.recording ? strings.t("indicator.recording") : "",root.indicators && root.indicators.remoteActive ? strings.t("indicator.remote") : "",root.indicators && root.indicators.microphoneMuted ? strings.t("indicator.microphoneMuted") : "",root.service && root.service.doNotDisturb ? strings.t("dnd") : "",root.indicators && root.indicators.nightLight ? strings.t("indicator.nightLight") : "",root.indicators && root.indicators.stayAwake ? strings.t("indicator.stayAwake") : "",root.indicators && root.indicators.updateAvailable ? strings.t("indicator.updateAvailable") : ""].filter(function(s){return s!==""}).join(" · ")
    onPressed: button => { if (button === Qt.RightButton) root.cycleClockFormat(); else if (button === Qt.MiddleButton) root.toggleCalendar(); else root.toggle() }
    onWheelMoved: delta => {if(delta) root.cyclePage(delta<0 ? 1 : -1)}
    ArtworkBackground {
      objectName: "islandClockArtwork"
      width: root.vertical ? parent.height : parent.width
      height: root.vertical ? parent.width : parent.height
      anchors.centerIn: parent
      rotation: root.vertical ? 90 : 0
      visible: !root.showAlert
      service: root.service
      monochrome: true
      horizontalFade: true
    }
    GridLayout {
      columns: root.vertical ? 1 : -1
      rows: root.vertical ? -1 : 1
      id:leftIndicators
      Item {
        id:t3Indicator
        objectName:"islandT3Indicator"
        visible:!!root.t3 && root.t3.allowed && (root.t3.waitingCount>0 || root.t3.workingCount>0)
        readonly property bool waiting:!!root.t3 && root.t3.waitingCount>0
        readonly property string text:Commons.I18n.formatNumber(root.t3 ? root.t3.waitingCount || root.t3.workingCount : 0)
        readonly property color color:root.showAlert ? Commons.Color.accent : root.bar ? root.bar.barForeground : Commons.Color.foreground
        implicitWidth:root.vertical ? Math.min(root.barSize-Style.space(4),t3IndicatorBody.implicitWidth) : t3IndicatorBody.implicitWidth;implicitHeight:t3IndicatorBody.implicitHeight
        GridLayout {
          columns:root.vertical ? 1 : -1
          rows:root.vertical ? -1 : 1
          id:t3IndicatorBody
          anchors.centerIn:parent
          width:parent.width
          columnSpacing:Style.space(4);rowSpacing:Style.space(4)
          T3Spinner {objectName:"islandT3Spinner";tint:t3Indicator.color;visible:!t3Indicator.waiting;active:t3Indicator.visible;implicitWidth:Style.space(14)}
          PlainText {visible:t3Indicator.waiting;text:"󰋗";color:t3Indicator.color;typeRole:"bar";Layout.alignment:Qt.AlignVCenter;verticalAlignment:Text.AlignVCenter}
          PlainText {objectName:"islandT3Count";Layout.maximumWidth:root.vertical ? root.barSize-Style.space(4) : Infinity;elide:Text.ElideRight;text:t3Indicator.text;color:t3Indicator.color;typeRole:"bar";font.family:root.bar ? root.bar.fontFamily : Style.font.family;Layout.preferredHeight:root.vertical ? Style.space(18) : trigger.height;verticalAlignment:Text.AlignVCenter}
        }
        MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.openOverview()}
      }
      objectName:"islandLeftIndicators"
      x: root.vertical ? (parent.width-width)/2 : centerContent.x+centerContent.width/2-centerContent.indicatorSpan/2-Style.space(11-5*root.osdShown)-width
      y: root.vertical ? Style.space(6) : (parent.height-height)/2
      z:1
      columnSpacing:Style.space(5)
      rowSpacing:Style.space(5)
      StatusBeacon {id:recordingBeacon;objectName:"islandRecordingIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activateIndicator("recording")} Layout.preferredHeight:root.vertical ? Style.space(18) : trigger.height;visible:Preferences.get("indicatorRecording") && root.indicators && root.indicators.recording;tint:Design.barDanger;waveWidth:root.vertical ? 0 : Math.max(0,trigger.width-leftIndicators.x-recordingBeacon.x)}
      StatusBeacon {id:remoteBeacon;objectName:"islandRemoteIndicator";Layout.preferredHeight:root.vertical ? Style.space(18) : trigger.height;visible:Preferences.get("indicatorRemote") && root.indicators && root.indicators.remoteActive;tint:Design.barAccent;waveWidth:root.vertical ? 0 : Math.max(0,trigger.width-leftIndicators.x-remoteBeacon.x)}
    }
    Item {
      id:centerContent
      objectName:"islandClockDisplay"
      width:Math.floor(Math.max(1,parent.width-(root.vertical ? Style.space(4) : 2*root.indicatorGutter+Style.space(18)))*root.displayScale)/root.displayScale
      height:root.vertical ? Math.max(clockMeasure.implicitHeight,Style.space(40)) : Math.floor(parent.height*root.displayScale)/root.displayScale
      x:Math.round((parent.width-width)*root.displayScale/2)/root.displayScale
      y:root.vertical ? leftIndicators.implicitHeight+Style.space(12)+(parent.height-leftIndicators.implicitHeight-rightIndicators.implicitHeight-Style.space(24)-height)/2 : Math.round((parent.height-height)*root.displayScale/2)/root.displayScale
      z:1
      readonly property real indicatorSpan: Math.min(width,clockLabel.contentWidth)*(1-root.osdShown)+osdGauge.contentWidth*root.osdShown
      // Keep a small cached surface so text antialiasing stays consistent
      // when the temporary shader is released. Software keeps the fade.
      layer.enabled: GraphicsInfo.api!==GraphicsInfo.Software
      layer.effect: root.osdTransitioning ? osdDissolve : null
      Component {
        id:osdDissolve
        BrailleDissolve {
          objectName:"islandOsdDissolve"
          size:Qt.vector2d(centerContent.width,centerContent.height)
          amount:4*root.osdShown*(1-root.osdShown)
        }
      }
      PlainText {
        id:clockLabel
        objectName:"islandClockText"
        typeRole:"bar"
        width:Math.min(parent.width,Math.ceil(implicitWidth*root.displayScale)/root.displayScale)
        height:parent.height
        x:Math.round((parent.width-width)*root.displayScale/2)/root.displayScale
        horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
        opacity:1-root.osdShown
        visible:opacity>0
        text: root.vertical ? root.clockText : root.barText
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        color: root.showAlert ? Commons.Color.accent : root.bar ? root.bar.barForeground : Commons.Color.foreground
      }
      PlainText {
        objectName:"islandVerticalOsd"
        anchors.fill:parent
        visible:root.vertical && root.osdShown>0
        opacity:root.osdShown
        text:osdGauge.displayGlyph+"\n"+(osdGauge.hasProgress ? (osdGauge.valueText || Commons.I18n.formatNumber(Math.round(osdGauge.value*100))+"%") : osdGauge.message)
        typeRole:"caption"
        horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
        wrapMode:Text.WrapAnywhere
        maximumLineCount:3
        elide:Text.ElideRight
      }
      BrailleGauge {
        id:osdGauge
        objectName:"islandOsdGauge";anchors.fill:parent;opacity:root.osdShown;visible:opacity>0 && !root.vertical
        animateEvents:Preferences.get("panelAnimation") && root.showOsd && root.osdShown===1
        kind:root.indicators ? root.indicators.osdKind : "volume"
        value:root.indicators ? root.indicators.osdValue : 0
        muted:root.indicators ? root.indicators.osdMuted : false
        hasProgress:!root.indicators || !("osdHasProgress" in root.indicators) || root.indicators.osdHasProgress
        glyph:root.indicators && ("osdIcon" in root.indicators) ? root.indicators.osdIcon : ""
        message:root.indicators && ("osdMessage" in root.indicators) ? root.indicators.osdMessage : ""
        valueText:root.indicators && ("osdProgressText" in root.indicators) ? root.indicators.osdProgressText : ""
      }
    }
    GridLayout {
      columns: root.vertical ? 1 : -1
      rows: root.vertical ? -1 : 1
      id:rightIndicators
      objectName:"islandRightIndicators"
      x: root.vertical ? (parent.width-width)/2 : centerContent.x+centerContent.width/2+centerContent.indicatorSpan/2+Style.space(11-5*root.osdShown)
      y: root.vertical ? parent.height-height-Style.space(6) : (parent.height-height)/2
      columnSpacing:Style.space(5)
      rowSpacing:Style.space(5)
      z:1
      StatusBeacon {
        id:updateBeacon
        objectName:"islandUpdateIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activateIndicator("update")}
        Layout.preferredHeight:root.vertical ? Style.space(18) : trigger.height
        visible:Preferences.get("indicatorUpdate") && !!root.indicators && !!root.indicators.updateAvailable
        tint:Commons.Color.foreground
        glyph:""
        bidirectional:true
        waveWidth:root.vertical ? 0 : trigger.width
        waveOffset:-rightIndicators.x-updateBeacon.x
      }
      PlainText {objectName:"islandMicrophoneIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activateIndicator("microphone")} visible:Preferences.get("indicatorMicrophone") && root.indicators && root.indicators.microphoneMuted;text:"󰍭";font.pixelSize:Math.round(Style.font.icon*0.85);color:clockLabel.color}
      PlainText {objectName:"islandDndIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activateIndicator("dnd")} visible:Preferences.get("indicatorDnd") && root.service !== null && root.service.doNotDisturb;text:"󰂛";font.pixelSize:Math.round(Style.font.icon*0.85);color:clockLabel.color}
      PlainText {objectName:"islandNightLightIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activateIndicator("nightLight")} visible:Preferences.get("indicatorNightLight") && root.indicators && root.indicators.nightLight;text:"󰔎";font.pixelSize:Math.round(Style.font.icon*0.85);color:clockLabel.color}
      PlainText {objectName:"islandStayAwakeIndicator"; MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.activateIndicator("stayAwake")} visible:Preferences.get("indicatorStayAwake") && root.indicators && root.indicators.stayAwake;text:"";font.pixelSize:Math.round(Style.font.icon*0.85);color:clockLabel.color}
    }
  }
  Loader {
    id:dictationOverlay
    property bool retaining:false
    function release() {if(item && !item.open && item.shown===0) retaining=false}
    readonly property var dictation:root.service && ("dictation" in root.service) ? root.service.dictation : null
    readonly property bool requested:!!dictation && dictation.showing && (!dictation.screenName || dictation.screenName===root.screenName)
    active:requested || retaining
    onLoaded:retaining=true
    Component.onCompleted:setSource(Qt.resolvedUrl("DictationOsd.qml"),{dictation:Qt.binding(function(){return dictationOverlay.dictation}),anchorItem:trigger,bar:root.bar,open:Qt.binding(function(){return dictationOverlay.requested})})
  }
  Connections {
    target:dictationOverlay.item
    function onShownChanged() {Qt.callLater(dictationOverlay.release)}
    function onOpenChanged() {Qt.callLater(dictationOverlay.release)}
  }
  IslandPopup {
    id: preview
    objectName: "islandPopup"
    anchorItem: trigger
    bar: root.bar
    owner: root
    triggerMode: root.pinned ? "click" : "hover"
    centerOnBar: false
    alignmentItem: clockLabel
    open: root.pinned || (root.hoverOpen && root.hoverContentAvailable) || (root.showAlert && !root.stripNotification)
    frameless: root.notificationToast || bareCard
    bareCard: root.alertKind==="t3" && !root.pinned && !root.hoverOpen
    onBackgroundClicked: position => {previewContent.cancelEdits();panelGlow.pulse(Qt.point(position.x+(preview.layoutWidth-preview.drawnWidth)/2,position.y))}
    onVisibleChanged: if (!visible) Qt.callLater(function(){
      if(!preview.visible && !preview.open) {root.contentExpanded=false;root.calendarMode=false;root.weatherMode=false;root.controlsMode=false}
    })
    contentWidth: fittedContentWidth(Style.space(root.contentExpanded ? 480 : root.notificationToast ? 300 : 440))
    contentHeight: fittedContentHeight(previewContent.implicitHeight)
    ToastWaves {
      id:notificationWaves
      objectName: "islandToastWaves"
      property var sourceIcon:previewContent.notificationIcon
      function updateOrigin() {
        if(!sourceIcon) return
        var center=sourceIcon.mapToItem(notificationWaves,sourceIcon.width/2,sourceIcon.height/2)
        origin=Qt.vector2d(center.x,center.y)
      }
      // The entrance moves/scales the card inside a stable Wayland surface.
      FrameAnimation {
        running:notificationWaves.active && notificationWaves.visible && !Preferences.reduceMotion
        onTriggered:notificationWaves.updateOrigin()
      }
      onSourceIconChanged:Qt.callLater(updateOrigin)
      onActiveChanged:Qt.callLater(updateOrigin)
      onWidthChanged:Qt.callLater(updateOrigin)
      onHeightChanged:Qt.callLater(updateOrigin)
      Connections {
        target:notificationWaves.sourceIcon
        function onXChanged() {Qt.callLater(notificationWaves.updateOrigin)}
        function onYChanged() {Qt.callLater(notificationWaves.updateOrigin)}
        function onWidthChanged() {Qt.callLater(notificationWaves.updateOrigin)}
        function onHeightChanged() {Qt.callLater(notificationWaves.updateOrigin)}
      }
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.leftMargin: -preview.padding; anchors.rightMargin: -preview.padding; anchors.topMargin: -preview.padding
      height: preview.layoutHeight
      active: preview.frameSuppressed && preview.visible
    }
    ArtworkBackground {
      objectName: "islandPopupArtwork"
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.leftMargin: -preview.padding; anchors.rightMargin: -preview.padding; anchors.topMargin: -preview.padding
      height: Math.min(preview.contentHeight,Style.space(root.contentExpanded ? 285 : 175)+previewContent.contentTop)
      reveal: 1-previewContent.pageProgress
      // Let the last dithered dots finish disappearing after the page settles.
      visible: opacity>0.001 && artworkReveal>0.001 && preview.visible && !preview.frameSuppressed
      service: root.service
    }
    BrailleSpotlight {
      id: panelGlow
      surfaceRoot: previewContent
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
      onImplicitHeightChanged:Qt.callLater(function(){root.hoverContentAvailable=previewContent.implicitHeight>0})
      objectName:"islandPopupPages"
      keyboardActive:root.pinned && preview.open
      settings: root.settings
      onSettingRequested:(key,value)=>root.updateSetting(key,value)
      externalFeedback: panelFeedback
      controls: root.controlsMode
      calendar: root.calendarMode
      weather: root.weatherMode
      compactNotifications: preview.frameSuppressed && !root.pinned && !root.hoverOpen
      radialBraille: root.setting("radialBraille",true)
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      service: root.service; strings: strings; bar: root.bar
      expanded: root.contentExpanded
      focus: root.pinned
      Keys.onEscapePressed: {if(!previewContent.back()) root.close()}
      Keys.onSpacePressed: event => { if (!root.controlsMode && !root.calendarMode && !root.weatherMode && root.service) root.service.media("toggle"); else event.accepted = false }

      onExpandRequested: root.openOverview()
      onControlsRequested: root.openControls()
      onDismissRequested: root.close()
      onCalendarRequested: root.openCalendar()
      onWeatherRequested: root.openWeather()
      onInboxRequested: root.openOverview()
    }
  }
  ShellIpc {
    target: "island"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function controls(): void { root.openControls() }
    function calendar(): void { root.openCalendar() }
    function weather(): void { root.openWeather() }
    function toggle(): void { root.toggle() }
    function hover(): void { if(Settings.get(root.settings,"hoverPreview") && Settings.get(root.settings,"overviewEnabled")) root.hoverOpen = !root.hoverOpen }
    function status(): string { return JSON.stringify({pinned:root.pinned,page:root.controlsMode ? "controls" : root.weatherMode ? "weather" : root.calendarMode ? "calendar" : "inbox",hover:root.hoverOpen,alert:root.alertKind,service:root.service!==null,screen:root.screenName,appearance:preview.entranceStyle || "legacy"}) }
  }
}
