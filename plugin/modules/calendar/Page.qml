import QtQuick
import "../.." as Island
Island.ModulePage {
  id:root
  available:!!backend && backend.allowed
  implicitHeight:content.implicitHeight
  stableHeight:presentation.selected ? content.implicitHeight : content.monthImplicitHeight
  function enter(){content.showToday()}
  function focusPrimary(){content.focusSelectedDay();return true}
  function handleKey(event){var item=presentation.focusedItem;return !!item && "islandCalendarDay" in item && content.handleKey(event)}
  Island.CalendarView {
    id:content;objectName:"islandCalendar";anchors.fill:parent
    subscriptions:root.backend ? root.backend.calendars : null
    reminders:root.backend ? root.backend.reminders : null
    strings:root.presentation.strings;externalFeedback:root.presentation.feedback
    showBack:false;active:root.presentation.active
    weekStart:String(root.presentation.settings.calendarWeekStart || "")
    radialBraille:root.presentation.radialBraille
    onWeekStartRequested:value=>root.settingRequested("calendarWeekStart",value)
  }
}
