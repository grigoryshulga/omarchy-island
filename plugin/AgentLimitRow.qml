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
  property bool compact:false
  property var feedback:null
  property double now:Date.now()
  Accessible.name:row.name+" · "+row.label
  Accessible.description:strings.t(row.pendingReset ? "limits.awaitingReset" : row.stale ? "limits.cached" : "limits.remaining")
  signal pinRequested(string id)
  readonly property real padding:compact ? Design.gap.small : Design.gap.large
  implicitHeight:body.implicitHeight+padding*2
  LayoutMirroring.enabled:Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit:true
  ColumnLayout {
    id:body
    x:root.padding;y:root.padding
    width:parent.width-2*root.padding
    spacing:Design.gap.tight
    RowLayout {
      Layout.fillWidth:true
      PlainText {Layout.fillWidth:true;Layout.minimumWidth:0;typeRole:root.compact ? "body" : "title";text:root.row.name+" · "+root.row.label;elide:Text.ElideRight}
      BatteryGauge {
        visible:root.compact && root.row.remaining!==null
        Layout.preferredWidth:Style.space(104)
        fraction:root.row.remaining===null ? 0 : root.row.remaining/100
        warningThreshold:(Math.min(Preferences.get("agentLimitsWarning"),Preferences.get("agentLimitsCritical"))+0.001)/100
      }
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
      visible:!root.compact && root.row.remaining!==null
      fraction:root.row.remaining===null ? 0 : root.row.remaining/100
      warningThreshold:(Math.min(Preferences.get("agentLimitsWarning"),Preferences.get("agentLimitsCritical"))+0.001)/100
    }
    PlainText {
      Layout.fillWidth:true;typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap
      objectName:"limitResetCountdown"
      visible:!root.compact && text!==""
      text:Model.resetCountdown(root.row,root.now,root.strings,Commons.I18n.formatNumber)
    }
  }
}
