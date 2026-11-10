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
    implicitWidth: 320; implicitHeight: 160
    Island.ArtworkBackground { id: artwork; anchors.fill: parent; service: service }
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
      console.log("ARTWORK_FRAMES_PASS")
      Qt.quit()
    }
  }
  Timer {interval:400;running:true;onTriggered:test.test_frames()}
}
