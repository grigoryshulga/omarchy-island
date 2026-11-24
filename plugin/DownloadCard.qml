import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Downloads.js" as Downloads

ContainerSurface {
  id:root
  readonly property bool islandSpotlightSurface: true
  required property var row
  required property var service
  required property var strings
  property bool expanded:false
  property bool active:true
  property alias fileIcon:downloadIcon
  objectName:"download-"+row.key
  color:Design.surface
  border.width: 0
  radius:Design.cardRadius
  implicitHeight:content.implicitHeight+2*Design.cardPadding
  MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.service.openDownload(root.row)}
  ColumnLayout {
    id:content
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Design.cardPadding
    spacing:Design.gap.tight
    RowLayout {
      Layout.fillWidth:true
      spacing:Design.gap.small
      PlainText {id:downloadIcon;text:"󰇚";color:Design.accent;font.pixelSize:Style.font.icon}
      PlainText {
        id:filename
        objectName:"downloadFilename"
        Layout.fillWidth:true;Layout.minimumWidth:0
        text:root.row.filename;typeRole:"title";elide:Text.ElideMiddle;maximumLineCount:1
        readonly property string fileUrl:root.service && ("downloadsDir" in root.service) ? Downloads.fileUrl(root.row,root.service.downloadsDir) : ""
        Accessible.description:fileUrl ? root.strings.t("downloads.dragFile") : ""
        Drag.dragType:Drag.Automatic
        Drag.supportedActions:Qt.CopyAction
        Drag.mimeData:({"text/uri-list":fileUrl+"\r\n"})
        Drag.active:fileDrag.active
        Drag.onDragStarted:if (root.service && "fileDragSource" in root.service) root.service.fileDragSource=filename
        Drag.onDragFinished:finishDrag()
        Component.onDestruction:finishDrag()
        function finishDrag() {
          if (root.service && root.service.fileDragSource===filename) root.service.fileDragSource=null
        }
        HoverHandler {
          enabled:!!filename.fileUrl
          cursorShape:fileDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
        DragHandler {
          id:fileDrag
          target:null
          acceptedButtons:Qt.LeftButton
          enabled:!!filename.fileUrl
        }
      }
      PlainText {text:new Date(root.row.ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm");color:Design.secondaryText;typeRole:"caption"}
    }
    RowLayout {
      Layout.fillWidth:true
      spacing:Design.gap.small
      PlainText {text:root.strings.t(root.row.active ? "downloads.downloading" : "downloads.complete");color:Design.secondaryText;typeRole:"caption"}
      PlainText {objectName:"downloadSize";Layout.fillWidth:true;text:Downloads.sizeText(root.row.downloadedBytes,Commons.I18n.formatNumber);color:Design.accent;typeRole:"caption"}
      ActionButton {objectName:"downloadOpenFolder";iconText:"󰉋";tooltipText:root.strings.t("downloads.openFolder");horizontalPadding:Design.gap.tight;verticalPadding:0;implicitHeight:Design.inlineControlHeight;onClicked:root.service.openDownload(root.row)}
      ActionButton {objectName:"downloadRemove";visible:!root.row.active && root.expanded;iconText:"󰅖";tooltipText:root.strings.t("downloads.removeFromList").arg(root.row.filename);horizontalPadding:Design.gap.tight;verticalPadding:0;implicitHeight:Design.inlineControlHeight;onClicked:root.service.remove(root.row.key)}
    }
    DownloadProgress {objectName:"downloadProgress";Layout.fillWidth:true;visible:root.row.active;active:root.active && root.row.active}
  }
}
