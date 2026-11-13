import QtQuick
import "../.." as Island
Island.ModuleView {
  id:root
  available:!!presentation && (presentation.expanded || presentation.hovering) && !!backend
  implicitHeight:presentation.detail ? Math.max(content.implicitHeight,presentation.pageHeight-Island.Design.controlHeight-Island.Design.gap.section) : content.implicitHeight
  navigationHidden:content.section==="settings"
  ownsKeys:content.settingsOwnKeys
  property var observedBackend:null
  readonly property bool observing:visible && !!presentation && presentation.active && content.section===""
  function sync(){
    if(observedBackend && observedBackend!==backend) observedBackend.watch(root,false)
    observedBackend=backend
    if(backend) backend.watch(root,observing)
  }
  onBackendChanged:sync()
  onObservingChanged:sync()
  Component.onCompleted:sync()
  Component.onDestruction:if(observedBackend) observedBackend.watch(root,false)
  function back(){if(content.section) {content.back();return true}return false}
  Island.ControlsView {
    id:content;objectName:"islandControls";anchors.fill:parent
    service:root.presentation.service;strings:root.presentation.strings;bar:root.presentation.bar
    settings:root.presentation.settings;externalFeedback:root.presentation.feedback
    favoritesInteractive:root.presentation.expanded
    favoriteMode:!root.presentation.detail
    onSectionRequested:key=>{root.detailsRequested();Qt.callLater(function(){if(root.presentation.detail) content.openSection(key)})}
    onAllRequested:root.detailsRequested()
    active:root.presentation.active
    controlState:root.backend
    panelCommand:root.backend ? root.backend.panelCommand : []
    execute:function(argv){
      if(root.backend) root.backend.execute(argv)
      else if(root.presentation.service && typeof root.presentation.service.execute==="function") root.presentation.service.execute(argv)
    }
    systemCall:function(target,method,args){
      var owner=root.backend || root.presentation.service
      return owner && typeof owner.systemCall==="function" ? owner.systemCall(target,method,args) : {ran:false}
    }
    onDismissRequested:root.closeRequested()
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
  }
}
