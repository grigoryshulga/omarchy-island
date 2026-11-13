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
  Accessible.name:Model.displayName(row)
  Accessible.description:strings.t(row.pendingReset ? "limits.awaitingReset" : row.stale ? "limits.cached" : "limits.remaining")
  signal pinRequested(string id)
  readonly property real padding:compact ? Design.gap.small : Design.gap.large
  readonly property color gaugeColor:row.remaining===null ? Design.accent : row.remaining<=Math.min(Preferences.get("agentLimitsWarning"),Preferences.get("agentLimitsCritical")) ? Design.danger : row.remaining<=Preferences.get("agentLimitsWarning") ? Design.warning : Design.accent
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
      spacing:Design.gap.small
      PlainText {
        objectName:"limitRemaining"
        typeRole:root.compact ? "body" : "title"
        text:(root.row.remaining===null ? "—" : Commons.I18n.formatNumber(Math.round(root.row.remaining))+"%")+(root.row.stale ? " ·" : "")
        color:root.row.remaining!==null && root.row.remaining<=Math.min(Preferences.get("agentLimitsWarning"),Preferences.get("agentLimitsCritical")) ? Design.danger : Design.text
      }
      PlainText {
        objectName:"limitName"
        Layout.fillWidth:true;Layout.minimumWidth:0
        typeRole:root.compact ? "body" : "title"
        text:Model.displayName(root.row);elide:Text.ElideRight
      }
      PlainText {
        objectName:"limitSummaryResetCountdown"
        visible:root.compact && text!==""
        Layout.maximumWidth:root.width*0.48;Layout.minimumWidth:0
        typeRole:"caption";color:Design.secondaryText;elide:Text.ElideRight
        text:Model.resetCountdown(root.row,root.now,root.strings,Commons.I18n.formatNumber)
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
    BrailleProgress {
      objectName:"limitBrailleProgress"
      Layout.fillWidth:true
      Layout.preferredHeight:Style.space(root.compact ? 10 : 24)
      visible:root.row.remaining!==null
      value:root.row.remaining===null ? 0 : root.row.remaining/100
      accent:root.gaugeColor
    }
    PlainText {
      Layout.fillWidth:true;typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap
      objectName:"limitResetCountdown"
      visible:!root.compact && text!==""
      text:Model.resetCountdown(root.row,root.now,root.strings,Commons.I18n.formatNumber)
    }
  }
}
