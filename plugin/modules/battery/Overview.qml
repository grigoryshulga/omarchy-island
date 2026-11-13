import QtQuick
import "../.." as Island
Island.ModuleView {
  id:root
  available:!!backend && backend.present && (presentation.expanded || presentation.hovering)
  function sync(){if(backend) backend.watch(root,visible && presentation.active)}
  onVisibleChanged:sync()
  onBackendChanged:sync()
  Component.onCompleted:sync()
  Component.onDestruction:if(backend) backend.watch(root,false)
  Connections {target:root.presentation;function onActiveChanged(){root.sync()}}
  implicitHeight:content.implicitHeight
  Island.BatteryOverview {
    id:content;objectName:"islandBatteryOverview";width:parent.width
    minimal:root.presentation.size==="minimal"
    power:root.backend;strings:root.presentation.strings
    active:root.presentation.active;externalFeedback:root.presentation.feedback
    onExpandRequested:root.expandRequested()
  }
}
