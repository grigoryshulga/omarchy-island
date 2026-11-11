import QtQuick
import QtTest
import Quickshell
import "Island" as Island

ShellRoot {
  Island.DictationState {id:backend;runtimeDir:Quickshell.env("ISLAND_DICTATION_RUNTIME")}
  TestCase {
    id:test
    when:false
    function check(ok,message) {if(!ok) {console.log("DICTATION_STATE_FAIL",message);Qt.quit();throw new Error(message)}}
    function test_clock() {
      tryCompare(backend,"mode","recording")
      wait(120)
      check(backend.startedAt> Date.now()-2000,"recording has no start time: "+backend.startedAt+", elapsed="+backend.elapsed)
      check(backend.elapsed>=0 && backend.elapsed<2,"counter started at epoch minutes")
      var start=backend.startedAt
      backend.mode="recording"
      compare(backend.startedAt,start)
      // Deterministically simulate a recording already 65 seconds long.
      backend.startedAt=Date.now()-65000
      wait(120)
      check(backend.elapsed===65,"counter did not tick from recording start")
      backend.mode="transcribing"
      var frozen=backend.elapsed
      wait(120)
      check(backend.elapsed===frozen,"transcription advanced the recording counter")
      backend.mode="recording"
      wait(120)
      check(backend.startedAt>Date.now()-1000 && backend.elapsed===0,"new recording did not reset counter")
      backend.mode="idle"
      console.log("DICTATION_STATE_PASS")
      Qt.quit()
    }
  }
  Timer {interval:100;running:true;onTriggered:test.test_clock()}
  Timer {interval:6000;running:true;onTriggered:{console.log("DICTATION_STATE_FAIL timeout");Qt.quit()}}
}
