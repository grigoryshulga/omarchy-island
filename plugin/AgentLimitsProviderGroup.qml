import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import "AgentLimitsModel.js" as Model

Column {
  id: root
  required property var provider
  required property var rows
  required property var pins
  required property var strings
  property var feedback: null
  property double now: 0
  property bool editingPins: false
  readonly property string balanceText: Model.balances(provider, Commons.I18n.formatNumber)
  signal pinsRequested(var pins)
  function focusEditor() { editor.forceActiveFocus() }
  signal editRequested()
  signal moveRequested(int direction)

  objectName: "limitsProvider-" + provider.id
  spacing: Design.gap.small
  onRowsChanged: syncRows()
  Component.onCompleted: syncRows()

  function syncRows() {
    Model.syncIdentities(windowItems, rows.map(function(row) { return row.id }), "windowId")
  }

  ListModel { id: windowItems }

  RowLayout {
    width: parent.width
    spacing: Design.gap.small
    AgentProviderIcon { providerId: root.provider.id }
    PlainText {
      objectName: "limitsProviderName"
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      typeRole: "section"
      text: Model.text(root.provider.name) || root.provider.id
    }
    FeedbackButton {
      id: editor
      objectName: "limitsProviderEdit-" + root.provider.id
      visible: root.editingPins
      iconText: "󰒓"
      tooltipText: root.strings.t("limits.provider.connection")
      compact: true; focusable: true; feedback: root.feedback
      onClicked: root.editRequested()
      Keys.onPressed: event => {
        if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
          root.moveRequested(event.key === Qt.Key_Up ? -1 : 1)
          event.accepted = true
        }
      }
    }
    PlainText {
      Layout.maximumWidth: root.width * 0.5
      typeRole: "caption"
      color: Design.secondaryText
      text: Model.text(root.provider.plan)
      visible: text !== ""
    }
  }
  PlainText {
    width: parent.width
    visible: root.provider.status === "error" || !!root.provider.stale
    wrapMode: Text.Wrap
    typeRole: "caption"
    color: Design.warning
    text: root.strings.t(root.provider.status === "error" ? "limits.providerError" : "limits.cached")
  }
  PlainText {
    objectName: "limitsProviderBalance"
    width: parent.width
    visible: root.balanceText !== ""
    wrapMode: Text.Wrap
    text: root.strings.t("limits.balance").arg(root.balanceText)
  }

  Repeater {
    model: windowItems
    AgentLimitDetail {
      required property string windowId
      width: root.width
      row: root.rows.find(function(row) { return row.id === windowId }) || ({id: windowId, remaining: null})
      pins: root.pins
      now: root.now
      editingPins: root.editingPins
      strings: root.strings
      feedback: root.feedback
      onPinsRequested: pins => root.pinsRequested(pins)
    }
  }

  PlainText {
    objectName: "limitsProviderEmpty"
    visible: root.rows.length === 0 && root.balanceText === ""
    width: parent.width
    typeRole: "caption"
    color: Design.secondaryText
    wrapMode: Text.Wrap
    text: root.strings.t(["openai-api", "gemini"].indexOf(root.provider.id) >= 0
      ? "limits.localOnly" : "limits.unavailable")
  }
}
