import QtQuick
import "../.." as Island
Island.ModuleView {
  id:root
  available:true
  implicitHeight:chip.implicitHeight
  Island.WeatherChip {
    id:chip;anchors.fill:parent;objectName:root.presentation.objectName
    weather:root.backend;strings:root.presentation.strings;showLabel:true
    feedback:root.presentation.feedback;selected:root.presentation.selected
    onClicked:root.detailsRequested()
  }
}
