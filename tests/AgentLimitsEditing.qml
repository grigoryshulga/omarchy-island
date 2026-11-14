import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("Island/i18n") }
  QtObject {
    id: backend
    property var cache: ({providers:[{id:"codex",name:"Codex"},{id:"claude",name:"Claude"}]})
    property var rows: [
      {id:"codex-week",providerId:"codex",name:"Codex",label:"Weekly",remaining:60,checkedAt:Date.now()},
      {id:"claude-week",providerId:"claude",name:"Claude",label:"Weekly",remaining:80,checkedAt:Date.now()}
    ]
    property var pins: []
    property var catalog: [{id:"codex",name:"Codex",enabled:true,secretName:""},
      {id:"claude",name:"Claude",enabled:true,secretName:""},
      {id:"deepseek",name:"DeepSeek",enabled:false,secretName:"DEEPSEEK_API_KEY",region:"global"}]
    property bool busy: false
    property string error: ""
    property double now: Date.now()
    property var moves: []
    function loadCatalog() {}
    function refresh() {}
    function moveProvider(id,before) {
      moves=moves.concat([{id:id,before:before}])
      var providers=cache.providers.slice(), from=providers.findIndex(function(p){return p.id===id})
      var entry=providers.splice(from,1)[0], at=providers.findIndex(function(p){return p.id===before})
      providers.splice(at<0 ? providers.length : at,0,entry)
      cache={providers:providers}
    }
    function change(id,action,secret,region) {
      catalog=catalog.map(function(p){return p.id===id ? Object.assign({},p,{enabled:action!=="disable"}) : p})
    }
  }
  FloatingWindow {
    id: window
    visible: true; implicitWidth: 540; implicitHeight: 700
    color: Island.Design.opaqueCanvas
    Island.AgentLimitsCenter { id: center; width: parent.width; backend: backend; strings: strings }
    TestCase {
      id: test; when: false
      function run() {
        center.configure();wait(40)
        var first=findChild(center,"limitsProvider-codex"),second=findChild(center,"limitsProvider-claude")
        var logo=findChild(first,"agentProviderLogo")
        tryCompare(logo,"status",Image.Ready)
        verify(logo.source.toString().indexOf("currentColor")<0,"logo did not inherit text color")
        // Drag from the provider body, not from an arrow or a separate reorder screen.
        mousePress(first,100,30,Qt.LeftButton)
        mouseMove(first,100,60,40)
        mouseMove(window.contentItem,100,second.y+second.height+center.y+20,80)
        mouseRelease(window.contentItem,100,second.y+second.height+center.y+20,Qt.LeftButton)
        wait(60)
        compare(backend.moves.length,1,"drag did not commit exactly one reorder")
        compare(backend.cache.providers[1].id,"codex")
        verify(findChild(center,"limitsProvider-codex")===first,"reorder recreated the provider")
        var editor=findChild(first,"limitsProviderEdit-codex")
        editor.forceActiveFocus();keyClick(Qt.Key_Up,Qt.ControlModifier);wait(30)
        compare(backend.cache.providers[0].id,"codex")
        verify(editor.activeFocus,"keyboard reorder lost focus")
        editor.clicked();wait(20)
        compare(center.selectedProvider,"codex")
        verify(center.back());wait(20);verify(editor.activeFocus)
        center.showAdd();wait(20)
        verify(findChild(center,"limitsChooseProvider-deepseek").visible)
        findChild(center,"limitsChooseProvider-deepseek").clicked();wait(30)
        compare(center.selectedProvider,"deepseek")
        verify(findChild(center,"agentSecret-deepseek").visible,"add did not open connection settings")
        verify(center.back());wait(20)
        var count=backend.moves.length
        mousePress(first,100,30,Qt.LeftButton);mouseMove(first,100,75,40)
        verify(center.back(),"Escape/Back did not cancel drag")
        mouseRelease(first,100,75,Qt.LeftButton);wait(30)
        compare(backend.moves.length,count,"canceled drag changed provider order")
        verify(center.editing,"cancel drag exited edit mode")
        verify(center.back());verify(!center.editing)
        console.log("LIMITS_EDIT_PASS");Qt.quit()
      }
    }
    Timer { interval: 150; running: true; onTriggered: {try {test.run()} catch(e){console.log("LIMITS_EDIT_FAIL",e,e.stack);Qt.quit()}} }
  }
}
