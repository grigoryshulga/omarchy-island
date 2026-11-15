import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Island" as Island

ShellRoot {
  Island.DictationState {id:backend;runtimeDir:Quickshell.env("ISLAND_DICTATION_RUNTIME")}
  FileView {id:stateFile;path:backend.runtimeDir+"/voxtype/state"}
  TestCase {
    id:test
    when:false
    function test_clock() {
      tryCompare(backend,"mode","recording")
      tryVerify(function(){return backend.elapsed>=1},2500)
      verify(backend.elapsed<10,"counter started at epoch minutes")
      var elapsed=backend.elapsed
      stateFile.setText("recording\n")
      wait(150)
      verify(backend.elapsed>=elapsed,"repeated recording status reset the counter")
      stateFile.setText("transcribing\n")
      tryCompare(backend,"mode","transcribing")
      var frozen=backend.elapsed
      wait(1200)
      compare(backend.elapsed,frozen,"transcription advanced the recording counter")
      stateFile.setText("recording\n")
      tryCompare(backend,"mode","recording")
      compare(backend.elapsed,0,"new recording did not reset the counter")
      tryVerify(function(){return backend.elapsed>=1},2500)
      stateFile.setText("idle\n")
      tryCompare(backend,"mode","idle")
      verify(!backend.showing,"idle state left dictation visible")
      console.log("DICTATION_STATE_PASS")
      Qt.quit()
    }
  }
  Timer {interval:100;running:true;onTriggered:{try {test.test_clock()} catch(error) {console.log("DICTATION_STATE_FAIL",error,error.stack);Qt.quit()}}}
  Timer {interval:8000;running:true;onTriggered:{console.log("DICTATION_STATE_FAIL timeout");Qt.quit()}}
}
