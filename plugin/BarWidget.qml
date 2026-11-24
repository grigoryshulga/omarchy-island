import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "ClockModel.js" as Clock
import "CornerGeometry.js" as Corners
import "ModuleCatalog.mjs" as Catalog
import "NowActivity.mjs" as NowActivity
import "NowPresentation.js" as NowPresentation
import "ClockLayout.mjs" as ClockLayout
import "SettingsModel.mjs" as Settings

BarWidget {
  id: root
  moduleName: "gshulga.island"
  property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  property bool ipcEnabled: true
  property bool standalone: false
  readonly property bool pillInteractive: !preview.morphFromAnchor && !preview.replacingAnchor
  readonly property real pillOpacity: 1 - Math.max(preview.anchorCoverage,
    Preferences.panelDuration(1) ? pillFade : Number(preview.morphFromAnchor && !preview.morphing))
  property real pillFade: preview.morphFromAnchor && !preview.morphing ? 1 : 0
  Behavior on pillFade {
    NumberAnimation { duration: Preferences.panelDuration(root.pinned ? 140 : 170); easing.type: Easing.OutCubic }
  }
  readonly property var indicators: service && ("indicators" in service) ? service.indicators : null
  readonly property string moduleTooltips: [leftIndicators.tooltips,rightIndicators.tooltips].filter(Boolean).join(" · ")
  readonly property var moduleStrings:strings
  readonly property var clockLayout:ClockLayout.layout(ClockLayout.catalog(Catalog.ordered("indicator")),Settings.get(settings,"clockLayout"),settings)
  property var registeredIndicators: null
  readonly property bool showOsd: indicators && indicators.osdActive && (!indicators.osdScreen || indicators.osdScreen===screenName)
  property real osdShown:showOsd ? 1 : 0
  readonly property bool osdTransitioning: osdShown>0 && osdShown<1 && !Preferences.reduceMotion && Preferences.get("panelAnimation")
  Behavior on osdShown {NumberAnimation {duration:Preferences.panelDuration(root.showOsd ? 240 : 200);easing.type:Easing.OutCubic}}
  readonly property real indicatorGutter: vertical ? 0 : Math.max(leftIndicators.implicitWidth,rightIndicators.implicitWidth)>0 ? Math.max(leftIndicators.implicitWidth,rightIndicators.implicitWidth)+Style.space(11) : 0
  readonly property real indicatorGap: Style.space(11 - 5 * osdShown)
  readonly property real leftInset: Design.gap.medium + (leftIndicators.implicitWidth > 0 ? leftIndicators.implicitWidth + indicatorGap : 0)
  readonly property real rightInset: Design.gap.medium + (rightIndicators.implicitWidth > 0 ? rightIndicators.implicitWidth + indicatorGap : 0)
  property var execute:function(argv){Util.execArgv(argv)}
  function activateIndicator(mode) {
    if (mode==="update") {
      execute(["omarchy-launch-floating-terminal-with-presentation","omarchy-update"])
    } else if (mode==="remote") {
      openControls()
    } else if (mode==="dnd") {
      openModuleDetails("notifications")
    } else {
      openModuleDetails("controls",mode==="microphone" ? {section:"audio"} : {tile:mode})
    }
  }
  function quickIndicatorAction(mode) {
    if(mode==="dnd") {if(service) service.setDoNotDisturb(false);return}
    if(mode==="nightLight" || mode==="stayAwake") {
      IpcRegistry.call(mode==="nightLight" ? "nightlight" : "idle","toggle",[])
      if(indicators && ("refreshControls" in indicators)) indicators.refreshControls()
      return
    }
    var commands={
      microphone:["omarchy-audio-input-mute"],
      recording:["omarchy-capture-screenrecording","--stop-recording"]
    }
    if(commands[mode]) execute(commands[mode])
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
  readonly property bool stripNotification: !standalone && !vertical && notificationToast && Settings.get(settings,"notificationStyle")==="bar"
  property bool contentExpanded: false
  property int selectedPage:1
  readonly property bool controlsMode:selectedPage===1 && previewContent.controls
  readonly property bool calendarMode:selectedPage===2
  readonly property bool weatherMode:selectedPage===3
  property bool hoverOpen: false
  property string alertKind: ""
  property bool hoverSuppressed: false
  property date now: new Date()
  readonly property bool opened: pinned
  readonly property string screenName: root.QsWindow.window && root.QsWindow.window.screen ? root.QsWindow.window.screen.name : ""
  readonly property string alertScreen: !service || alertKind==="media" ? ""
    : alertKind==="herdr" ? service.herdrTargetScreen : alertKind==="t3" ? service.t3TargetScreen : service.targetScreen || ""
  readonly property bool alertOnScreen: !alertScreen || alertScreen===screenName
  readonly property bool showAlert: alertKind !== "" && alertOnScreen
  readonly property bool notificationToast: alertKind==="notification" && !pinned && !hoverOpen
  readonly property bool adaptiveToast: standalone && notificationToast
  readonly property real toastWidth: {
    const row = adaptiveToast && service ? service.latest : null
    if (!row) return Style.space(300)
    const title = toastTitleMetrics.advanceWidth(String(row.filename || row.summary || "").slice(0, 180))
    const body = toastCaptionMetrics.advanceWidth(Model.plain(row.body).slice(0, 180))
    const count = service.notifications && !row.downloadPath ? service.notifications.toastCount : 0
    const suffix = count>1 ? strings.tn("notifications.new",count).arg(Commons.I18n.formatNumber(count)) : "00:00"
    const header = toastCaptionMetrics.advanceWidth(Model.source(row).slice(0, 64) + "  " + suffix) + Style.space(24)
    return Math.min(Style.space(440), Math.max(Style.space(192), Math.max(title, body, header) + Style.space(40)))
  }
  property real toastOpacity: 1
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
    var index=selectedPage
    previewContent.requestPage(Settings.nextPage(previewContent.enabledPages,index,step))
  }
  readonly property string barText: !standalone && showAlert && alertKind!=="t3" && alertKind!=="herdr" && service && (alertKind!=="notification" || stripNotification) ? (alertKind === "notification" && service.latest ? (service.latest.downloadPath ? "󰇚  " : "󰂚  ") + service.latest.summary : "󰝚  " + strings.t("nowPlaying")) : clockText
  readonly property bool isHovered: barHover.hovered || nowPointerInside || preview.containsMouse
  HoverHandler {
    id:barHover
    enabled: !root.standalone || root.pillInteractive
    onHoveredChanged:if(hovered) Qt.callLater(function(){
      if(barHover.hovered && !root.nowPointerInside) root.nowHover=false
    })
  }
  readonly property string signature: service ? service.track + ":" + service.playing : ""

  function activateWeather() { if(Settings.get(settings,"weatherEnabled") && service && service.weather) service.weather.activate() }
  function syncContentPresentation() {
    // Coalesce interaction changes so an exit never applies the closed
    // presentation before its fade. A reopen uses the latest state instead.
    if (!preview.open) return
    previewContent.hovering = hoverOpen || pinned
    previewContent.alertKind = alertKind
  }
  function openPage(index) {
    if(Settings.pages(settings, !service || !service.weather || service.weather.allowed).indexOf(index)<0) index=1
    selectedPage=index
    contentExpanded=true;pinned=true;hoverOpen=false;alertKind="";lastOpenedPage=index
    activateWeather()
    previewContent.enterPage(index)
    Qt.callLater(function(){previewContent.forceActiveFocus()})
  }
  function open() {openPage(Settings.openingPage(settings,lastOpenedPage))}
  function openOverview() {openPage(1)}
  function openCalendar() {openPage(2)}
  function openWeather() {
    openPage(3)
  }
  property bool nowPointerInside: false
  property bool nowHover: false
  readonly property var activities:NowActivity.activities(service)
  property var hoveredActivity:null
  readonly property var previewActivity: hoverOpen && nowHover && !pinned && hoveredActivity
    ? activities.find(row=>row.id===hoveredActivity.id) || hoveredActivity : null
  onClockLayoutChanged:if(!clockLayout.some(function(row){return row.id==="now"})) {
    nowPointerInside=false
    nowHover=false
  }
  function trackNowHover(inside,activity) {
    nowPointerInside=inside
    // Keep the activity preview during the pointer crossing to its surface.
    if (inside) {hoveredActivity=activity;nowHover=true}
    else Qt.callLater(function(){if(!root.nowPointerInside && barHover.hovered && !preview.containsMouse) nowHover=false})
  }
  function openNow(activity) {
    if (!activity) return
    openModuleDetails(activity.kind,NowActivity.target(activity))
  }
  function openModuleDetails(moduleId,target) {
    openPage(1)
    Qt.callLater(function(){if(root.pinned && root.selectedPage===1) previewContent.openDetails(moduleId,target)})
  }
  function openControls() {openModuleDetails("controls")}
  function toggleCalendar() { if (pinned && calendarMode) close(true); else openCalendar() }
  function close(suppressHover) {
    // An outside dismissal has already left the hover region; waiting for
    // another exit would swallow the next entry. Clock toggles explicitly
    // suppress re-entry when the pinned surface was covering the clock.
    hoverSuppressed = suppressHover === true || isHovered
    pinned = false; hoverOpen = false; alertKind = ""; hoverDelay.stop()
  }
  function toggle() { pinned ? close(true) : open() }
  function ipcStatus() {
    return JSON.stringify({pinned:pinned,page:controlsMode ? "controls" : weatherMode ? "weather" : calendarMode ? "calendar" : "inbox",hover:hoverOpen,alert:alertKind,service:!!service,screen:screenName,appearance:preview.entranceStyle || "legacy"})
  }
  function openSettings() {
    var overview = previewContent.pageObject(1)
    if (overview) overview.openSettings()
  }
  function toggleHover() {
    if(Settings.get(settings,"hoverPreview") && Settings.get(settings,"overviewEnabled")) hoverOpen = !hoverOpen
  }
  function dismissAlert(kind) {
    if (alertKind !== kind) return
    alertKind = ""
    alertLife.stop()
  }
  readonly property bool automaticPopupBlocked: standalone && !!bar && !!bar.activePopout
    && bar.activePopout !== popupCoordinator && bar.activePopout.pinned === true
  function needsAgentInput(kind,row) {
    return !!row && (kind==="t3" ? !!row.requestId : kind==="herdr" && row.status==="blocked")
  }
  function showAgentActivity(kind,row,screen) {
    if(!row || service.doNotDisturb || pinned || hoverOpen || automaticPopupBlocked || alertKind==="notification" || !Settings.get(settings,"overviewEnabled")) return
    if(screen && screen!==screenName) return
    const current=alertKind==="t3" ? service.latestT3 : alertKind==="herdr" ? service.latestHerdr : null
    if (alertKind!==kind && needsAgentInput(alertKind,current) && !needsAgentInput(kind,row)) return
    contentExpanded=false;selectedPage=1
    alertKind=kind;alertLife.interval=4000;alertLife.restart()
    Qt.callLater(notificationWaves.play)
  }
  function showNotification() {
    if (!service || !service.latest || (service.targetScreen && service.targetScreen!==screenName) || pinned || automaticPopupBlocked) return
    const sameSeries=notificationToast && !service.latest.downloadPath && service.notifications && service.notifications.toastCount>1
    if (!sameSeries && adaptiveToast && preview.open && Preferences.panelDuration(1) > 0) {
      toastSwap.stop()
      toastOpacity = 0
      toastSwap.start()
    }
    contentExpanded = false; alertKind = "notification"; alertLife.interval = Number(setting("notificationDuration",5000)); alertLife.restart()
    if (!sameSeries) Qt.callLater(notificationWaves.play)
  }
  function syncSettings() {
    Preferences.values=root.settings
    if(!Settings.get(settings,"hoverPreview") || !Settings.get(settings,"overviewEnabled")) {hoverDelay.stop();hoverOpen=false}
    if(!Settings.get(settings,"trackAlerts")) dismissAlert("media")
    if(pinned && Settings.pages(settings).indexOf(selectedPage)<0) openControls()
    if(service && service.modules && service.modules.media) service.modules.media.allowedPlayers=Array.isArray(setting("musicApps",null)) ? setting("musicApps",[]) : []
  }
  function updateSetting(key,value) {
    if(key==="weatherTemperatureUnit" && ["celsius","fahrenheit","kelvin"].indexOf(value)<0) return
    if(["recentMullvadRegions","weatherTemperatureUnit","format","verticalFormat"].indexOf(key)<0 && !Settings.valid(key,value)) return
    var entry={id:root.moduleName}
    for(var name in root.settings) if(name!=="id") entry[name]=root.settings[name]
    entry[key]=value
    root.settings=entry
    if(root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName,entry)
  }
  onHoverOpenChanged: {
    Qt.callLater(function(){
      if(!root.hoverOpen && !barHover.hovered) root.nowHover=false
      if(root.hoverOpen) {
        if(!root.pinned) {root.contentExpanded=false;root.selectedPage=1}
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
    // Route this track change once. Focus changes alone never move or replay a toast.
    dismissAlert("media")
    if (Settings.get(settings,"trackAlerts") && service && service.playing && !service.doNotDisturb
        && (!service.focusedScreenName || service.focusedScreenName===screenName)
        && !pinned && !hoverOpen && !automaticPopupBlocked && !alertKind) {
      alertKind = "media"; alertLife.interval = 3000; alertLife.restart()
    }
  }
  onShowOsdChanged: if(!showOsd && isHovered && !pinned && !hoverOpen && !hoverSuppressed) hoverDelay.restart()
  onIsHoveredChanged: {
    if (isHovered) { leaveGrace.stop(); if (!pinned && !hoverSuppressed && Settings.get(settings,"hoverPreview") && Settings.get(settings,"overviewEnabled")) hoverDelay.restart() }
    else { hoverSuppressed = false; hoverDelay.stop(); leaveGrace.restart() }
  }
  readonly property real clockHeight: standalone && !showOsd && osdShown <= 0
    ? clockMeasure.implicitHeight : Math.max(clockMeasure.implicitHeight, Style.space(40))
  readonly property real standaloneWidth: Math.max(clockMeasure.implicitWidth, showOsd || osdShown > 0 ? osdGauge.implicitWidth : 0)
    + leftInset + rightInset
  implicitWidth: vertical ? barSize : Math.min(Style.space(600), standalone ? standaloneWidth
    : Math.max(Style.space(fixedEdge === "center" ? 360 : 0), clockMeasure.implicitWidth + 2*indicatorGutter + Style.space(fixedEdge === "center" ? 120 : 32), showAlert ? Style.space(420) : 0, showOsd ? osdMeasure.implicitWidth+2*indicatorGutter+Style.space(50) : 0))
  implicitHeight: vertical ? Math.max(standalone ? 0 : Style.space(80),
    (standalone ? clockHeight : clockMeasure.implicitHeight) + leftIndicators.implicitHeight + rightIndicators.implicitHeight + Style.space(24)) : barSize
  Behavior on implicitWidth { NumberAnimation { duration: Preferences.panelDuration(180); easing.type: Easing.OutCubic } }
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  Connections {
    target: root.service
    ignoreUnknownSignals: true

    function onDoNotDisturbChanged() {
      if (root.service.doNotDisturb) {
        root.dismissAlert("media")
        root.dismissAlert("t3")
      }
    }
    function onHerdrArrival() { root.showAgentActivity("herdr",root.service.latestHerdr,root.service.herdrTargetScreen) }
    function onLatestHerdrChanged() {
      if (root.service && !root.service.latestHerdr) root.dismissAlert("herdr")
    }
    function onT3Arrival() { root.showAgentActivity("t3",root.service.latestT3,root.service.t3TargetScreen) }
    function onLatestT3Changed() {
      if (root.service && !root.service.latestT3) root.dismissAlert("t3")
    }
    function onHasMediaChanged() {
      if (root.service && !root.service.hasMedia) root.dismissAlert("media")
    }
    function onArrivalChanged() { root.showNotification() }
    function onLatestChanged() {
      if (root.service && !root.service.latest) root.dismissAlert("notification")
    }
  }
  // Epoch scheduling follows Omarchy's WallClock and remains positive across
  // DST folds. Only formats displaying seconds need second-by-second work.
  Timer {
    id: clockTick
    objectName: "islandClockTick"
    readonly property int step: Clock.clockNeedsSeconds(root.configuredFormat) ? 1000 : 60000
    function arm() {interval=Clock.msUntilNextTick(Date.now(),step);restart()}
    onStepChanged: {root.now=new Date();arm()}
    onTriggered: {root.now=new Date();arm()}
    Component.onCompleted: arm()
  }
  Timer { id: hoverDelay; interval: Settings.get(root.settings,"hoverDelay"); onTriggered: if (!root.pinned && !root.automaticPopupBlocked && !root.showOsd && !dictationOverlay.presented && root.isHovered && Settings.get(root.settings,"hoverPreview") && Settings.get(root.settings,"overviewEnabled")) { root.contentExpanded = false; root.hoverOpen = true } }
  Timer { id: leaveGrace; interval: 220; onTriggered: if (!root.pinned && !root.isHovered) root.hoverOpen = false }
  Timer { id: alertLife; objectName:"islandAlertLife"; interval: 3000; onTriggered: root.alertKind = "" }
  SequentialAnimation {
    id: toastSwap
    PauseAnimation { duration: Preferences.panelDuration(55) }
    NumberAnimation { target: root; property: "toastOpacity"; to: 1; duration: Preferences.panelDuration(145); easing.type: Easing.OutCubic }
  }
  FontMetrics { id: toastTitleMetrics; font.family: Design.fontFamily; font.pixelSize: Design.type.body }
  FontMetrics { id: toastCaptionMetrics; font.family: Design.fontFamily; font.pixelSize: Design.type.caption }
  PlainText {id:osdMeasure;visible:false;text:root.indicators && ("osdMessage" in root.indicators) ? root.indicators.osdMessage : "";typeRole:"bar"}
  PlainText { id: clockMeasure; typeRole:"bar"; text: root.clockText; visible: false }
  WidgetButton {
    id: trigger
    objectName: "islandClock"
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    interactive: !root.standalone || root.pillInteractive
    fixedWidth: root.implicitWidth
    fixedHeight: root.implicitHeight
    pressFeedbackButtons: Qt.NoButton
    tooltipText:root.moduleTooltips
    function triggerPressAt(button,point) {
      var cell=leftIndicators.actionAt(trigger,point) || rightIndicators.actionAt(trigger,point)
      if (cell && button!==Qt.MiddleButton) cell.triggerPress(button,cell.mapFromItem(trigger,point))
      else triggerPress(button)
    }
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
    ClockIndicatorStrip {
      id:leftIndicators
      elements:root.clockLayout.filter(function(row){return row.side==="left"})
      service:root.service;settings:root.settings;strings:root.moduleStrings
      vertical:root.vertical;barSize:root.barSize;barHeight:root.vertical ? root.barSize : trigger.height
      bar:root.bar;showAlert:root.showAlert;foreground:clockLabel.color
      waveSpan:trigger.width
      z:1
      objectName:"islandLeftIndicators"
      x: root.vertical ? (parent.width-width)/2 : centerContent.x+centerContent.width/2-centerContent.indicatorSpan/2-root.indicatorGap-width
      y: root.vertical ? Style.space(6) : (parent.height-height)/2
      onActivate:mode=>root.activateIndicator(mode)
      onQuickAction:mode=>root.quickIndicatorAction(mode)
      onPageRequested:index=>root.openPage(index)
      onDetailsRequested:moduleId=>root.openModuleDetails(moduleId)
      onCalendarRequested:root.openCalendar()
      onNowRequested:activity=>root.openNow(activity)
      activities:root.activities
      onNowListRequested:root.openModuleDetails("now")
      onNowHovered:(inside,activity)=>root.trackNowHover(inside,activity)
    }
    Item {
      id:centerContent
      objectName:"islandClockDisplay"
      width:Math.floor(Math.max(1,parent.width-(root.vertical ? Style.space(4) : root.standalone
        ? root.leftInset+root.rightInset : 2*root.indicatorGutter+Style.space(18)))*root.displayScale)/root.displayScale
      height:root.vertical ? root.clockHeight : Math.floor(parent.height*root.displayScale)/root.displayScale
      x:Math.round((root.standalone && !root.vertical ? root.leftInset : (parent.width-width)/2)*root.displayScale)/root.displayScale
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
    ClockIndicatorStrip {
      id:rightIndicators
      elements:root.clockLayout.filter(function(row){return row.side==="right"})
      service:root.service;settings:root.settings;strings:root.moduleStrings
      vertical:root.vertical;barSize:root.barSize;barHeight:root.vertical ? root.barSize : trigger.height
      bar:root.bar;showAlert:root.showAlert;foreground:clockLabel.color
      waveSpan:trigger.width
      z:1
      objectName:"islandRightIndicators"
      x: root.vertical ? (parent.width-width)/2 : centerContent.x+centerContent.width/2+centerContent.indicatorSpan/2+root.indicatorGap
      y: root.vertical ? parent.height-height-Style.space(6) : (parent.height-height)/2
      onActivate:mode=>root.activateIndicator(mode)
      onQuickAction:mode=>root.quickIndicatorAction(mode)
      onPageRequested:index=>root.openPage(index)
      onDetailsRequested:moduleId=>root.openModuleDetails(moduleId)
      onCalendarRequested:root.openCalendar()
      onNowRequested:activity=>root.openNow(activity)
      activities:root.activities
      onNowListRequested:root.openModuleDetails("now")
      onNowHovered:(inside,activity)=>root.trackNowHover(inside,activity)
    }
  }
  Loader {
    id:dictationOverlay
    property bool retaining:false
    function release() {if(item && !item.open && item.shown===0) retaining=false}
    readonly property var dictation:root.service && ("dictation" in root.service) ? root.service.dictation : null
    readonly property bool requested:!!dictation && dictation.showing && (!dictation.screenName || dictation.screenName===root.screenName)
    readonly property bool presented:item ? item.presented : requested
    active:requested || retaining
    onLoaded:retaining=true
    Component.onCompleted:setSource(Qt.resolvedUrl("DictationOsd.qml"),{dictation:Qt.binding(function(){return dictationOverlay.dictation}),anchorItem:trigger,bar:root.bar,open:Qt.binding(function(){return dictationOverlay.requested})})
  }
  Connections {
    target:dictationOverlay.item
    function onShownChanged() {Qt.callLater(dictationOverlay.release)}
    function onOpenChanged() {Qt.callLater(dictationOverlay.release)}
  }
  // Keep popout coordination without the bar marking the clock as its owner.
  Item {id:popupCoordinator;readonly property bool pinned:root.pinned;function close(){root.close()}}
  IslandPopup {
    id: preview
    objectName: "islandPopup"
    anchorItem: trigger
    bar: root.bar
    owner: popupCoordinator
    triggerMode: root.pinned ? "click" : "hover"
    centerOnBar: root.standalone
    alignmentItem: root.standalone ? trigger : clockLabel
    morphFromAnchor: root.standalone && (root.pinned || (root.showAlert && !root.hoverOpen))
    forwardAnchorClicks: !root.standalone
    // The hover header is always present. Open before measuring its layout;
    // a hidden surface cannot polish the first preview's content height.
    open: root.pinned || root.hoverOpen || (root.showAlert && !root.stripNotification)
    dismissOnRightClick: root.showAlert && !root.pinned && !root.hoverOpen
    frameless: root.notificationToast || bareCard
    bareCard: (root.alertKind==="t3" || root.alertKind==="herdr" || root.alertKind==="media") && !root.pinned && !root.hoverOpen
    onBackgroundClicked: position => {previewContent.cancelEdits();panelGlow.pulse(Qt.point(position.x+(preview.layoutWidth-preview.drawnWidth)/2,position.y))}
    onVisibleChanged: if (!visible) Qt.callLater(function(){
      if(!preview.visible && !preview.open) {root.contentExpanded=false;root.selectedPage=1}
    })
    contentWidth: fittedContentWidth(root.adaptiveToast ? root.toastWidth
      : Style.space(root.contentExpanded ? 480 : root.notificationToast ? 300 : 440))
    contentFade: root.adaptiveToast && animateMorph ? root.toastOpacity : 1
    fitEventContent: frameSuppressed
    fileDragActive: !!root.service && !!root.service.downloadsState && !!root.service.downloadsState.fileDragSource
    contentHeight: fittedContentHeight(root.previewActivity ? nowPreview.implicitHeight : previewContent.implicitHeight)
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
      active: preview.frameSuppressed && preview.paintOpen && !previewContent.mediaToast
    }
    ArtworkBackground {
      objectName: "islandPopupArtwork"
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.leftMargin: -preview.padding; anchors.rightMargin: -preview.padding; anchors.topMargin: -preview.padding
      height: Math.min(preview.contentHeight,Style.space(root.contentExpanded ? 285 : 175)+previewContent.contentTop)
      reveal: 1-previewContent.pageProgress
      // Let the last dithered dots finish disappearing after the page settles.
      visible: opacity>0.001 && artworkReveal>0.001 && preview.visible && (!preview.frameSuppressed || previewContent.mediaToast)
      service: root.service
    }
    BrailleSpotlight {
      id: panelGlow
      surfaceRoot: previewContent
      objectName: "islandPanelSpotlight"
      cornerPower: CornerStyle.roundingPower
      cornerRadius: Corners.effectiveRadius(Style.cornerRadius,cornerPower,width,height)
      x: -preview.insetLeft; y: -preview.insetTop
      width: preview.layoutWidth; height: preview.layoutHeight
      z: 10
      active: preview.containsMouse && preview.visible
      pointer: Qt.point(preview.hoverPosition.x+(preview.layoutWidth-preview.drawnWidth)/2,preview.hoverPosition.y)
      adaptive: root.setting("radialBraille",true)
      artworkUrl: Preferences.get("musicVisualizationBackground")==="artwork" && root.service && root.service.player ? root.service.player.trackArtUrl : ""
      artworkStrength: previewContent.musicHovered ? 1 : 0
    }
    BrailleFeedback {id:panelFeedback;surface:panelGlow;effect:panelGlow;hover:null}
    Column {
      id:nowPreview
      objectName:"nowActivityPreview"
      anchors.left:parent.left;anchors.right:parent.right
      visible:!!root.previewActivity
      spacing:Design.gap.tight
      readonly property var copy:root.previewActivity ? NowPresentation.describe(root.previewActivity,strings,Commons.I18n.formatNumber) : null
      PlainText {
        width:parent.width
        text:nowPreview.copy ? nowPreview.copy.title : ""
        typeRole:"title";elide:Text.ElideRight
      }
      PlainText {
        width:parent.width
        text:nowPreview.copy ? nowPreview.copy.detail : ""
        typeRole:"body";wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight
      }
      TapHandler {acceptedButtons:Qt.LeftButton;onTapped:root.openNow(root.previewActivity)}
      TapHandler {acceptedButtons:Qt.RightButton;onTapped:root.close(true)}
    }
    PopupPages {
      visible:!root.previewActivity
      id: previewContent
      objectName:"islandPopupPages"
      maximumOverviewHeight:Math.max(1,Math.min(Style.space(640),preview.availableHeight-preview.insetTop-preview.insetBottom))
      keyboardActive:root.pinned && preview.open
      settings: root.settings
      onSettingRequested:(key,value)=>root.updateSetting(key,value)
      externalFeedback: panelFeedback
      selectedPage:root.selectedPage
      compactNotifications: preview.frameSuppressed && !root.pinned && !root.hoverOpen
      radialBraille: root.setting("radialBraille",true)
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      height:Math.min(implicitHeight,parent.height)
      service: root.service; strings: strings; bar: root.bar
      expanded: root.contentExpanded
      focus: root.pinned
      Keys.onEscapePressed: {if(!previewContent.back()) root.close()}
      Keys.onSpacePressed: event => { if (root.selectedPage===1 && root.service) root.service.media("toggle"); else event.accepted = false }

      onExpandRequested: root.openOverview()
      onDismissRequested: root.close()
      onPageRequested:index=>root.openPage(index)
    }
  }
  IslandIpc { enabled: root.ipcEnabled; widget: root }
}
