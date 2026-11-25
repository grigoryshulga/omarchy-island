import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Island" as Island

ShellRoot {
  Island.DictationState {id:backend;runtimeDir:Quickshell.env("ISLAND_DICTATION_RUNTIME")}
  FileView {id:stateFile;path:backend.runtimeDir+"/voxtype/state"}
  FileView {id:indicator;path:backend.runtimeDir+"/indicator.json";printErrors:false}
  FileView {id:hexStatus;path:backend.runtimeDir+"/hex-status.json";printErrors:false}
  TestCase {
    id:test
    when:false
    function test_clock() {
      tryCompare(backend,"mode","recording")
      compare(backend.source,"voxtype")
      tryVerify(function(){return backend.history[backend.history.length-1]===0.25})
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
      var before=backend.sessionId
      indicator.setText('{"phase":"recording","peak":0.65}')
      wait(250)
      compare(backend.source,"voxtype")
      compare(backend.sessionId,before)
      compare(backend.history[backend.history.length-1],0.25)
      stateFile.setText("idle\n")
      tryCompare(backend,"source","superwhisper")
      compare(backend.mode,"recording")
      compare(backend.elapsed,0)
      compare(backend.sessionId,before+1)
      tryVerify(function(){return backend.history[backend.history.length-1]===0.65})
      indicator.setText('{"phase":"recording","peak":0,"visible":false}')
      tryVerify(function(){return backend.superwhisperInputMeter && backend.history[47]===0})
      indicator.setText('{"phase":"recording","peak":0,"visible":true}')
      tryCompare(backend,"superwhisperInputMeter",false)
      indicator.setText('{"phase":"recording","wave":[10,10,10,10,10,10]}')
      tryVerify(function(){return backend.history[backend.history.length-1]===0.5})
      indicator.setText('{"phase":"cleaning"}')
      tryCompare(backend,"mode","transcribing")
      compare(backend.superwhisperInputMeter,false)
      indicator.setText('{"phase":"delivering"}')
      wait(100)
      compare(backend.mode,"transcribing")
      indicator.setText('{"phase":"offline"}')
      tryCompare(backend,"mode","idle")
      verify(!backend.showing,"idle state left dictation visible")
      indicator.setText('{"phase":"warming"}')
      wait(250)
      compare(backend.mode,"idle")
      indicator.setText('{"phase":"recording","peak":0.1}')
      tryCompare(backend,"mode","recording")
      backend.active=false
      tryCompare(backend,"mode","idle")
      backend.active=true
      tryCompare(backend,"mode","recording")
      indicator.setText('{"phase":"idle"}')
      tryCompare(backend,"mode","idle")
      hexStatus.setText('{"capture":{"state":"recording","recording":"dictation"},"meeting":{"state":"idle"}}')
      tryCompare(backend,"mode","recording")
      compare(backend.source,"hex")
      var hexSession=backend.sessionId
      stateFile.setText("recording\n")
      tryCompare(backend,"voxtypeMode","recording")
      compare(backend.source,"hex")
      hexStatus.setText('{"capture":{"state":"transcribing"}}')
      tryCompare(backend,"mode","transcribing")
      compare(backend.sessionId,hexSession)
      stateFile.setText("idle\n")
      tryCompare(backend,"voxtypeMode","idle")
      hexStatus.setText('{"capture":{"state":"idle"},"meeting":{"state":"recording"}}')
      tryCompare(backend,"mode","idle")
      hexStatus.setText('{"capture":{"state":"recording"}}')
      tryCompare(backend,"source","hex")
      hexStatus.setText('invalid')
      tryCompare(backend,"mode","idle")
      console.log("DICTATION_STATE_PASS")
      Qt.quit()
    }
  }
  Timer {interval:100;running:true;onTriggered:{try {test.test_clock()} catch(error) {console.log("DICTATION_STATE_FAIL",error,error.stack);Qt.quit()}}}
  Timer {interval:12000;running:true;onTriggered:{console.log("DICTATION_STATE_FAIL timeout");Qt.quit()}}
}
