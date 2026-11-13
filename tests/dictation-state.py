#!/usr/bin/env python3
from session import ensure
ensure()
import os, subprocess, tempfile
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-dictation-state-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:
        (root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/DictationState.qml').read_text())
    (root/'voxtype').mkdir()
    (root/'voxtype/state').write_text('recording\n')
    (root/'bin').mkdir()
    bridge=root/'bin/voxtype-audio-bridge'
    bridge.write_text('#!/bin/sh\nexit 0\n')
    bridge.chmod(0o755)
    env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
             ISLAND_DICTATION_RUNTIME=str(root), PATH=str(root/'bin')+':'+os.environ['PATH'])
    result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,
                          stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
    print(result.stdout)
    assert 'DICTATION_STATE_PASS' in result.stdout and not any(s in result.stdout for s in
        ['DICTATION_STATE_FAIL','ReferenceError:','TypeError:','Binding loop']),result.stdout
