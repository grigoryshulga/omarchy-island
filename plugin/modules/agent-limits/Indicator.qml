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
  implicitWidth:root.presentation.vertical ? Math.min(root.presentation.barSize-Style.space(4),limitIndicatorText.implicitWidth) : limitIndicatorText.implicitWidth
  implicitHeight:root.presentation.vertical ? Style.space(18) : root.presentation.barHeight
  PlainText {
    id:limitIndicatorText
    anchors.centerIn:parent
    width:parent.width;elide:Text.ElideRight;typeRole:"bar"
    text:root.backend && root.backend.tightest ? "󰧑 "+Commons.I18n.formatNumber(Math.round(root.backend.tightest.remaining))+"%"+(root.backend.tightest.stale ? " ·" : "") : ""
    color:root.backend && root.backend.tightest && root.backend.tightest.remaining<=Math.min(Preferences.get("agentLimitsWarning"),Preferences.get("agentLimitsCritical")) ? Design.barDanger : Design.barText
  }
  MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.detailsRequested()}
}
