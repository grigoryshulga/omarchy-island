import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../.."
import "../.." as Island

Island.ModuleView {
  id:root
  objectName:"islandBatteryIndicator"
  available:!!backend && backend.allowed && backend.present && backend.lowCharge
  readonly property string percentage:Commons.I18n.formatNumber(Math.round(backend ? backend.fraction*100 : 0))+"%"
  tooltip:presentation.strings.t("battery.lowCharge")+" · "+percentage
  implicitWidth:presentation.vertical ? Math.min(presentation.barSize-Style.space(4),button.implicitWidth) : button.implicitWidth
  implicitHeight:button.implicitHeight
  FeedbackButton {
    id:button
    objectName:"batteryIndicatorButton"
    width:parent.width
    text:(root.backend ? root.backend.icon : "")+(root.presentation.vertical ? "\n" : " ")+root.percentage
    foreground:Design.barDanger
    fontSize:Design.type.bar
    fontFamily:root.presentation.bar ? root.presentation.bar.fontFamily : Style.font.family
    implicitHeight:root.presentation.vertical ? fontSize*2.7 : root.presentation.barHeight
    horizontalPadding:0;verticalPadding:0
    focusable:true
    tooltipText:root.tooltip
    onClicked:root.detailsRequested()
  }
}
