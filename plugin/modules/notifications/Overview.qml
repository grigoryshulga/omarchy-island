import QtQuick
import "../.." as Island
Island.ModuleView {
  id:root
  available:!!backend && (presentation.expanded || (presentation.hovering && backend.activeEntries.length>0) || (presentation.alertKind==="notification" && !!presentation.alert && !presentation.alert.downloadPath))
  implicitHeight:content.implicitHeight
  toastIcon:content.notificationIcon
  Island.NotificationContent {
    id:content;width:parent.width
    service:root.backend;strings:root.presentation.strings
    expanded:root.presentation.expanded;hovering:root.presentation.hovering
    overviewSize:root.presentation.size || "standard"
    detailOpen:root.presentation.detail;alertKind:root.presentation.alertKind
    radialBraille:root.presentation.radialBraille;externalFeedback:root.presentation.feedback
    pageHeight:root.presentation.pageHeight
    onExpandRequested:root.expandRequested()
    onDetailsRequested:root.detailsRequested()
  }
}
