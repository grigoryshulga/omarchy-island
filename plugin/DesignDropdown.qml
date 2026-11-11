import QtQuick
import qs.Ui as Ui

// Keep the native dropdown's keyboard, popup and selection lifecycle.
Ui.Dropdown {
  foreground: Design.text
  background: Design.opaqueCanvas
  accent: Design.accent
  fontFamily: Design.fontFamily
  rowHeight: Design.fieldHeight
  popupRowHeight: Design.controlHeight
  opacity: enabled ? 1 : Design.disabledOpacity
}
