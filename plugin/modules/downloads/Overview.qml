import QtQuick
import qs.Commons
import "../.." as Island
Island.ModuleView {
  id:root
  available:!!backend && backend.allowed && (backend.downloads.length>0 || !!targetKey) && (presentation.expanded || presentation.hovering || (presentation.alertKind==="notification" && presentation.alert && !!presentation.alert.downloadPath))
  readonly property string targetKey:presentation && presentation.detail && presentation.activityTarget ? presentation.activityTarget.downloadKey || "" : ""
  readonly property var detailRow:targetKey && backend ? backend.downloads.find(function(row){return row.key===targetKey}) : null
  implicitHeight:content.implicitHeight
  toastIcon:!presentation.expanded && !presentation.hovering ? downloadList.firstIcon : null
  Column {
    id:content;width:parent.width;objectName:"islandDownloads";spacing:Island.Design.gap.small
    Island.SectionLink {
      objectName:"downloadsOpenDetails";width:parent.width
      visible:(root.presentation.expanded || root.presentation.hovering) && !root.presentation.detail
      title:root.presentation.strings.t("downloads.title");focusable:root.presentation.expanded;feedback:root.presentation.feedback
      onClicked:root.presentation.expanded ? root.detailsRequested() : root.expandRequested()
    }
    Island.PlainText {
      objectName:"downloadEnded"
      visible:!!root.targetKey && !root.detailRow
      width:parent.width;wrapMode:Text.Wrap
      text:visible ? root.presentation.strings.t("downloads.ended").arg(root.presentation.activityTarget.downloadName || "") : ""
    }
    Island.DownloadList {
      id:downloadList
      width:parent.width
      active:root.presentation.active
      rows:root.targetKey ? (root.detailRow ? [root.detailRow] : []) : root.backend ? (root.presentation.expanded || root.presentation.hovering ? root.backend.downloads : root.presentation.alert && root.presentation.alert.downloadPath ? [root.presentation.alert] : []) : []
      service:root.backend;strings:root.presentation.strings;expanded:root.presentation.expanded
    }
  }
}
