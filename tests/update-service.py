#!/usr/bin/env python3
"""Check the native update probe's exit-code contract without checking packages."""
from session import ensure
ensure()
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-update-') as temporary:
    root = Path(temporary)
    for name in ['Commons', 'Ui']:
        (root / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
    (root / 'Island').symlink_to(project / 'plugin')
    commands = root / 'bin'
    commands.mkdir()
    probe = commands / 'omarchy-update-available'
    probe.write_text('#!/bin/sh\nexit "$(cat "$ISLAND_UPDATE_RESULT")"\n')
    probe.chmod(0o755)
    result_file = root / 'result'
    result_file.write_text('0')
    (root / 'shell.qml').write_text('''import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Island" as Island
ShellRoot {
  Island.IndicatorState {id:state;layouts.observeSystem:false}
  FileView {id:result;path:Quickshell.env("ISLAND_UPDATE_RESULT")}
  TestCase {
    id:test
    when:false
    function run() {
      state.refreshUpdate()
      tryCompare(state,"updateAvailable",true,2000)
      result.setText("2");wait(50);state.refreshUpdate();wait(200)
      verify(state.updateAvailable,"probe failure cleared known update")
      state.clearUpdate();verify(!state.updateAvailable)
      result.setText("0");wait(50);state.refreshUpdate()
      tryCompare(state,"updateAvailable",true,2000)
      result.setText("1");wait(50);state.refreshUpdate()
      tryCompare(state,"updateAvailable",false,2000)
      console.log("UPDATE_SERVICE_PASS");Qt.quit()
    }
  }
  Timer {interval:150;running:true;onTriggered:test.run()}
}
''')
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
               PATH=str(commands) + os.pathsep + os.environ['PATH'],
               ISLAND_UPDATE_RESULT=str(result_file))
    env.setdefault('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    try:
        run = subprocess.run(['qs', '-p', str(root), '--no-color'], env=env,
                             capture_output=True, text=True, timeout=8)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b" ").decode())
        raise
    output = run.stdout + run.stderr
    print(output)
    assert 'UPDATE_SERVICE_PASS' in output and not any(message in output for message in
           ['FAIL!', 'ReferenceError:', 'TypeError:', 'Unable to assign']), output
