import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../.."
import "../.." as Island

Island.ModuleView {
  id:root
  objectName:"islandAgentLimitsIndicator"
  available:!!root.backend && root.backend.indicatorVisible
  tooltip:backend && backend.indicatorVisible && backend.tightest ? backend.tightest.name+" · "+backend.tightest.label+" · "+Commons.I18n.formatNumber(Math.round(backend.tightest.remaining))+"%" : ""
  readonly property real sidePadding:presentation.vertical ? 0 : Island.Design.gap.tight
  implicitWidth:root.presentation.vertical ? Math.min(root.presentation.barSize-Style.space(4),limitIndicatorText.implicitWidth) : Math.ceil(limitIndicatorText.implicitWidth+2*sidePadding)
  implicitHeight:root.presentation.vertical ? Style.space(18) : root.presentation.barHeight
  PlainText {
    id:limitIndicatorText
    anchors.centerIn:parent
    width:Math.max(0,parent.width-2*root.sidePadding);elide:Text.ElideRight;typeRole:"bar"
    text:root.backend && root.backend.tightest ? "󰧑 "+Commons.I18n.formatNumber(Math.round(root.backend.tightest.remaining))+"%"+(root.backend.tightest.stale ? " ·" : "") : ""
    color:root.backend && root.backend.tightest && root.backend.tightest.remaining<=Math.min(Preferences.get("agentLimitsWarning"),Preferences.get("agentLimitsCritical")) ? Design.barDanger : Design.barText
  }
  FeedbackButton {
    objectName:"moduleIndicatorAction"
    anchors.fill:parent;focusable:true
    horizontalPadding:0;verticalPadding:0
    tooltipText:root.presentation.strings.t("indicator.openModule").arg(root.presentation.strings.t("limits.title"))
    onClicked:root.detailsRequested()
  }
}
