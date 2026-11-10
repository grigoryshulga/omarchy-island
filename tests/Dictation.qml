import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  QtObject {
    id:fake
    property bool showing:false
    property bool recording:true
    property string screenName:""
    property int elapsed:65
    property var history:Array(48).fill(0.2)
  }
  QtObject {id:bar;property string position:"top";property int barSize:40}
  FloatingWindow {
    visible:true;implicitWidth:640;implicitHeight:60
    Item {id:anchor;anchors.centerIn:parent;width:360;height:30}
  }
  Loader {
    id:loader
    property bool retaining:false
    function release() {if(item && !item.open && item.shown===0) retaining=false}
    active:fake.showing || retaining
    onLoaded:retaining=true
    Component.onCompleted:setSource(Qt.resolvedUrl("Island/DictationOsd.qml"),{dictation:fake,anchorItem:anchor,bar:bar})
  }
  Connections {
    target:loader.item
    function onShownChanged() {Qt.callLater(loader.release)}
    function onOpenChanged() {Qt.callLater(loader.release)}
  }
  Island.DictationState {id:backend;active:false;runtimeDir:"/tmp/island-dictation-absent"}
  TestCase {
    id:test
    name:"Dictation"
    when:false
    function test_flow() {
      compare(loader.item,null)
      fake.showing=true
      tryCompare(loader,"status",Loader.Ready)
      var hud=loader.item
      tryCompare(hud,"shown",1)
      var card=findChild(hud,"islandDictationOsd"),surface=findChild(hud,"islandDictationSurface")
      verify(card!==null)
      compare(surface.WlrLayershell.keyboardFocus,WlrKeyboardFocus.None)
      compare(card.y,bar.barSize+Commons.Style.gapsOut)
      compare(card.x,Math.round(hud.anchorPosition.x+anchor.width/2-card.width/2))
      anchor.anchors.horizontalCenterOffset=70
      wait(50)
      compare(card.x,Math.round(hud.anchorPosition.x+anchor.width/2-card.width/2))
      compare(backend.mode,"idle")
      fake.recording=false
      wait(400)
      var field=findChild(hud,"islandDictationField")
      compare(field.processing,true)
      tryCompare(field,"morph",1)
      fake.showing=false
      tryCompare(loader,"item",null)
      fake.showing=true
      tryCompare(loader,"status",Loader.Ready)
      hud=loader.item
      field=findChild(hud,"islandDictationField")
      Commons.Style.reduceMotion=true
      fake.recording=true
      tryCompare(field,"morph",0)
      fake.showing=false
      tryCompare(loader,"item",null)
      console.log("DICTATION_PASS")
      Qt.quit()
    }
  }
  Timer {interval:100;running:true;onTriggered:test.test_flow()}
  Timer {interval:7000;running:true;onTriggered:{console.log("DICTATION_FAIL timeout");Qt.quit()}}
}
