import QtQuick
import "../.." as Island
Item {
  id:root
  property bool allowed:Island.Preferences.get("calendarEnabled")
  property alias helperCommand:calendars.helperCommand
  property alias reminderCommand:reminders.command
  property alias clock:reminders.clock
  property alias calendars:calendars
  property alias reminders:reminders
  Island.CalendarState {id:calendars;allowed:root.allowed}
  Island.ReminderState {id:reminders;allowed:root.allowed}
}
