import QtQuick
import "../.." as Island
Island.ModuleView {
  id:root
  objectName:"sampleView"
  available:!!backend && backend.allowed
  implicitHeight:100
  property string draft:""
  Island.FeedbackButton {
    objectName:"sampleDetails"
    text:"Sample"
    focusable:true
    onClicked:root.detailsRequested()
  }
}
