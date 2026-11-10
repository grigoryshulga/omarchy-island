import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "CalendarModel.js" as Calendar

Item {
  id: root
  required property var strings
  property bool radialBraille: true
  property date today: new Date()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  property var selectedDay: ({year:today.getFullYear(),month:today.getMonth(),day:today.getDate(),key:todayKey})
  readonly property string todayKey: Calendar.key(today.getFullYear(),today.getMonth(),today.getDate())
  readonly property var locale: Qt.locale(Commons.I18n.formatLocale)
  readonly property var weekdays: Calendar.weekdays(locale.firstDayOfWeek)
  readonly property var cells: Calendar.monthCells(viewYear,viewMonth,locale.firstDayOfWeek,todayKey)
  readonly property string monthTitle: strings.t("calendar.monthYear").arg(locale.standaloneMonthName(viewMonth,Locale.LongFormat)).arg(Calendar.localDate(viewYear,viewMonth,1).toLocaleDateString(locale,"yyyy"))
  signal backRequested()
  implicitHeight: body.implicitHeight

  function pulseFrom(item) {
    var at=item.mapToItem(root,item.width/2,item.height/2)
    if(hover.hovered) {
      var p=hover.point.position, local=item.mapFromItem(root,p.x,p.y)
      if(local.x>=0 && local.y>=0 && local.x<=item.width && local.y<=item.height) at=p
    }
    glow.pulse(at)
  }
  function showToday() {
    viewYear=today.getFullYear(); viewMonth=today.getMonth()
    selectedDay={year:viewYear,month:viewMonth,day:today.getDate(),key:todayKey}
  }
  function shiftMonth(delta) {
    var next=Calendar.stepMonth(viewYear,viewMonth,delta)
    viewYear=next.year; viewMonth=next.month
  }
  function selectDay(day) { selectedDay=day; viewYear=day.year; viewMonth=day.month }
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
    objectName: "calendarSpotlight"
    anchors.fill: parent
    active: hover.hovered
    pointer: hover.point.position
    adaptive: root.radialBraille
  }
  MouseArea { anchors.fill: parent; onClicked: mouse => glow.pulse(Qt.point(mouse.x,mouse.y)) }
  Timer {
    interval: 60000; repeat: true; running: root.visible
    onTriggered: {
      var follow=root.selectedDay.key===root.todayKey && root.viewYear===root.today.getFullYear() && root.viewMonth===root.today.getMonth()
      root.today=new Date()
      if(follow) root.showToday()
    }
  }
  ColumnLayout {
    id: body
    width: parent.width
    spacing: Style.space(12)
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)
      Button { id: backButton; objectName: "calendarBack"; iconText: Commons.I18n.rightToLeft ? "󰁔" : "󰁍"; tooltipText: root.strings.t("calendar.back"); radius: Math.min(Style.cornerRadius,Style.space(6)); horizontalPadding: Style.space(5); focusable: true; onClicked: { root.pulseFrom(backButton); root.backRequested() } }
      PlainText { objectName: "calendarMonth"; Layout.fillWidth: true; text: root.monthTitle; font.pixelSize: Style.font.title; font.bold: true }
      Button { id: previousButton; objectName: "calendarPrevious"; iconText: Commons.I18n.rightToLeft ? "󰅂" : "󰅁"; tooltipText: root.strings.t("calendar.previous"); radius: Math.min(Style.cornerRadius,Style.space(6)); horizontalPadding: Style.space(5); focusable: true; onClicked: { root.pulseFrom(previousButton); root.shiftMonth(-1) } }
      Button { id: nextButton; objectName: "calendarNext"; iconText: Commons.I18n.rightToLeft ? "󰅁" : "󰅂"; tooltipText: root.strings.t("calendar.next"); radius: Math.min(Style.cornerRadius,Style.space(6)); horizontalPadding: Style.space(5); focusable: true; onClicked: { root.pulseFrom(nextButton); root.shiftMonth(1) } }
    }
    GridLayout {
      Layout.fillWidth: true
      columns: 7
      columnSpacing: Style.space(3)
      rowSpacing: Style.space(3)
      Repeater {
        model: root.weekdays
        PlainText {
          required property int modelData
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(24)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: root.locale.dayName(modelData,Locale.ShortFormat)
          font.pixelSize: Style.font.caption
          color: Commons.Color.muted
        }
      }
      Repeater {
        model: root.cells
        Button {
          id: dayButton
          required property var modelData
          objectName: "calendar-day-"+modelData.key
          Layout.fillWidth: true
          Layout.preferredWidth: Style.space(38)
          Layout.preferredHeight: Style.space(34)
          horizontalPadding: 0; verticalPadding: 0
          radius: Math.min(Style.cornerRadius,Style.space(6))
          text: Commons.I18n.formatNumber(modelData.day)
          foreground: modelData.today ? Commons.Color.accent : modelData.inMonth ? Commons.Color.foreground : Commons.Color.muted
          background: modelData.today ? Util.alpha(Commons.Color.accent,0.15) : "transparent"
          bordered: modelData.today
          active: root.selectedDay.key===modelData.key
          Rectangle {
            anchors.fill: parent
            visible: modelData.today
            radius: parent.radius
            color: "transparent"
            border.width: Math.max(1,Style.space(1))
            border.color: Commons.Color.accent
          }
          focusable: true
          onClicked: { root.pulseFrom(dayButton); root.selectDay(modelData) }
        }
      }
    }
    PanelSeparator { Layout.fillWidth: true }
    RowLayout {
      Layout.fillWidth: true
      PlainText {
        Layout.fillWidth: true
        text: Calendar.localDate(root.selectedDay.year,root.selectedDay.month,root.selectedDay.day).toLocaleDateString(root.locale,root.strings.t("calendar.dateFormat"))
        font.pixelSize: Style.font.bodySmall
        color: Commons.Color.muted
      }
      ActionButton { id: todayButton; objectName: "calendarToday"; text: root.strings.t("calendar.today"); onClicked: { root.pulseFrom(todayButton); root.showToday() } }
    }
  }
}
