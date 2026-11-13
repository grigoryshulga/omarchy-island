import QtQuick
import qs.Ui as Ui
import qs.Commons

Ui.TextField {
  id: root
  property bool invalid: false
  foreground: Design.text
  accent: Design.accent
  font.family: Design.fontFamily
  font.pixelSize: Design.type.body
  implicitHeight: Design.fieldHeight
  horizontalPadding: Design.gap.medium
  verticalPadding: Design.gap.small
  leftPadding: horizontalPadding+2
  rightPadding: horizontalPadding+2
  topPadding: verticalPadding+2
  bottomPadding: verticalPadding+2
  placeholderTextColor: Design.secondaryText
  selectionColor: Design.selection
  selectedTextColor: Design.selectedText
  background: Rectangle {
    color: Design.raised
    radius: Design.controlRadius
    border.color: root.activeFocus ? Design.focusRing : root.invalid ? Design.danger : Design.fieldBorder
    border.width: root.activeFocus ? 2 : 1
  }
  opacity: enabled ? 1 : Design.disabledOpacity
}
