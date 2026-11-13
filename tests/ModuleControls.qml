import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  Island.ModuleRegistry {id:registry;definitions:[]}
  ModuleHost {id:host;registry:registry}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  Island.ControlsState {
    id:backend
    adapter:null;sink:null;nodes:[];networking:({backend:-1,wifiEnabled:false})
    execute:function(argv){host.execute(argv)}
    systemCall:function(target,method,args){return host.systemCall(target,method,args)}
    panelCommand:[]
    outputCommand:["python3",Quickshell.env("ISLAND_CONTROLS_HELPER"),"output"]
    tailscaleCommand:["python3",Quickshell.env("ISLAND_CONTROLS_HELPER"),"tailscale"]
  }
  FileView {id:log;path:Quickshell.env("ISLAND_MODULE_STORAGE")+"/controls.jsonl";watchChanges:true;printErrors:false;onFileChanged:reload()}
  FloatingWindow {
    visible:true;implicitWidth:500;implicitHeight:600
    Island.ModuleSlot {
      id:slot;anchors.fill:parent
      viewSource:"modules/controls/Page.qml"
      presentation:QtObject {
        readonly property var service:host
        readonly property var strings:strings
        readonly property var bar:null
        readonly property var settings:({})
        readonly property var feedback:null
        readonly property bool active:true
      }
    }
  }
  TestCase {
    id:test;when:false
    function events(kind){return log.text().split("\n").filter(function(line){return line && JSON.parse(line).event===kind}).length}
    function run(){
      wait(150)
      compare(host.actions.length,0,"Loading UI launched an external action")
      compare(events("start"),0,"Loading UI activated the real backend")
      var content=findChild(slot,"islandControls")
      content.toggleMode("recording")
      compare(host.actions.length,1);compare(host.actions[0][0],"omarchy-menu")
      content.toggleMode("nightLight")
      compare(host.actions[1].target,"nightlight")
      content.launchExternalPanel("invalid","")
      compare(host.actions.length,2,"Invalid external action was executed")
      content.openSection("audio");verify(content.error!=="")
      content.back()
      slot.backend=backend
      tryVerify(function(){return events("start")===2},2500)
      compare(backend.consumers.length,1)
      var secondScreen={}
      backend.watch(secondScreen,true);backend.watch(secondScreen,true)
      compare(backend.consumers.length,2)
      slot.visible=false
      verify(backend.active,"Hiding one monitor stopped another monitor")
      backend.allowed=false
      tryVerify(function(){return events("stop")===2},2500)
      backend.allowed=true
      tryVerify(function(){return events("start")===4},2500)
      backend.watch(secondScreen,false)
      tryVerify(function(){return events("stop")===4},2500)
      verify(!backend.active)
      compare(events("start"),4,"Re-enable duplicated collectors")
      backend.watch(secondScreen,true)
      tryVerify(function(){return events("start")===6},2500)
      backend.tailscaleKnown=true;backend.tailscaleEnabled=false
      backend.toggle("tailscale")
      tryVerify(function(){return events("start")===7},2500)
      backend.watch(secondScreen,false)
      tryVerify(function(){return events("stop")===6},2500)
      wait(50);compare(events("stop"),6,"Closing the page cancelled a requested action")
      backend.allowed=false
      tryVerify(function(){return events("stop")===7},2500)
      console.log("MODULE_CONTROLS_PASS");Qt.quit()
    }
  }
  Timer {interval:100;running:true;onTriggered:{try{test.run()}catch(error){console.log("MODULES_FAIL",error.stack);Qt.quit()}}}
}
