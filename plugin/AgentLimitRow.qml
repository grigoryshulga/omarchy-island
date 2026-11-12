import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import qs.Commons
import "AgentLimitsModel.js" as Model

Surface {
  id:root
  required property var row
  required property var strings
  property bool pinned:false
  property bool interactive:false
  property var feedback:null
  property double now:Date.now()
  Accessible.name:row.name+" · "+row.label
  Accessible.description:strings.t(row.stale ? "limits.cached" : "limits.remaining")
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
        text:(root.row.remaining===null ? "—" : Commons.I18n.formatNumber(Math.round(root.row.remaining))+"%")+(root.row.stale ? " ·" : "")
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
      objectName:"limitResetCountdown"
      visible:text!==""
      text:Model.resetCountdown(root.row,root.now,root.strings,Commons.I18n.formatNumber)
    }
  }
}
