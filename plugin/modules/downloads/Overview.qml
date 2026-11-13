import QtQuick
import qs.Commons
import "../.." as Island
Island.ModuleView {
  id:root
  available:!!backend && backend.allowed && backend.downloads.length>0 && (presentation.expanded || presentation.hovering || (presentation.alertKind==="notification" && presentation.alert && !!presentation.alert.downloadPath))
  implicitHeight:content.implicitHeight
  Column {
    id:content;width:parent.width;objectName:"islandDownloads";spacing:Island.Design.gap.small
    Island.SectionHeading {width:parent.width;visible:root.presentation.expanded || root.presentation.hovering;title:root.presentation.strings.t("downloads.title")}
    Island.DownloadList {
      width:parent.width
      active:root.presentation.active
      rows:root.backend ? (root.presentation.expanded || root.presentation.hovering ? root.backend.downloads : root.presentation.alert && root.presentation.alert.downloadPath ? [root.presentation.alert] : []) : []
      service:root.backend;strings:root.presentation.strings;expanded:root.presentation.expanded
    }
  }
}
