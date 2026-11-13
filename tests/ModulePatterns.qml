import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  QtObject {
    id:backend
    property bool busy:false
    property var catalog:[{id:"zai",name:"Z.AI",enabled:true,secretName:"ZAI_API_KEY",region:"global"}]
    property var actions:[]
    function change(id,action,secret,region){actions=actions.concat([{id:id,action:action,secret:secret,region:region}])}
  }
  FloatingWindow {
    visible:true;implicitWidth:440;implicitHeight:700
    color:Island.Design.opaqueCanvas
    Island.AgentLimitsProviders {id:providers;width:400;x:20;y:20;strings:strings;backend:backend}
    TestCase {
      id:test;when:false
      function checkModule() {
        findChild(providers,"agentProviderConnect-zai").clicked();wait(30)
        var input=findChild(providers,"agentSecret-zai"),field=findChild(providers,"agentSecretField-zai"),save=findChild(providers,"agentProviderSave-zai")
        verify(input.visible && save.enabled)
        input.forceActiveFocus();input.selectAll();keyClick(Qt.Key_Space)
        verify(!!field.error && input.invalid && !save.enabled)
        keyClick(Qt.Key_Return);compare(backend.actions.length,0)
        var draft=input.text
        Commons.Style.cornerRadius=0;Commons.Style.fontBaseSize=15;wait(30)
        compare(input.text,draft);verify(input.activeFocus)
        compare(input.background.radius,0)
        if(Quickshell.env("ISLAND_PATTERNS_CAPTURE")) {
          input.text="ZAI API KEY";input.textEdited()
          providers.grabToImage(function(image){image.saveToFile(Quickshell.env("ISLAND_PATTERNS_CAPTURE")+"/agent-limits-form.png")});wait(120)
        }
        input.text="ZAI_API_KEY";input.textEdited()
        verify(!field.error && !input.invalid && save.enabled)
        backend.busy=true;verify(!input.enabled && !save.enabled)
        backend.busy=false
        save.forceActiveFocus();keyClick(Qt.Key_Return)
        compare(backend.actions.length,1);compare(backend.actions[0].secret,"ZAI_API_KEY")
        compare(providers.editingId,"")
        console.log("MODULE_PATTERNS_PASS");Qt.quit()
      }
    }
    Timer {interval:150;running:true;onTriggered:{try{test.checkModule()}catch(error){console.log("MODULES_FAIL",error.message,error.stack);Qt.quit()}}}
  }
}
