import QtQuick
import "../.." as Island

Island.ModuleView {
  id:root
  available:(presentation.expanded || presentation.hovering) && !!backend && backend.allowed
  implicitHeight:overview.implicitHeight
  readonly property bool editing: overview.center.editing
  readonly property bool adding: overview.center.adding
  function configure() { overview.center.configure() }
  function showAdd() { overview.center.showAdd() }
  function back() { return overview.center.back() }
  Island.AgentLimitsOverview {
    id:overview
    availableHeight: root.presentation ? root.presentation.pageHeight : 500
    width:parent.width
    backend:root.backend
    strings:root.presentation ? root.presentation.strings : null
    expanded:!!root.presentation && root.presentation.expanded
    compact:!!root.presentation && root.presentation.size==="compact"
    showHeader:!centerOpen && !compact
    centerOpen:!!root.presentation && root.presentation.detail
    feedback:root.presentation ? root.presentation.feedback : null
    onDetailsRequested:root.detailsRequested()
    onExpandRequested:root.expandRequested()
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
  }
}
