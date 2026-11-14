import QtQuick
import qs.Commons
import "../.." as Island

Island.ModuleView {
  id:root
  available:(presentation.expanded || presentation.hovering) && !!backend && backend.allowed && backend.connected
  implicitHeight:body.implicitHeight
  Column {
    id:body
    width:parent.width;spacing:Island.Design.gap.medium
    Island.T3SessionList {
      width:parent.width
      title:"Codex";provider:"codex";titleOpensDetails:true;showAllSummary:true
      bridge:root.backend;strings:root.presentation.strings
      expanded:root.presentation.expanded
      active:root.presentation.active && root.visible && root.available
      feedback:root.presentation.feedback
      summaryMode:!root.presentation.detail;allSessions:root.presentation.detail
      maximumHeight:Math.max(Style.space(96),root.presentation.pageHeight-Style.space(300))
      sessionActions:Component {
        Island.CodexActions {row:parent.row;bridge:parent.bridge;strings:parent.strings;feedback:parent.feedback}
      }
      onDetailsRequested:root.detailsRequested()
      onExpandRequested:root.expandRequested()
    }
    Island.CodexActions {
      objectName:"codexNewSession"
      width:parent.width
      visible:root.presentation.expanded && root.presentation.detail
      bridge:root.backend;strings:root.presentation.strings;feedback:root.presentation.feedback
    }
  }
}
