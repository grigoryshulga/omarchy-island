import QtQuick
import Quickshell
import qs.Commons
import "Services" as Services
ShellRoot {
  id: root
  property var config: ({bar:{layout:{center:[{id:"omarchy.clock",format:"dddd HH:mm"}],left:[],right:[]}},plugins:[]})
  Services.PluginRegistry {
    id: registry
    pluginsDir: Qt.resolvedUrl("temporary-plugins").toString().replace(/^file:\/\//,"")
    shellConfigProvider: function() { return root.config }
    shellConfigMutator: function(mutator) { var next=Util.cloneJson(root.config); mutator(next); root.config=next }
  }
  function check(value,message) { if(!value) throw new Error(message) }
  Timer {
    interval: 150; running: true
    onTriggered: {
      try {
        registry.parseScanOutput("===firstparty::/clock===\n"+JSON.stringify({schemaVersion:1,id:"omarchy.clock",name:"Clock",version:"1",kinds:["bar-widget"],entryPoints:{barWidget:"Clock.qml"}})+"\n=== EOM ===\n"
          +"===firstparty::/notifications===\n"+JSON.stringify({schemaVersion:1,id:"omarchy.notifications",name:"Notifications",version:"1",kinds:["service"],entryPoints:{service:"Service.qml"}})+"\n=== EOM ===\n"
          +"===thirdparty::/island===\n"+JSON.stringify(ROOT_MANIFEST)+"\n=== EOM ===\n")
        check(registry.setEnabled("omarchy.notifications",false),"disable notifications")
        check(registry.setEnabled("gshulga.island",true),"enable island")
        check(root.config.bar.layout.center.length===1,"duplicated clock")
        check(root.config.bar.layout.center[0].id==="gshulga.island","clock not replaced")
        check(root.config.bar.layout.center[0].format==="dddd HH:mm","format not preserved")
        check(!registry.isEnabled("omarchy.notifications"),"conflicting notification service")
        check(registry.entryPointUrl(registry.installedPlugins["gshulga.island"],"barWidget").endsWith("/plugin/BarWidget.qml"),"entry point path")
        check(registry.setEnabled("gshulga.island",false),"disable island")
        check(root.config.bar.layout.center[0].id==="omarchy.clock","clock not restored")
        check(root.config.bar.layout.center[0].format==="dddd HH:mm","restored format changed")
        check(registry.setEnabled("omarchy.notifications",true),"restore notifications")
        check(registry.isEnabled("omarchy.notifications"),"notifications not restored")
        console.log("ISLAND_NATIVE_REGISTRY_PASS")
      } catch(error) { console.log("ISLAND_NATIVE_REGISTRY_FAIL",String(error)) }
      Qt.quit()
    }
  }
}
