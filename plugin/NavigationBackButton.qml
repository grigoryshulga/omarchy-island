import QtQuick
import qs.Commons

FeedbackButton {
  required property var strings
  compact:true
  focusable:true
  implicitWidth:Design.compactControlHeight
  implicitHeight:Design.compactControlHeight
  horizontalPadding:0
  verticalPadding:0
  iconSize:Style.font.iconLarge
  iconText:LayoutMirroring.enabled ? "󰁔" : "󰁍"
  tooltipText:strings.t("navigation.back")
}
