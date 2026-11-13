import QtQuick
import "../.." as Island

Island.ModuleView {
  id:root
  available:(presentation.expanded || presentation.hovering) && !!backend && backend.allowed
  implicitHeight:overview.implicitHeight
  Island.AgentLimitsOverview {
    id:overview
    width:parent.width
    backend:root.backend
    strings:root.presentation ? root.presentation.strings : null
    expanded:!!root.presentation && root.presentation.expanded
    showHeader:!centerOpen
    centerOpen:!!root.presentation && root.presentation.detail
    feedback:root.presentation ? root.presentation.feedback : null
    onDetailsRequested:root.detailsRequested()
    onExpandRequested:root.expandRequested()
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
  }
}
