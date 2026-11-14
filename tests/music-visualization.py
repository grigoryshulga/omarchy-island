#!/usr/bin/env python3
"""Check live settings, shader inputs and audio-consumer lifecycle without a GPU."""
from session import ensure
ensure()
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-music-') as temporary:
    root = Path(temporary)
    for name in ['Commons', 'Ui']:
        (root / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
    (root / 'Island').symlink_to(project / 'plugin')
    (root / 'shell.qml').write_text((project / 'tests/MusicVisualization.qml').read_text())
    result = subprocess.run(['qs', '-p', str(root), '--no-color'], env=os.environ.copy(),
                            capture_output=True, text=True, timeout=10)
    output = result.stdout + result.stderr
    print(output)
    assert 'MUSIC_VISUALIZATION_PASS' in output and not any(marker in output for marker in
        ['MUSIC_VISUALIZATION_FAIL', 'ReferenceError:', 'TypeError:', 'Binding loop',
         'Cannot assign', 'Unable to assign']), output
