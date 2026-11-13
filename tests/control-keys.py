#!/usr/bin/env python3
"""Verify display reorder key dispatch without changing any real displays."""
from session import ensure
ensure()
import os
from pathlib import Path
import subprocess
import shutil
import tempfile

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-control-keys-') as directory:
    root = Path(directory)
    (root / 'Controls').mkdir()
    shutil.copyfile(project / 'plugin/controls/ControlKeyCatcher.qml', root / 'Controls/ControlKeyCatcher.qml')
    (root / 'shell.qml').write_text((project / 'tests/ControlKeys.qml').read_text())
    result = subprocess.run(
        ['qs', '-p', str(root), '--no-color'],
        env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software'),
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=10)
    print(result.stdout)
    assert result.returncode == 0 and 'CONTROL_KEYS_PASS' in result.stdout
    assert not any(value in result.stdout for value in ['FAIL!', 'ReferenceError:', 'TypeError:', 'Cannot assign'])
