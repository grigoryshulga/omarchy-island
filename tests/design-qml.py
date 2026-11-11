#!/usr/bin/env python3
"""Verify real theme bindings and editor state in an isolated QML process."""
import os
from pathlib import Path
import subprocess
import tempfile

project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-design-test-') as temporary:
    root=Path(temporary)
    for name in ('Commons','Ui'):(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/Design.qml').read_text())
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=10)
    print(result.stdout)
    assert 'DESIGN_PASS' in result.stdout and not any(x in result.stdout for x in
        ('DESIGN_FAIL','ReferenceError:','TypeError:','Binding loop','Cannot assign','Unable to assign','FAIL!')),result.stdout
