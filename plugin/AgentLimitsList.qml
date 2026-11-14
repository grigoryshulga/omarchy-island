import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import "sdk" as UI
import "AgentLimitsModel.js" as Model

Column {
  id: root
  required property var backend
  required property var strings
  property var feedback: null
  property bool editingPins: false
  readonly property var providers: backend ? backend.cache.providers : []
  signal settingRequested(string key, var value)

  spacing: Design.gap.medium
  LayoutMirroring.enabled: Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit: true
  onVisibleChanged: if (!visible) editingPins = false
  onProvidersChanged: syncProviders()
  Component.onCompleted: syncProviders()

  function syncProviders() {
    Model.syncIdentities(providerItems, providers.map(function(p) { return p.id }), "providerId")
  }

  ListModel { id: providerItems }

  FeedbackButton {
    objectName: "limitsEditPins"
    visible: root.providers.length > 0
    text: root.strings.t(root.editingPins ? "limits.finishPins" : "limits.editPins")
    selected: root.editingPins
    compact: true
    focusable: true
    feedback: root.feedback
    onClicked: root.editingPins = !root.editingPins
  }
  PlainText {
    visible: root.editingPins
    width: parent.width
    typeRole: "caption"
    color: Design.secondaryText
    wrapMode: Text.Wrap
    text: root.strings.t("limits.pinOrderHelp")
  }

  Repeater {
    model: providerItems
    AgentLimitsProviderGroup {
      required property string providerId
      width: root.width
      provider: root.providers.find(function(p) { return p.id === providerId }) || ({id: providerId})
      rows: root.backend ? root.backend.rows.filter(function(row) { return row.providerId === providerId }) : []
      pins: root.backend ? root.backend.pins : []
      now: root.backend ? root.backend.now : 0
      editingPins: root.editingPins
      strings: root.strings
      feedback: root.feedback
      onPinsRequested: pins => root.settingRequested("agentLimitsPins", pins)
    }
  }

  UI.DataState {
    visible: root.providers.length === 0
    width: parent.width
    title: root.strings.t("limits.noWindows")
  }
}
