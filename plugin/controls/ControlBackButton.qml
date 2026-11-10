import QtQuick
import qs.Commons
import qs.Commons as Commons
import ".."

FeedbackButton {
  objectName:"controlBack"
  property bool islandExternalNavigation:true
  implicitWidth:Style.space(26)
  implicitHeight:Style.space(28)
  iconText:Commons.I18n.rightToLeft ? "󰁔" : "󰁍"
  iconSize:Style.font.iconLarge
  foreground:activeFocus || hot ? Commons.Color.accent : Commons.Color.foreground
  color:"transparent"
  borderSpec:Border.none()
  horizontalPadding:0
  verticalPadding:0
  focusable:true
  tooltipText:strings.t("calendar.back")
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("../i18n")}
}
