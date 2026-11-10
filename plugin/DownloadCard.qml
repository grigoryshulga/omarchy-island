import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Downloads.js" as Downloads

Rectangle {
  id:root
  required property var row
  required property var service
  required property var strings
  property bool expanded:false
  activeFocusOnTab:expanded
  objectName:"download-"+row.key
  color:Style.normalFillFor(Commons.Color.foreground,Commons.Color.accent)
  border.width:Math.max(1,Style.space(1))
  border.color:Style.hoverFillFor(Commons.Color.foreground,Commons.Color.accent)
  radius:Style.cornerRadius
  implicitHeight:content.implicitHeight+Style.space(16)
  Keys.onReturnPressed:service.openDownload(row)
  Keys.onEnterPressed:service.openDownload(row)
  Keys.onSpacePressed:service.openDownload(row)
  MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.service.openDownload(root.row)}
  ColumnLayout {
    id:content
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Style.space(8)
    spacing:Style.space(4)
    RowLayout {
      Layout.fillWidth:true
      spacing:Style.space(8)
      PlainText {text:"󰇚";color:Commons.Color.accent;font.pixelSize:Style.font.icon}
      PlainText {objectName:"downloadFilename";Layout.fillWidth:true;Layout.minimumWidth:0;text:root.row.filename;font.pixelSize:Style.font.body;elide:Text.ElideMiddle;maximumLineCount:1}
      PlainText {text:new Date(root.row.ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm");color:Commons.Color.muted;font.pixelSize:Style.font.caption}
    }
    RowLayout {
      Layout.fillWidth:true
      spacing:Style.space(6)
      PlainText {text:root.strings.t(root.row.active ? "downloads.downloading" : "downloads.complete");color:Commons.Color.muted;font.pixelSize:Style.font.caption}
      PlainText {objectName:"downloadSize";Layout.fillWidth:true;text:Downloads.sizeText(root.row.downloadedBytes,Commons.I18n.formatNumber);color:Commons.Color.accent;font.pixelSize:Style.font.caption}
      ActionButton {objectName:"downloadOpenFolder";iconText:"󰉋";tooltipText:root.strings.t("downloads.openFolder");horizontalPadding:Style.space(4);verticalPadding:0;onClicked:root.service.openDownload(root.row)}
      ActionButton {visible:!root.row.active && root.expanded;iconText:"󰅖";tooltipText:root.strings.t("delete");horizontalPadding:Style.space(4);verticalPadding:0;onClicked:root.service.remove(root.row.key)}
    }
    DownloadProgress {objectName:"downloadProgress";Layout.fillWidth:true;visible:root.row.active;active:root.row.active}
  }
}
