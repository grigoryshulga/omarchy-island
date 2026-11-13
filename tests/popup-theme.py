#!/usr/bin/env python3
"""Check actual popup theme bindings without opening windows or sending input."""
from session import ensure
ensure()
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-popup-theme-') as temporary:
    root = Path(temporary)
    for name in ('Commons', 'Ui'):
        (root / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
    (root / 'Island').symlink_to(project / 'plugin')
    (root / 'shell.qml').write_text((project / 'tests/PopupTheme.qml').read_text())
    result = subprocess.run(['qs', '-p', str(root), '--no-color'],
                            env=dict(os.environ, QT_QPA_PLATFORM='wayland'),
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=8)
    print(result.stdout)
    assert 'POPUP_THEME_PASS' in result.stdout and not any(marker in result.stdout for marker in
        ('POPUP_THEME_FAIL', 'ReferenceError:', 'TypeError:', 'Cannot assign', 'Unable to assign'))
