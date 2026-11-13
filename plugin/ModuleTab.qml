import QtQuick
ModuleView {
  id:root
  available:true
  implicitHeight:button.implicitHeight
  TabButton {
    id:button;anchors.fill:parent;objectName:root.presentation.objectName
    label:root.presentation.title;tabActive:root.presentation.selected
    feedback:root.presentation.feedback;fontSize:Design.type.label;radius:Design.controlRadius;focusable:true
    onClicked:root.detailsRequested()
  }
}
