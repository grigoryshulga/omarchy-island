import QtQuick
import qs.Ui
import qs.Commons
import ".."

PanelActionButton {
  foreground: Design.text
  fontFamily: Design.fontFamily
  size: Design.compactControlHeight
  radius: Design.controlRadius
  borderSpec: activeFocus && focusable ? Border.flat(Design.focusRing,2) : Border.none()
}
