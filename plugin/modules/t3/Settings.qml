import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../.." as Island

Island.ModuleView {
  id:root
  available:!!backend
  implicitHeight:content.implicitHeight
  readonly property var strings:presentation ? presentation.strings : null
  readonly property string connectionState:!backend || !backend.allowed ? "disabled" : backend.status
  readonly property string reason:backend && backend.allowed ? backend.reason : ""
  Column {
    id:content
    width:parent.width
    spacing:Island.Design.gap.small
    Island.PlainText {
      objectName:"t3ConnectionStatus"
      width:parent.width
      text:root.strings ? root.strings.t("t3.connection."+root.connectionState) : ""
      wrapMode:Text.Wrap
      color:root.reason ? Island.Design.warning : Island.Design.secondaryText
      typeRole:"caption"
    }
    Island.PlainText {
      objectName:"t3ConnectionReason"
      width:parent.width
      visible:!!root.reason
      text:visible && root.strings ? root.strings.t("t3.diagnostic."+root.reason) : ""
      wrapMode:Text.Wrap;typeRole:"caption"
    }
    Island.PlainText {
      objectName:"t3ConnectionVersions"
      width:parent.width
      visible:!!root.backend && !!root.backend.serverVersion
      text:visible && root.strings ? root.strings.t("t3.versions").arg(root.backend.serverVersion).arg(root.backend.cliVersion || "—") : ""
      wrapMode:Text.Wrap;typeRole:"caption";color:Island.Design.secondaryText
    }
    Island.PlainText {
      objectName:"t3ConnectionCli"
      width:parent.width
      visible:!!root.backend && !!root.backend.cliPath
      text:visible && root.strings ? root.strings.t("t3.cli."+root.backend.cliSource).arg(root.backend.cliPath) : ""
      wrapMode:Text.WrapAnywhere;typeRole:"caption";color:Island.Design.secondaryText
    }
    Island.PlainText {
      objectName:"t3ConnectionStage"
      width:parent.width
      visible:!!root.reason && !!root.backend.stage
      text:visible && root.strings ? root.strings.t("t3.stage").arg(root.strings.t("t3.stage."+root.backend.stage)) : ""
      wrapMode:Text.Wrap;typeRole:"caption";color:Island.Design.secondaryText
    }
    Island.PlainText {
      objectName:"t3ConnectionTime"
      width:parent.width
      visible:!!root.backend && root.backend.lastConnectedAt>0
      text:visible && root.strings ? root.strings.t("t3.lastConnected").arg(new Date(root.backend.lastConnectedAt).toLocaleString(Qt.locale(Commons.I18n.formatLocale),Locale.ShortFormat)) : ""
      wrapMode:Text.Wrap;typeRole:"caption";color:Island.Design.secondaryText
    }
    Island.ActionButton {
      id:retry
      objectName:"t3Reconnect"
      text:root.strings ? root.strings.t("t3.reconnect") : ""
      enabled:!!root.backend && root.backend.allowed && root.backend.status!=="connecting"
      x:Commons.I18n.rightToLeft ? parent.width-width : 0
      feedback:root.presentation ? root.presentation.feedback : null
      onActiveFocusChanged:if(activeFocus && root.presentation) root.presentation.revealFocus(retry)
      onClicked:root.backend.restart()
    }
  }
}
