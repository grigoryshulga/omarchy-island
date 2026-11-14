import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "CalendarModel.js" as Calendar
import "ReminderModel.js" as Reminders

Item {
  id: root
  required property var strings
  property var reminders:null
  property bool yearMode:false
  property bool sourcesMode:false
  property var subscriptions:null
  property bool subscriptionsReady:false
  readonly property var markedDays:reminderDays.concat(subscriptions ? subscriptions.daysForYear(viewYear) : [])
  function activateSubscriptions() {if(subscriptionsReady && active && visible && subscriptions) subscriptions.activate(viewYear)}
  onSubscriptionsChanged:activateSubscriptions()
  onViewYearChanged:activateSubscriptions()
  Component.onCompleted:{subscriptionsReady=true;activateSubscriptions()}
  readonly property var reminderDays:reminders ? reminders.rows.map(function(row){return Reminders.dayKey(row.at)}) : []
  property bool radialBraille: true
  property var externalFeedback: null
  property bool showBack: true
  property bool active: true
  property string weekStart: ""
  property date today: new Date()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  property var selectedDay: ({year:today.getFullYear(),month:today.getMonth(),day:today.getDate(),key:todayKey})
  readonly property string todayKey: Calendar.key(today.getFullYear(),today.getMonth(),today.getDate())
  readonly property var locale: Qt.locale(Commons.I18n.formatLocale)
  readonly property int firstDay: Calendar.weekStart(weekStart,locale.firstDayOfWeek)
  readonly property var weekdays: Calendar.weekdays(firstDay)
  readonly property var cells: Calendar.monthCells(viewYear,viewMonth,firstDay,todayKey)
  readonly property var weekNumbers: Calendar.weekNumbers(cells,firstDay)
  readonly property string monthTitle: strings.t("calendar.monthYear").arg(locale.standaloneMonthName(viewMonth,Locale.LongFormat)).arg(Calendar.localDate(viewYear,viewMonth,1).toLocaleDateString(locale,"yyyy"))
  signal backRequested()
  signal weekStartRequested(string value)
  readonly property real monthImplicitHeight:body.implicitHeight-(yearMode && !sourcesMode ? yearGrid.implicitHeight-calendarGrid.implicitHeight : 0)
  implicitHeight: body.implicitHeight
  onActiveChanged: {if(!active) settingsMenu.close();else {refreshToday();activateSubscriptions()}}
  onVisibleChanged: {if(!visible) settingsMenu.close();else activateSubscriptions()}

  function pulseFrom(item) {
    if(externalFeedback) {externalFeedback.pulseFrom(item);return}
    var at=item.mapToItem(root,item.width/2,item.height/2)
    if(hover.hovered) {
      var p=hover.point.position, local=item.mapFromItem(root,p.x,p.y)
      if(local.x>=0 && local.y>=0 && local.x<=item.width && local.y<=item.height) at=p
    }
    glow.pulse(at)
  }
  function showToday() {
    sourcesMode=false
    yearMode=false;viewYear=today.getFullYear(); viewMonth=today.getMonth()
    selectedDay={year:viewYear,month:viewMonth,day:today.getDate(),key:todayKey}
  }
  function refreshToday() {
    var now=new Date()
    if(Calendar.key(now.getFullYear(),now.getMonth(),now.getDate())===todayKey) return
    var follow=selectedDay.key===todayKey && viewYear===today.getFullYear() && viewMonth===today.getMonth()
    today=now
    if(follow && !yearMode && !sourcesMode) showToday()
  }
  function shiftMonth(delta) {
    if(yearMode) {viewYear=Math.max(1,Math.min(9999,viewYear+delta));return}
    var next=Calendar.stepMonth(viewYear,viewMonth,delta)
    viewYear=next.year; viewMonth=next.month
  }
  function selectDay(day) { selectedDay=day; viewYear=day.year; viewMonth=day.month }
  function focusSelectedDay() {
    if(sourcesMode) {sourcesPanel.focusEditor();return}
    if(yearMode) {yearGrid.focusMonth();return}
    for(var i=0;i<dayCells.count;i++) {
      var item=dayCells.itemAt(i)
      if(item && item.modelData.key===selectedDay.key) {item.forceActiveFocus(Qt.TabFocusReason);return}
    }
  }
  function chooseWeekStart(value) {
    weekStartRequested(value)
    settingsMenu.close()
  }
  function stepSetting(index,delta) {
    var count=subscriptions ? 3 : 2,next=(index+delta+count)%count
    if(next===2) subscriptionsButton.forceActiveFocus()
    else weekChoices.itemAt(next).forceActiveFocus()
  }
  function focusWeekStart() {
    if(settingsMenu.opened) weekChoices.itemAt(firstDay===0 ? 0 : 1).forceActiveFocus()
  }
  function handleKey(event) {
    if(event.key===Qt.Key_PageUp) shiftMonth(-1)
    else if(event.key===Qt.Key_PageDown) shiftMonth(1)
    else if(event.key===Qt.Key_Home) showToday()
    else if(event.key===Qt.Key_Left) selectDay(Calendar.stepDay(selectedDay,Commons.I18n.rightToLeft ? 1 : -1))
    else if(event.key===Qt.Key_Right) selectDay(Calendar.stepDay(selectedDay,Commons.I18n.rightToLeft ? -1 : 1))
    else if(event.key===Qt.Key_Up) selectDay(Calendar.stepDay(selectedDay,-7))
    else if(event.key===Qt.Key_Down) selectDay(Calendar.stepDay(selectedDay,7))
    else return false
    return true
  }
  HoverHandler { id: hover }
  BrailleSpotlight {
    id: glow
    surfaceRoot: root
    objectName: "calendarSpotlight"
    anchors.fill: parent
    active: !root.externalFeedback && hover.hovered
    pointer: hover.point.position
    adaptive: root.radialBraille
  }
  MouseArea { anchors.fill: parent; onClicked: mouse => {if(root.externalFeedback) root.externalFeedback.pulseFrom(root,Qt.point(mouse.x,mouse.y));else glow.pulse(Qt.point(mouse.x,mouse.y))} }
  Timer {
    objectName:"calendarDateRefresh"
    interval: 60000; repeat: true; running: root.active && root.visible
    onTriggered: root.refreshToday()
  }
  Controls.ScrollView {
    id:calendarScroll
    objectName:"calendarScroll"
    anchors.fill:parent;clip:true;contentWidth:availableWidth
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Controls.ScrollBar.vertical.policy:Controls.ScrollBar.AlwaysOff
  ColumnLayout {
    id: body
    width: calendarScroll.availableWidth
    spacing:Design.gap.medium
    Item {
      Layout.fillWidth: true
      implicitHeight: currentDate.implicitHeight+Style.space(8)
      FeedbackButton { id: backButton; anchors.left: parent.left; anchors.verticalCenter: currentDate.verticalCenter; visible: root.showBack || root.sourcesMode; objectName: "calendarBack"; iconText: Commons.I18n.rightToLeft ? "󰁔" : "󰁍"; tooltipText: root.strings.t("calendar.back"); radius: Design.controlRadius; horizontalPadding:Design.gap.small; focusable: true; onClicked: { root.pulseFrom(backButton); if(root.sourcesMode) root.sourcesMode=false;else root.backRequested() } }
      FeedbackButton {
        id: currentDate
        objectName: "calendarCurrentDate"
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth,parent.width-2*(settingsButton.width+Style.space(8)))
        text: root.sourcesMode ? root.strings.t("ics.sources") : root.today.toLocaleDateString(root.locale,root.strings.t("calendar.currentDateFormat"))
        fontSize: Design.type.page
        fontWeight: Design.weight("page")
        color: "transparent"
        foreground: hot || activeFocus ? Design.accent : Design.text
        tooltipText: root.strings.t("calendar.goToToday")
        focusable: true
        onClicked: {root.pulseFrom(currentDate);root.showToday()}
      }
      FeedbackButton {
        id: settingsButton
        objectName: "calendarSettings"
        anchors.right: parent.right
        anchors.verticalCenter: currentDate.verticalCenter
        iconText: "󰒓"
        tooltipText: root.strings.t("calendar.settings")
        horizontalPadding:Design.gap.small
        radius: Design.controlRadius
        focusable: true
        onClicked: {root.pulseFrom(settingsButton);settingsMenu.opened ? settingsMenu.close() : settingsMenu.open()}
      }
    }
    GridLayout {
      id:calendarGrid
      visible:!root.yearMode && !root.sourcesMode
      Layout.fillWidth: true
      columns: 8
      columnSpacing:Design.gap.tight
      rowSpacing:Design.gap.tight
      PlainText {
        id:weekHeading
        objectName: "calendarWeekHeading"
        Layout.row: 0; Layout.column: 0
        Layout.preferredWidth: Style.space(28)
        horizontalAlignment: Text.AlignHCenter
        text: root.strings.t("calendar.weekNumber")
        typeRole:"caption"
        color: Design.secondaryText
      }
      Repeater {
        model: 7
        PlainText {
          required property int index
          readonly property int modelData: root.weekdays[index]
          Layout.row: 0; Layout.column: index+1
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(24)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: root.locale.dayName(modelData,Locale.ShortFormat)
          typeRole:"caption"
          color: Design.secondaryText
        }
      }
      Repeater {
        model: 6
        PlainText {
          required property int index
          readonly property int modelData: root.weekNumbers[index]
          objectName: "calendarWeek-"+index
          Layout.row: index+1; Layout.column: 0
          Layout.preferredWidth: Style.space(28)
          Layout.fillHeight: true
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: Commons.I18n.formatNumber(modelData)
          typeRole:"caption"
          color: Design.secondaryText
        }
      }
      Repeater {
        id:dayCells
        // A JS array model resets the Repeater on every month/year change.
        // Keep the controls (and keyboard focus); only their dates change.
        model: 42
        FeedbackButton {
          id: dayButton
          required property int index
          readonly property var modelData: root.cells[index]
          readonly property bool islandCalendarDay: true
          objectName: "calendar-day-"+modelData.key
          Layout.row: Math.floor(index/7)+1; Layout.column: index%7+1
          Layout.fillWidth: true
          Layout.preferredWidth: Style.space(38)
          Layout.preferredHeight: Style.space(34)
          horizontalPadding: 0; verticalPadding: 0
          radius: Design.controlRadius
          text: Commons.I18n.formatNumber(modelData.day)
          foreground: modelData.today ? Design.onAccent : modelData.inMonth ? Design.text : Design.secondaryText
          color: modelData.today ? Design.accent : activeFocus ? Style.focusFillFor(foreground,accent) : hot ? Style.hoverFillFor(foreground,accent) : active ? Style.selectedFillFor(foreground,accent) : "transparent"
          active: root.selectedDay.key===modelData.key
          Loader {
            anchors.centerIn: parent
            width: Math.max(dayButton.width,dayButton.height)+Style.space(40)
            height: width
            z: -1
            active: dayButton.modelData.today
            sourceComponent: IndicatorGlow {
              objectName: "calendarTodayGlow"
              width: parent.width; height: parent.height
              active: root.active && root.visible
              intensity: 3.8
            }
          }
          Rectangle {anchors.bottom:parent.bottom;anchors.bottomMargin:2;anchors.horizontalCenter:parent.horizontalCenter;width:4;height:4;radius:2;visible:root.markedDays.indexOf(dayButton.modelData.key)>=0;color:dayButton.modelData.today ? Design.onAccent : Design.accent}
          focusable: true
          onClicked: { root.pulseFrom(dayButton); root.selectDay(modelData) }
        }
      }
    }

    CalendarYear {
      id:yearGrid;Layout.fillWidth:true;visible:root.yearMode && !root.sourcesMode
      year:root.viewYear;month:root.viewMonth;firstDay:root.firstDay;todayKey:root.todayKey;reminderDays:root.markedDays
      onYearShift:delta=>root.shiftMonth(delta)
      onTodayRequested:{root.showToday();Qt.callLater(root.focusSelectedDay)}
      onMonthChosen:month=>{root.viewMonth=month;root.yearMode=false;root.selectedDay=Calendar.parts(Calendar.civilDate(root.viewYear,month,1));Qt.callLater(root.focusSelectedDay)}
    }
    RowLayout {
      visible:!root.sourcesMode
      Layout.fillWidth: true
      spacing:Design.gap.small
      FeedbackButton { id: previousButton; objectName: "calendarPrevious"; iconText: Commons.I18n.rightToLeft ? "󰅂" : "󰅁"; tooltipText: root.strings.t("calendar.previous"); radius: Design.controlRadius; horizontalPadding:Design.gap.small; focusable: true; onClicked: { root.pulseFrom(previousButton); root.shiftMonth(-1) } }
      FeedbackButton {
        objectName: "calendarMonth"
        Layout.fillWidth: true
        text: root.yearMode ? Commons.I18n.formatNumber(root.viewYear) : root.monthTitle
        fontSize:Design.type.label;focusable:true
        tooltipText:root.strings.t(root.yearMode ? "calendar.showMonth" : "calendar.showYear")
        onClicked:root.yearMode=!root.yearMode
      }
      FeedbackButton { id: nextButton; objectName: "calendarNext"; iconText: Commons.I18n.rightToLeft ? "󰅁" : "󰅂"; tooltipText: root.strings.t("calendar.next"); radius: Design.controlRadius; horizontalPadding:Design.gap.small; focusable: true; onClicked: { root.pulseFrom(nextButton); root.shiftMonth(1) } }
    }
    CalendarAgenda {
      Layout.fillWidth:true
      visible:!root.sourcesMode && !root.yearMode && root.selectedDay.year===root.viewYear && root.selectedDay.month===root.viewMonth && !!root.subscriptions && root.subscriptions.hasEnabled
      strings:root.strings;subscriptions:root.subscriptions;year:root.viewYear;selectedKey:root.selectedDay.key
    }
    CalendarSources {
      id:sourcesPanel
      Layout.fillWidth:true
      visible:root.sourcesMode && !!root.subscriptions
      strings:root.strings;subscriptions:root.subscriptions
    }
    ReminderPanel {
      id:reminderPanel
      Layout.fillWidth:true
      visible:!!root.reminders && !root.sourcesMode
      strings:root.strings;reminders:root.reminders;selectedKey:root.selectedDay.key
    }
  }
  }
  Controls.Popup {
    id: settingsMenu
    objectName: "calendarSettingsMenu"
    parent: settingsButton
    x: Commons.I18n.rightToLeft ? 0 : settingsButton.width-width
    y: settingsButton.height+Style.space(5)
    width: Math.min(root.width,Style.space(230))
    padding:Design.gap.medium
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    enter: Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:Preferences.duration(160);easing.type:Easing.OutCubic}}
    exit: Transition {NumberAnimation {property:"opacity";to:0;duration:Preferences.duration(100);easing.type:Easing.OutCubic}}
    background: BorderSurface {color:Design.canvas;borderSpec:Design.popupBorder;radius:Design.cardRadius}
    onOpened: Qt.callLater(root.focusWeekStart)
    onClosed: if(root.active && root.visible) {if(root.sourcesMode) sourcesPanel.focusEditor();else settingsButton.forceActiveFocus()}
    contentItem: Column {
      spacing:Design.gap.small
      PlainText {width:parent.width;text:root.strings.t("calendar.weekStartsOn");color:Design.secondaryText;typeRole:"caption";wrapMode:Text.Wrap}
      Repeater {
        id: weekChoices
        model: ["sunday","monday"]
        ActionButton {
          required property string modelData
          required property int index
          objectName: "calendarWeekStart-"+modelData
          width: parent.width
          text: root.locale.dayName(index===0 ? 0 : 1,Locale.LongFormat)
          selected: root.firstDay===(index===0 ? 0 : 1)
          foreground: selected ? Design.accent : Design.text
          leftAlign: true
          background: "transparent"
          onClicked: {root.pulseFrom(settingsButton);root.chooseWeekStart(modelData)}
          Keys.onDownPressed: root.stepSetting(index,1)
          Keys.onUpPressed: root.stepSetting(index,-1)
          Keys.onTabPressed: root.stepSetting(index,1)
          Keys.onBacktabPressed: root.stepSetting(index,-1)
        }
      }
      ActionButton {
        id:subscriptionsButton;objectName:"calendarSubscriptions"
        visible:!!root.subscriptions;width:parent.width
        text:root.strings.t("ics.sources");leftAlign:true;background:"transparent"
        onClicked:{root.sourcesMode=true;settingsMenu.close()}
        Keys.onDownPressed:root.stepSetting(2,1)
        Keys.onUpPressed:root.stepSetting(2,-1)
        Keys.onTabPressed:root.stepSetting(2,1)
        Keys.onBacktabPressed:root.stepSetting(2,-1)
      }
    }
  }
}
