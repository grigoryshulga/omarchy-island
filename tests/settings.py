#!/usr/bin/env python3
"""Wayland: check settings against an isolated fake shell; no session changes."""
import os
import subprocess
import tempfile
from pathlib import Path

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-settings-') as temporary:
    root = Path(temporary)
    for name in ['Commons', 'Ui']:
        (root / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
    (root / 'Island').symlink_to(project / 'plugin')
    (root / 'shell.qml').write_text((project / 'tests/Settings.qml').read_text())
    env = dict(os.environ, QT_QPA_PLATFORM='wayland', QT_QUICK_BACKEND='software')
    result = subprocess.run(['qs', '-p', str(root), '--no-color'], env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
    print(result.stdout)
    assert 'SETTINGS_PASS' in result.stdout and not any(marker in result.stdout for marker in
        ['SETTINGS_FAIL', 'ReferenceError:', 'TypeError:', 'Binding loop', 'Cannot assign', 'Unable to assign']), result.stdout
