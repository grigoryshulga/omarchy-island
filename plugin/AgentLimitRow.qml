import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import qs.Commons

Surface {
  id:root
  required property var row
  required property var strings
  property bool pinned:false
  property bool interactive:false
  property var feedback:null
  property double now:Date.now()
  signal pinRequested(string id)
  implicitHeight:body.implicitHeight+Design.gap.large*2
  LayoutMirroring.enabled:Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit:true
  ColumnLayout {
    id:body
    x:Design.gap.large;y:Design.gap.large
    width:parent.width-2*Design.gap.large
    spacing:Design.gap.tight
    RowLayout {
      Layout.fillWidth:true
      PlainText {Layout.fillWidth:true;typeRole:"title";text:root.row.name+" · "+root.row.label;elide:Text.ElideRight}
      PlainText {
        objectName:"limitRemaining"
        typeRole:"title"
        text:root.row.remaining===null ? "—" : Commons.I18n.formatNumber(Math.round(root.row.remaining))+"%"
        color:root.row.remaining!==null && root.row.remaining<=Math.min(Preferences.get("agentLimitsWarning"),Preferences.get("agentLimitsCritical")) ? Design.danger : Design.text
      }
      FeedbackButton {
        objectName:"limitPin"
        visible:root.interactive
        compact:true;text:root.pinned ? "󰐃" : "󰐄"
        selected:root.pinned;focusable:true;feedback:root.feedback
        tooltipText:root.strings.t(root.pinned ? "limits.unpin" : "limits.pin")
        onClicked:root.pinRequested(root.row.id)
      }
    }
    BatteryGauge {
      Layout.fillWidth:true
      visible:root.row.remaining!==null
      fraction:root.row.remaining===null ? 0 : root.row.remaining/100
      warningThreshold:(Math.min(Preferences.get("agentLimitsWarning"),Preferences.get("agentLimitsCritical"))+0.001)/100
    }
    PlainText {
      Layout.fillWidth:true;typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap
      text:[root.strings.t(root.row.pendingReset ? "limits.awaitingReset" : root.row.exhausted ? "limits.exhausted" : root.row.remaining===null ? "limits.unavailable" : root.row.remaining<=Preferences.get("agentLimitsWarning") ? "limits.low" : "limits.remaining"),
        root.row.stale ? root.strings.t("limits.cached") : "",
        root.row.checkedAt>0 ? root.strings.t("limits.measuredAt").arg(new Date(root.row.checkedAt).toLocaleString(Qt.locale(Commons.I18n.formatLocale),"ddd HH:mm")) : "",
        root.row.resetsAt>root.now && !root.row.pendingReset ? root.strings.t("limits.resetAt").arg(new Date(root.row.resetsAt).toLocaleString(Qt.locale(Commons.I18n.formatLocale),"ddd HH:mm")) : ""].filter(function(s){return !!s}).join(" · ")
    }
  }
}
