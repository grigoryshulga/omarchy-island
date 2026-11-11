import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Downloads.js" as Downloads

Rectangle {
  id:root
  readonly property bool islandSpotlightSurface: true
  required property var row
  required property var service
  required property var strings
  property bool expanded:false
  activeFocusOnTab:expanded
  objectName:"download-"+row.key
  color:Design.surface
  border.width: 0
  radius:Design.cardRadius
  implicitHeight:content.implicitHeight+2*Design.cardPadding
  Keys.onReturnPressed:service.openDownload(row)
  Keys.onEnterPressed:service.openDownload(row)
  Keys.onSpacePressed:service.openDownload(row)
  MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.service.openDownload(root.row)}
  ColumnLayout {
    id:content
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Design.cardPadding
    spacing:Design.gap.tight
    RowLayout {
      Layout.fillWidth:true
      spacing:Design.gap.small
      PlainText {text:"󰇚";color:Design.accent;font.pixelSize:Style.font.icon}
      PlainText {objectName:"downloadFilename";Layout.fillWidth:true;Layout.minimumWidth:0;text:root.row.filename;typeRole:"title";elide:Text.ElideMiddle;maximumLineCount:1}
      PlainText {text:new Date(root.row.ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm");color:Design.secondaryText;typeRole:"caption"}
    }
    RowLayout {
      Layout.fillWidth:true
      spacing:Design.gap.small
      PlainText {text:root.strings.t(root.row.active ? "downloads.downloading" : "downloads.complete");color:Design.secondaryText;typeRole:"caption"}
      PlainText {objectName:"downloadSize";Layout.fillWidth:true;text:Downloads.sizeText(root.row.downloadedBytes,Commons.I18n.formatNumber);color:Design.accent;typeRole:"caption"}
      ActionButton {objectName:"downloadOpenFolder";iconText:"󰉋";tooltipText:root.strings.t("downloads.openFolder");horizontalPadding:Design.gap.tight;verticalPadding:0;implicitHeight:Design.inlineControlHeight;onClicked:root.service.openDownload(root.row)}
      ActionButton {visible:!root.row.active && root.expanded;iconText:"󰅖";tooltipText:root.strings.t("delete");horizontalPadding:Design.gap.tight;verticalPadding:0;implicitHeight:Design.inlineControlHeight;onClicked:root.service.remove(root.row.key)}
    }
    DownloadProgress {objectName:"downloadProgress";Layout.fillWidth:true;visible:root.row.active;active:root.row.active}
  }
}
