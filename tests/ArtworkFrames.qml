import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  QtObject {
    id: service
    property bool hasMedia: true
    property bool playing: true
    property real visualPhase: 0
    property real audioLevel: 0
    property real audioBass: 0
    property real audioTreble: 0
    property var player: null
  }
  FloatingWindow {
    visible: true
    color: "black"
    implicitWidth: 320; implicitHeight: 200
    Island.ArtworkBackground { id: artwork; anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;height:160; service: service }
    Island.BrailleGauge {id:gauge;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:24;value:0.2}
  }
  TestCase {
    id: test
    when: false
    function check(ok,message) {
      if(!ok) {console.log("ARTWORK_FRAMES_FAIL:",message);Qt.quit();throw new Error(message)}
    }
    function test_frames() {
      Commons.Style.reduceMotion=false
      wait(120)
      var first=grabImage(artwork)
      check(first.width>0 && first.height>0,"no GPU frame")
      service.visualPhase=0.75
      wait(120)
      var second=grabImage(artwork)
      var ambientChanged=!first.equals(second)
      service.audioLevel=0.4;service.visualPhase=0
      wait(100)
      var reactive=grabImage(artwork)
      service.visualPhase=0.75
      wait(100)
      check(!reactive.equals(grabImage(artwork)),"shared phase or GPU layer does not update")
      check(ambientChanged,"artwork is frozen when audio levels are zero")
      Commons.Style.reduceMotion=true
      wait(80)
      var still=grabImage(artwork)
      service.visualPhase=1.5
      wait(80)
      check(still.equals(grabImage(artwork)),"artwork ignores reduced motion")
      var field=findChild(gauge,"brailleGaugeField")
      var thin=grabImage(gauge)
      gauge.value=0.9;wait(80)
      var thick=grabImage(gauge),a=0,b=0
      // Both values fill this region: increased ink here proves that dots
      // become thicker, rather than merely lighting more columns.
      for(var y=Math.ceil(field.y);y<field.y+field.height;y++) for(var x=Math.ceil(field.x);x<field.x+field.width*0.15;x++) {a+=thin.red(x,y)+thin.green(x,y)+thin.blue(x,y);b+=thick.red(x,y)+thick.green(x,y)+thick.blue(x,y)}
      check(b>a*1.2,"gauge dots did not become thicker: "+a+" -> "+b+", amount="+field.amount)
      console.log("GAUGE_FRAMES_PASS")
      console.log("ARTWORK_FRAMES_PASS")
      Qt.quit()
    }
  }
  Timer {interval:400;running:true;onTriggered:test.test_frames()}
}
