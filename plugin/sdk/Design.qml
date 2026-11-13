pragma Singleton
import QtQuick
import ".." as Island

// Read-only, live bindings to the host design system.
QtObject {
  readonly property string fontFamily: Island.Design.fontFamily
  readonly property QtObject type: Island.Design.type
  readonly property QtObject gap: Island.Design.gap
  readonly property int controlHeight: Island.Design.controlHeight
  readonly property int compactControlHeight: Island.Design.compactControlHeight
  readonly property int inlineControlHeight: Island.Design.inlineControlHeight
  readonly property int fieldHeight: Island.Design.fieldHeight
  readonly property int optionHeight: Island.Design.optionHeight
  readonly property int cardPadding: Island.Design.cardPadding
  readonly property int panelPadding: Island.Design.panelPadding
  readonly property real cardRadius: Island.Design.cardRadius
  readonly property real controlRadius: Island.Design.controlRadius
  readonly property int feedbackDuration: Island.Design.feedbackDuration
  readonly property int transitionDuration: Island.Design.transitionDuration
  readonly property int revealDuration: Island.Design.revealDuration
  readonly property int spinnerDuration: Island.Design.spinnerDuration
  readonly property real disabledOpacity: Island.Design.disabledOpacity
  readonly property color canvas: Island.Design.canvas
  readonly property color opaqueCanvas: Island.Design.opaqueCanvas
  readonly property color surface: Island.Design.surface
  readonly property color raised: Island.Design.raised
  readonly property color text: Island.Design.text
  readonly property color secondaryText: Island.Design.secondaryText
  readonly property color accent: Island.Design.accent
  readonly property color info: Island.Design.info
  readonly property color success: Island.Design.success
  readonly property color warning: Island.Design.warning
  readonly property color danger: Island.Design.danger
  readonly property color onAccent: Island.Design.onAccent
  readonly property color fieldBorder: Island.Design.fieldBorder
  readonly property color focusRing: Island.Design.focusRing
  readonly property color selection: Island.Design.selection
  readonly property color hover: Island.Design.hover
  readonly property color pressed: Island.Design.pressed
  readonly property color selectedText: Island.Design.selectedText
  readonly property color selectedSecondaryText: Island.Design.selectedSecondaryText
  readonly property color barText: Island.Design.barText
  readonly property color barAccent: Island.Design.barAccent
  readonly property color barDanger: Island.Design.barDanger
  function fontSize(role) { return Island.Design.fontSize(role) }
  function lineHeight(role) { return Island.Design.lineHeight(role) }
  function weight(role) { return Island.Design.weight(role) }
}
