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
  property var subscriptions:null
  property bool subscriptionsReady:false
  readonly property var eventDays:subscriptions ? subscriptions.daysForYear(viewYear) : []
  readonly property var markedDays:reminderDays.concat(eventDays)
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
  signal settingsRequested()
  readonly property real monthImplicitHeight:body.implicitHeight-(yearMode ? yearGrid.implicitHeight-calendarGrid.implicitHeight : 0)
  implicitHeight: body.implicitHeight
  onActiveChanged: if(active) {refreshToday();activateSubscriptions()}
  onVisibleChanged: activateSubscriptions()

  function cancelReminderClear() {return reminderPanel.cancelClear()}
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
    yearMode=false;viewYear=today.getFullYear(); viewMonth=today.getMonth()
    selectedDay={year:viewYear,month:viewMonth,day:today.getDate(),key:todayKey}
  }
  function refreshToday() {
    var now=new Date()
    if(Calendar.key(now.getFullYear(),now.getMonth(),now.getDate())===todayKey) return
    var follow=selectedDay.key===todayKey && viewYear===today.getFullYear() && viewMonth===today.getMonth()
    today=now
    if(follow && !yearMode) showToday()
  }
  function shiftMonth(delta) {
    if(yearMode) {viewYear=Math.max(1,Math.min(9999,viewYear+delta));return}
    selectDay(Calendar.stepMonth(viewYear,viewMonth,delta,selectedDay.day))
  }
  function closeSubview() {
    if(yearMode) {
      yearMode=false
      viewYear=selectedDay.year; viewMonth=selectedDay.month
      monthButton.forceActiveFocus(Qt.TabFocusReason)
    } else return false
    return true
  }
  function selectDay(day) { selectedDay=day; viewYear=day.year; viewMonth=day.month }
  function focusSelectedDay() {
    if(yearMode) {yearGrid.focusMonth();return}
    for(var i=0;i<dayCells.count;i++) {
      var item=dayCells.itemAt(i)
      if(item && item.modelData.key===selectedDay.key) {item.forceActiveFocus(Qt.TabFocusReason);return}
    }
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
    focusSelectedDay()
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
      NavigationBackButton {
        id:backButton;objectName:"calendarBack"
        anchors.left:parent.left;anchors.verticalCenter:currentDate.verticalCenter
        strings:root.strings;visible:root.showBack
        onClicked:{root.pulseFrom(backButton);if(!root.closeSubview()) root.backRequested()}
      }
      FeedbackButton {
        id: currentDate
        objectName: "calendarCurrentDate"
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth,parent.width-2*(settingsButton.width+Style.space(8)))
        text: root.today.toLocaleDateString(root.locale,root.strings.t("calendar.currentDateFormat"))
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
        onClicked: {root.pulseFrom(settingsButton);root.settingsRequested()}
      }
    }
    GridLayout {
      id:calendarGrid
      visible:!root.yearMode
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
          Accessible.name: Calendar.localDate(modelData.year,modelData.month,modelData.day).toLocaleDateString(root.locale,Locale.LongFormat)
          Accessible.selectable:true
          Accessible.selected:active
          Accessible.description:[
            modelData.today ? root.strings.t("calendar.today") : "",
            root.reminderDays.indexOf(modelData.key)>=0 ? root.strings.t("reminders.title") : "",
            root.eventDays.indexOf(modelData.key)>=0 ? root.strings.t("ics.events") : ""
          ].filter(Boolean).join(" · ")
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
      id:yearGrid;Layout.fillWidth:true;visible:root.yearMode
      year:root.viewYear;month:root.viewMonth;firstDay:root.firstDay;todayKey:root.todayKey;reminderDays:root.markedDays
      onYearShift:delta=>root.shiftMonth(delta)
      onTodayRequested:{root.showToday();Qt.callLater(root.focusSelectedDay)}
      onMonthChosen:month=>{root.viewMonth=month;root.yearMode=false;root.selectedDay=Calendar.parts(Calendar.civilDate(root.viewYear,month,1));Qt.callLater(root.focusSelectedDay)}
    }
    RowLayout {
      Layout.fillWidth: true
      spacing:Design.gap.small
      FeedbackButton { id: previousButton; objectName: "calendarPrevious"; iconText: Commons.I18n.rightToLeft ? "󰅂" : "󰅁"; tooltipText: root.strings.t("calendar.previous"); radius: Design.controlRadius; horizontalPadding:Design.gap.small; focusable: true; onClicked: { root.pulseFrom(previousButton); root.shiftMonth(-1) } }
      FeedbackButton {
        id:monthButton
        objectName: "calendarMonth"
        Layout.fillWidth: true
        text: root.yearMode ? Commons.I18n.formatNumber(root.viewYear) : root.monthTitle
        fontSize:Design.type.label;focusable:true
        tooltipText:root.strings.t(root.yearMode ? "calendar.showMonth" : "calendar.showYear")
        onClicked:{if(root.yearMode) root.closeSubview();else {root.yearMode=true;yearGrid.focusMonth()}}
      }
      FeedbackButton { id: nextButton; objectName: "calendarNext"; iconText: Commons.I18n.rightToLeft ? "󰅁" : "󰅂"; tooltipText: root.strings.t("calendar.next"); radius: Design.controlRadius; horizontalPadding:Design.gap.small; focusable: true; onClicked: { root.pulseFrom(nextButton); root.shiftMonth(1) } }
    }
    CalendarAgenda {
      Layout.fillWidth:true
      visible:!root.yearMode && root.selectedDay.year===root.viewYear && root.selectedDay.month===root.viewMonth && !!root.subscriptions && root.subscriptions.hasEnabled
      strings:root.strings;subscriptions:root.subscriptions;year:root.viewYear;selectedKey:root.selectedDay.key
    }
    ReminderPanel {
      id:reminderPanel
      active:root.active
      Layout.fillWidth:true
      visible:!!root.reminders
      strings:root.strings;reminders:root.reminders;selectedKey:root.selectedDay.key
    }
  }
  }
}
