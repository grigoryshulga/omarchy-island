import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons

ColumnLayout {
  id: root
  required property var strings
  required property var targetIds
  required property string questionKey
  required property Item trigger
  required property Item fallback
  property bool permitted: true
  property string requestedTargets: ""
  readonly property string currentTargets: JSON.stringify(targetIds)
  readonly property bool opened: requestedTargets !== ""
  visible: opened
  Layout.fillWidth: true
  spacing: Design.gap.small
  signal confirmed()

  function ask() {
    if (!permitted || !targetIds.length) return
    requestedTargets = currentTargets
    cancelButton.forceActiveFocus(Qt.TabFocusReason)
  }
  function cancel(restoreFocus) {
    if (!opened) return false
    requestedTargets = ""
    if (restoreFocus) {
      var returnTarget = trigger.visible && trigger.enabled ? trigger : fallback
      returnTarget.forceActiveFocus(Qt.TabFocusReason)
    }
    return true
  }
  onCurrentTargetsChanged: if (opened && requestedTargets !== currentTargets) cancel(cancelButton.activeFocus || deleteButton.activeFocus)
  onPermittedChanged: if (!permitted) cancel(false)
  onVisibleChanged: if (!visible) cancel(false)
  Keys.onShortcutOverride: event => { if (opened && event.key === Qt.Key_Escape) event.accepted = true }
  Keys.onEscapePressed: event => { event.accepted = cancel(true) }

  PlainText {
    id: question
    objectName: root.objectName + "Question"
    Layout.fillWidth: true
    text: root.strings.t(root.questionKey).arg(Commons.I18n.formatNumber(root.targetIds.length))
    wrapMode: Text.Wrap
  }
  RowLayout {
    layoutDirection: Commons.I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
    FeedbackButton {
      id: cancelButton
      objectName: root.objectName + "Cancel"
      text: root.strings.t("bulk.cancel")
      Accessible.description: question.text
      compact: true
      focusable: true
      onClicked: root.cancel(true)
    }
    FeedbackButton {
      id: deleteButton
      objectName: root.objectName + "Delete"
      text: root.strings.t("bulk.delete")
      Accessible.description: question.text
      compact: true
      focusable: true
      foreground: Design.danger
      onClicked: {
        if (!root.opened || !root.permitted || root.currentTargets !== root.requestedTargets) return
        root.cancel(false)
        root.fallback.forceActiveFocus(Qt.TabFocusReason)
        root.confirmed()
      }
    }
  }
}
