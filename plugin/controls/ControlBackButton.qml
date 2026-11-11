import QtQuick
import qs.Commons
import qs.Commons as Commons
import ".."

FeedbackButton {
  objectName:"controlBack"
  property bool islandExternalNavigation:true
  implicitWidth:Design.compactControlHeight
  implicitHeight:Design.compactControlHeight
  iconText:Commons.I18n.rightToLeft ? "󰁔" : "󰁍"
  iconSize:Style.font.iconLarge
  foreground:activeFocus || hot ? Design.accent : Design.text
  horizontalPadding:0
  verticalPadding:0
  focusable:true
  tooltipText:strings.t("calendar.back")
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("../i18n")}
}
