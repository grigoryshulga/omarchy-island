import QtQuick
import "../.." as Island

Island.ModuleView {
  id:root
  available:!!backend
  implicitHeight:body.implicitHeight
  Column {
    id:body
    width:parent.width;spacing:Island.Design.gap.small
    Island.PlainText {
      width:parent.width;wrapMode:Text.Wrap;typeRole:"caption"
      text:root.presentation.strings.t("t3.connection."+(!root.backend || !root.backend.allowed ? "disabled" : root.backend.status))
    }
    Island.PlainText {
      width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Island.Design.secondaryText
      text:root.presentation.strings.t(root.backend && root.backend.reason ? "codex.connectionError" : "codex.setup")
    }
    Island.ActionButton {
      text:root.presentation.strings.t("t3.reconnect")
      enabled:!!root.backend && root.backend.allowed
      feedback:root.presentation.feedback
      onClicked:root.backend.restart()
    }
  }
}
