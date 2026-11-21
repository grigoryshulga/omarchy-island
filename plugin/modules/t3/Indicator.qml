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
  readonly property real sidePadding:presentation.vertical ? 0 : Island.Design.gap.tight
  implicitWidth:root.presentation.vertical ? Math.min(root.presentation.barSize-Style.space(4),t3IndicatorBody.implicitWidth) : Math.ceil(t3IndicatorBody.implicitWidth+2*sidePadding);implicitHeight:t3IndicatorBody.implicitHeight
  GridLayout {
    columns:root.presentation.vertical ? 1 : -1
    rows:root.presentation.vertical ? -1 : 1
    id:t3IndicatorBody
    anchors.centerIn:parent
    width:Math.max(0,parent.width-2*root.sidePadding)
    columnSpacing:Style.space(4);rowSpacing:Style.space(4)
    T3Spinner {objectName:"islandT3Spinner";tint:root.color;visible:!root.waiting;active:root.visible && root.available;implicitWidth:t3Count.font.pixelSize*0.75;Layout.alignment:Qt.AlignVCenter;transform:Translate {y:Style.space(1)}}
    PlainText {visible:root.waiting;text:"󰋗";color:root.color;typeRole:"bar";Layout.alignment:Qt.AlignVCenter;verticalAlignment:Text.AlignVCenter}
    PlainText {id:t3Count;objectName:"islandT3Count";Layout.maximumWidth:root.presentation.vertical ? root.presentation.barSize-Style.space(4) : Infinity;elide:Text.ElideRight;text:root.text;color:root.color;typeRole:"bar";font.family:root.presentation.bar ? root.presentation.bar.fontFamily : Style.font.family;Layout.preferredHeight:root.presentation.vertical ? Style.space(18) : root.presentation.barHeight;verticalAlignment:Text.AlignVCenter}
  }
  FeedbackButton {
    objectName:"moduleIndicatorAction"
    anchors.fill:parent;focusable:true
    horizontalPadding:0;verticalPadding:0
    tooltipText:root.presentation.strings.t("indicator.openModule").arg("T3 Code")
    onClicked:root.detailsRequested()
  }
}
