import QtQuick
import "../.." as Island
Island.ModulePage {
  id:root
  available:true
  stableHeight:0
  implicitHeight:content.implicitHeight
  toastIcon:content.toastIcon
  interactionHovered:content.musicHovered
  function back(){return content.back()}
  Island.IslandContent {
    id:content;anchors.fill:parent
    service:root.presentation.service;strings:root.presentation.strings;bar:root.presentation.bar
    pageHeight:root.presentation.pageHeight;overviewActive:root.presentation.selected
    externalFeedback:root.presentation.feedback
    expanded:root.presentation.expanded;hovering:root.presentation.hovering;alertKind:root.presentation.alertKind
    radialBraille:root.presentation.radialBraille
    onCloseRequested:root.closeRequested()
    onExpandRequested:root.expandRequested()
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
  }
}
