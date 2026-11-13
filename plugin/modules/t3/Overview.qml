import QtQuick
import qs.Commons
import "../.." as Island

Island.ModuleView {
  id:root
  available:(presentation.expanded || presentation.hovering) && !!backend && backend.allowed && backend.connected && backend.rows.length>0
  implicitHeight:list.implicitHeight
  Island.T3SessionList {
    id:list
    width:parent.width
    bridge:root.backend
    strings:root.presentation ? root.presentation.strings : null
    expanded:!!root.presentation && root.presentation.expanded
    active:!!root.presentation && root.presentation.active && root.visible && root.available
    feedback:root.presentation ? root.presentation.feedback : null
    summaryMode:!root.presentation || !root.presentation.detail
    allSessions:!!root.presentation && root.presentation.detail
    maximumHeight:root.presentation ? Math.max(Style.space(96),root.presentation.pageHeight-Style.space(128)) : Style.space(96)
    onDetailsRequested:root.detailsRequested()
    onExpandRequested:root.expandRequested()
  }
}
