import QtQuick

Loader {
  id:root
  property string viewSource:""
  property var backend:null
  property var presentation:null
  readonly property bool available:!!item && item.available && (!backend || !("allowed" in backend) || backend.allowed)
  readonly property string tooltip:item ? item.tooltip : ""
  signal closeRequested()
  signal expandRequested()
  signal detailsRequested()
  signal settingRequested(string key,var value)
  function loadView() {
    if(viewSource) setSource(Qt.resolvedUrl(viewSource), {
      backend:Qt.binding(function(){return root.backend}),
      presentation:Qt.binding(function(){return root.presentation})
    })
    else source=""
  }
  onViewSourceChanged:loadView()
  Connections {
    target:root.item
    function onCloseRequested(){root.closeRequested()}
    function onExpandRequested(){root.expandRequested()}
    function onDetailsRequested(){root.detailsRequested()}
    function onSettingRequested(key,value){root.settingRequested(key,value)}
  }
}
