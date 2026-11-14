import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
  id:root
  required property var bridge
  required property var strings
  property var row:null
  property var feedback:null
  readonly property string key:row ? row.id : "new"
  readonly property string state:bridge ? bridge.actionStatus(key) : ""
  readonly property bool sending:state==="sending" || state==="uncertain"
  readonly property bool writable:!!bridge && bridge.connected && bridge.responsesEnabled && !sending
  readonly property bool attached:!!row && row.attached
  readonly property bool automatic:!!row && !attached && row.status!=="unloaded"
  readonly property bool busy:!!row && row.status==="running"
  spacing:Design.gap.small
  DesignTextField {
    id:directory
    objectName:"codexDirectory"
    Layout.fillWidth:true;visible:!root.row
    placeholderText:root.strings.t("codex.directory")
    maximumLength:4096;enabled:root.writable
    Accessible.name:placeholderText
  }
  DesignTextField {
    id:message
    objectName:"codexMessage"
    Layout.fillWidth:true;visible:!root.row || root.attached
    placeholderText:root.strings.t("codex.message")
    maximumLength:16000;enabled:root.writable && !root.busy && (!root.row || !root.row.requestId)
    Accessible.name:placeholderText
  }
  RowLayout {
    Layout.fillWidth:true
    ActionButton {
      objectName:"codexAction"
      feedback:root.feedback
      text:root.strings.t(!root.row ? "codex.create" : root.automatic ? "codex.connecting" : !root.attached ? "codex.resume" : "codex.send")
      enabled:root.writable && !root.automatic && (!root.row ? directory.text.charAt(0)==="/" && !!message.text.trim() : !root.attached || (!root.busy && !root.row.requestId && !!message.text.trim()))
      onClicked:root.bridge.act(!root.row ? "create" : !root.attached ? "attach" : "message",root.row ? root.row.id : "",message.text,directory.text)
    }
    ActionButton {
      objectName:"codexInterrupt"
      feedback:root.feedback;visible:root.attached && root.busy
      text:root.strings.t("codex.interrupt")
      enabled:root.writable && !!root.row && !!root.row.turnId
      onClicked:root.bridge.act("interrupt",root.row.id,"","")
    }
  }
  PlainText {
    Layout.fillWidth:true;wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText
    text:root.strings.t(root.state ? "codex.response."+root.state : !root.row ? "codex.createHint" : !root.bridge.responsesEnabled ? "codex.readOnly" : root.attached ? "codex.attached" : root.automatic ? (root.row.attachState==="retrying" ? "codex.retrying" : "codex.autoConnectHint") : "codex.historyHint")
  }
  onStateChanged:if(state==="sent") message.text=""
}
