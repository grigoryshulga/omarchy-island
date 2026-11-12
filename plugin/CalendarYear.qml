import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "CalendarModel.js" as Calendar

Item {
  id:root
  property int year:2026
  property int month:0
  property int firstDay:1
  property string todayKey:""
  property var reminderDays:[]
  readonly property var formatLocale:Qt.locale(Commons.I18n.formatLocale)
  readonly property var weekdays:Calendar.weekdays(firstDay)
  signal monthChosen(int month)
  signal yearShift(int delta)
  signal todayRequested()
  implicitHeight:grid.implicitHeight
  function focusMonth() {var item=months.itemAt(month);if(item) item.forceActiveFocus()}
  GridLayout {
    id:grid;width:root.width;columns:3;columnSpacing:Design.gap.small;rowSpacing:Design.gap.small
    Repeater {
      id:months;model:12
      FeedbackButton {
        id:tile
        required property int index
        readonly property var cells:Calendar.monthCells(root.year,index,root.firstDay,root.todayKey)
        objectName:"calendarYearMonth-"+index
        Layout.fillWidth:true;Layout.minimumWidth:0;Layout.preferredWidth:1
        implicitHeight:mini.implicitHeight+Design.gap.small*2
        variant:"soft";selected:root.month===index;focusable:true
        Accessible.name:root.formatLocale.standaloneMonthName(index,Locale.LongFormat)+" "+Commons.I18n.formatNumber(root.year)
        onClicked:root.monthChosen(index)
        Keys.onPressed:event=>{
          if(event.key===Qt.Key_PageUp) {root.yearShift(-1);event.accepted=true}
          else if(event.key===Qt.Key_PageDown) {root.yearShift(1);event.accepted=true}
          else if(event.key===Qt.Key_Home) {root.todayRequested();event.accepted=true}
        }
        ColumnLayout {
          id:mini;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:Design.gap.small;spacing:Design.gap.tight
          PlainText {Layout.fillWidth:true;text:root.formatLocale.standaloneMonthName(tile.index,Locale.ShortFormat);typeRole:"title";color:tile.selected ? Design.selectedText : Design.text}
          GridLayout {
            Layout.fillWidth:true;columns:7;columnSpacing:0;rowSpacing:0
            Repeater {
              model:7
              PlainText {required property int index;readonly property int modelData:root.weekdays[index];Layout.fillWidth:true;Layout.preferredWidth:1;text:root.formatLocale.dayName(modelData,Locale.NarrowFormat);typeRole:"caption";horizontalAlignment:Text.AlignHCenter;color:tile.selected ? Design.selectedSecondaryText : Design.secondaryText}
            }
            Repeater {
              model:42
              PlainText {
                required property int index
                readonly property var modelData:tile.cells[index]
                Layout.fillWidth:true;Layout.preferredWidth:1
                text:modelData.inMonth ? Commons.I18n.formatNumber(modelData.day) : ""
                typeRole:"caption";horizontalAlignment:Text.AlignHCenter
                font.bold:modelData.today || root.reminderDays.indexOf(modelData.key)>=0
                color:modelData.today ? Design.accent : tile.selected ? Design.selectedText : Design.text
              }
            }
          }
        }
      }
    }
  }
}
