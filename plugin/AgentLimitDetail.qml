import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import qs.Commons as Commons
import "AgentLimitsModel.js" as Model

ColumnLayout {
  id: root
  required property var row
  required property var pins
  required property var strings
  property var feedback: null
  property double now: 0
  property bool editingPins: false
  readonly property int pinIndex: pins.indexOf(row.id)
  readonly property bool known: row.remaining !== null
  readonly property color quotaColor: !known ? Design.secondaryText
    : row.remaining <= Math.min(Preferences.get("agentLimitsWarning"), Preferences.get("agentLimitsCritical")) ? Design.danger
    : row.remaining <= Preferences.get("agentLimitsWarning") ? Design.warning : Design.text
  signal pinsRequested(var pins)

  objectName: "limitDetail-" + row.id
  spacing: Design.gap.tight

  RowLayout {
    Layout.fillWidth: true
    spacing: Design.gap.small
    PlainText {
      objectName: "limitName"
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      wrapMode: Text.Wrap
      text: Model.windowLabel(root.row, root.strings)
    }
    ColumnLayout {
      spacing: 0
      PlainText {
        objectName: "limitRemaining"
        Layout.alignment: Qt.AlignRight
        typeRole: "section"
        color: root.quotaColor
        text: root.known ? Commons.I18n.formatNumber(Math.round(root.row.remaining)) + "%" : "—"
      }
      PlainText {
        objectName: "limitRemainingLabel"
        Layout.alignment: Qt.AlignRight
        typeRole: "caption"
        color: root.quotaColor
        text: root.strings.t(!root.known ? "limits.unavailable" : root.row.exhausted ? "limits.exhausted" : "limits.remaining")
      }
    }
    FeedbackButton {
      objectName: "limitPin"
      visible: root.editingPins
      compact: true
      focusable: true
      selected: root.pinIndex >= 0
      text: selected ? "󰐃" : "󰐄"
      tooltipText: root.strings.t(selected ? "limits.unpin" : "limits.pin")
      Accessible.name: tooltipText + " · " + Model.displayName(root.row)
      Accessible.description: resetCaption.exactReset
      feedback: root.feedback
      onClicked: root.pinsRequested(Model.toggle(root.pins, root.row.id))
    }
  }
  BrailleProgress {
    objectName: "limitBrailleProgress"
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    visible: root.known
    value: root.known ? root.row.remaining / 100 : 0
    accent: root.quotaColor === Design.text ? Design.accent : root.quotaColor
  }
  RowLayout {
    Layout.fillWidth: true
    spacing: Design.gap.small
    PlainText {
      id: resetCaption
      objectName: "limitResetCountdown"
      readonly property string exactReset: root.row.resetsAt > 0 && !root.row.pendingReset
        ? root.strings.t("limits.resetAt").arg(new Date(root.row.resetsAt).toLocaleString(Qt.locale(Commons.I18n.formatLocale), Locale.ShortFormat)) : ""
      Accessible.name: text
      Accessible.description: exactReset
      HoverHandler { id: resetHover }
      Controls.ToolTip {
        visible: root.visible && resetHover.hovered && resetCaption.exactReset !== ""
        delay: 400
        text: resetCaption.exactReset
        padding: Design.gap.small
        background: BorderSurface {
          color: Commons.Color.tooltip.background
          borderSpec: Border.surfaceSpec("tooltip", "border", Commons.Color.tooltip.border, Math.max(1, Style.normalBorderWidth))
          radius: 0
        }
        contentItem: PlainText { text: resetCaption.exactReset; color: Commons.Color.tooltip.text; typeRole: "caption" }
      }
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      Layout.alignment: Qt.AlignTop
      typeRole: "caption"
      wrapMode: Text.Wrap
      color: Design.secondaryText
      text: Model.resetCountdown(root.row, root.now, root.strings, Commons.I18n.formatNumber)
      visible: text !== ""
    }
    PlainText {
      objectName: "limitFreshness"
      horizontalAlignment: Text.AlignRight
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      Layout.alignment: Qt.AlignTop
      typeRole: "caption"
      wrapMode: Text.Wrap
      color: root.row.stale ? Design.warning : Design.secondaryText
      text: Model.freshness(root.row, root.now, root.strings, Commons.I18n.formatNumber)
    }
  }
}
