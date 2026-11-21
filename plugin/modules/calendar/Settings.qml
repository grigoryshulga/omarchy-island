import QtQuick
import qs.Commons as Commons
import "../.." as Island

Island.ModuleView {
  id:root
  available:!!backend && backend.allowed && !!backend.calendars
  implicitHeight:content.implicitHeight
  property bool expanded:false
  onAvailableChanged:if(!available) expanded=false
  Column {
    id:content
    width:parent.width
    spacing:Island.Design.gap.small
    Island.ActionButton {
      id:disclosure
      objectName:"calendarSubscriptions"
      width:Math.min(parent.width,implicitWidth)
      x:Commons.I18n.rightToLeft ? parent.width-width : 0
      text:root.presentation.strings.t("ics.sources")
      iconText:Commons.I18n.rightToLeft ? "󰅁" : "󰅂"
      iconRotation:root.expanded ? (Commons.I18n.rightToLeft ? -90 : 90) : 0
      Accessible.expandable:true;Accessible.expanded:root.expanded
      onClicked:{
        root.expanded=!root.expanded
        if(root.expanded) root.backend.calendars.activate(root.backend.calendars.year)
      }
    }
    Island.CalendarSources {
      width:parent.width
      visible:root.expanded
      strings:root.presentation.strings
      subscriptions:root.available ? root.backend.calendars : null
    }
  }
}
