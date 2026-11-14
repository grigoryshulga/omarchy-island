import QtQuick
import "../.." as Island
Island.ModulePage {
  id:root
  available:true
  stableHeight:0
  readonly property string detailPage:content.detailPage
  navigationHidden:content.navigationHidden
  ownsKeys:content.ownsKeys
  function openDetails(id){content.openDetails(id)}
  implicitHeight:content.implicitHeight
  toastIcon:content.toastIcon
  interactionHovered:content.musicHovered
  function enter(){content.configuring=false;content.detailPage="";content.restoreSummary()}
  function back(){return content.back()}
  function focusSummary(target){content.focusSummary(target)}
  function configure(returnTarget){content.configure(returnTarget)}
  Island.IslandContent {
    id:content;anchors.fill:parent
    settings:root.presentation.settings;service:root.presentation.service;strings:root.presentation.strings;bar:root.presentation.bar
    pageHeight:root.presentation.pageHeight;overviewActive:root.presentation.selected
    externalFeedback:root.presentation.feedback
    expanded:root.presentation.expanded;hovering:root.presentation.hovering;alertKind:root.presentation.alertKind
    radialBraille:root.presentation.radialBraille
    onCalendarRequested:root.presentation.openPage(2)
    onWeatherRequested:root.presentation.openPage(3)
    onCloseRequested:root.closeRequested()
    onExpandRequested:root.expandRequested()
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
  }
}
