import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../.." as Island

Island.ModuleView {
  id:root
  available:!!backend
  implicitHeight:content.implicitHeight
  readonly property var strings:presentation ? presentation.strings : null
  readonly property string connectionState:!backend || !backend.allowed ? "disabled"
      : backend.status==="connected" || backend.status==="connecting" ? backend.status : "offline"
  readonly property string reason:backend && backend.allowed ? backend.reason : ""
  property bool detailsOpen:false
  readonly property bool hasDetails:!!backend && backend.allowed && (!!reason || !!backend.serverVersion || !!backend.cliPath || backend.lastConnectedAt>0)
  onHasDetailsChanged:if(!hasDetails) detailsOpen=false
  Column {
    id:content
    width:parent.width
    spacing:Island.Design.gap.small
    GridLayout {
      width:parent.width
      columns:statusLabel.implicitWidth+retry.implicitWidth+columnSpacing<=width ? 2 : 1
      layoutDirection:Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
      columnSpacing:Island.Design.gap.medium;rowSpacing:Island.Design.gap.small
      Island.PlainText {
        id:statusLabel;objectName:"t3ConnectionStatus"
        Layout.fillWidth:true;Layout.minimumWidth:0
        text:root.strings ? root.strings.t("t3.connection."+root.connectionState) : ""
        wrapMode:Text.Wrap;typeRole:"body"
        color:root.connectionState==="connected" ? Island.Design.success : root.connectionState==="offline" ? Island.Design.warning : Island.Design.secondaryText
      }
      Island.ActionButton {
        id:retry;objectName:"t3Reconnect"
        visible:!!root.backend && root.backend.allowed
        enabled:visible && root.connectionState!=="connecting"
        Layout.maximumWidth:parent.width
        variant:"soft";bordered:true;iconText:"󰑐"
        text:root.strings ? root.strings.t("t3.reconnect") : ""
        feedback:root.presentation ? root.presentation.feedback : null
        onActiveFocusChanged:if(activeFocus && root.presentation) root.presentation.revealFocus(retry)
        onClicked:root.backend.restart()
      }
    }
    Island.ActionButton {
      id:disclosure;objectName:"t3ConnectionDetails"
      visible:root.hasDetails
      width:Math.min(implicitWidth,parent.width)
      x:Commons.I18n.rightToLeft ? parent.width-width : 0
      text:root.strings ? root.strings.t("t3.details") : ""
      iconText:Commons.I18n.rightToLeft ? "󰅁" : "󰅂"
      iconRotation:root.detailsOpen ? (Commons.I18n.rightToLeft ? -90 : 90) : 0
      foreground:Island.Design.secondaryText
      Accessible.expandable:true;Accessible.expanded:root.detailsOpen
      feedback:root.presentation ? root.presentation.feedback : null
      onActiveFocusChanged:if(activeFocus && root.presentation) root.presentation.revealFocus(disclosure)
      onClicked:root.detailsOpen=!root.detailsOpen
    }
    Column {
      width:parent.width-Island.Design.gap.medium
      x:Commons.I18n.rightToLeft ? 0 : Island.Design.gap.medium
      visible:root.hasDetails && root.detailsOpen
      spacing:Island.Design.gap.small
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
    }
  }
}
