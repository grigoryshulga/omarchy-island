import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../.."
import "../.." as Island

Island.ModuleView {
  id:root
  objectName:"islandT3Indicator"
  available:!!root.backend && root.backend.allowed && (root.backend.waitingCount>0 || root.backend.workingCount>0)
  readonly property bool waiting:!!root.backend && root.backend.waitingCount>0
  readonly property string text:Commons.I18n.formatNumber(root.backend ? root.backend.waitingCount || root.backend.workingCount : 0)
  readonly property color color:root.presentation.showAlert ? Commons.Color.accent : root.presentation.bar ? root.presentation.bar.barForeground : Commons.Color.foreground
  implicitWidth:root.presentation.vertical ? Math.min(root.presentation.barSize-Style.space(4),t3IndicatorBody.implicitWidth) : t3IndicatorBody.implicitWidth;implicitHeight:t3IndicatorBody.implicitHeight
  GridLayout {
    columns:root.presentation.vertical ? 1 : -1
    rows:root.presentation.vertical ? -1 : 1
    id:t3IndicatorBody
    anchors.centerIn:parent
    width:parent.width
    columnSpacing:Style.space(4);rowSpacing:Style.space(4)
    T3Spinner {objectName:"islandT3Spinner";tint:root.color;visible:!root.waiting;active:root.visible && root.available;implicitWidth:t3Count.font.pixelSize*0.75;Layout.alignment:Qt.AlignVCenter}
    PlainText {visible:root.waiting;text:"󰋗";color:root.color;typeRole:"bar";Layout.alignment:Qt.AlignVCenter;verticalAlignment:Text.AlignVCenter}
    PlainText {id:t3Count;objectName:"islandT3Count";Layout.maximumWidth:root.presentation.vertical ? root.presentation.barSize-Style.space(4) : Infinity;elide:Text.ElideRight;text:root.text;color:root.color;typeRole:"bar";font.family:root.presentation.bar ? root.presentation.bar.fontFamily : Style.font.family;Layout.preferredHeight:root.presentation.vertical ? Style.space(18) : root.presentation.barHeight;verticalAlignment:Text.AlignVCenter}
  }
  MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.detailsRequested()}
}
