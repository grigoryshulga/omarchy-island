import QtQuick

// No production Service, NotificationServer, collector, or desktop connection.
Item {
  required property var registry
  readonly property var modules:registry.backends
  property var actions:[]
  property double now:1794560000000
  property bool doNotDisturb:false
  property var indicators:null
  property string error:""
  function setDoNotDisturb(value){doNotDisturb=value}
  property var latest:null
  property var latestT3:null
  property var t3:null
  function execute(argv){actions=actions.concat([argv])}
  function openUrl(url){execute(["xdg-open",url])}
  function systemCall(target,method,args){actions=actions.concat([{target:target,method:method,args:args}]);return {ran:true}}
}
