import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../.."
import "../.." as Island

Island.ModuleView {
  id:root
  objectName:"islandT3Indicator"
  readonly property var counts:backend && backend.counts
  readonly property string category:counts && counts.attention ? "attention" : counts && counts.failed ? "failed" : "finished"
  readonly property int count:counts ? counts[category] : 0
  available:!!backend && backend.allowed && count>0
  readonly property string text:Commons.I18n.formatNumber(count)
  tooltip:presentation.strings.t(category==="attention" ? "overview.t3Attention" : category==="failed" ? "overview.t3Failed" : "overview.t3Finished").arg(text)
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
    PlainText {text:root.category==="attention" ? "󰋗" : root.category==="failed" ? "󰅙" : "✓";color:root.color;typeRole:"bar";Layout.alignment:Qt.AlignVCenter;verticalAlignment:Text.AlignVCenter}
    PlainText {id:t3Count;objectName:"islandT3Count";Layout.maximumWidth:root.presentation.vertical ? root.presentation.barSize-Style.space(4) : Infinity;elide:Text.ElideRight;text:root.text;color:root.color;typeRole:"bar";font.family:root.presentation.bar ? root.presentation.bar.fontFamily : Style.font.family;Layout.preferredHeight:root.presentation.vertical ? Style.space(18) : root.presentation.barHeight;verticalAlignment:Text.AlignVCenter}
  }
  FeedbackButton {
    objectName:"moduleIndicatorAction"
    anchors.fill:parent;focusable:true
    horizontalPadding:0;verticalPadding:0
    tooltipText:"T3 Code · "+root.tooltip
    onClicked:root.detailsRequested()
  }
}
