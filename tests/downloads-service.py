#!/usr/bin/env python3
from session import ensure
ensure()
import os
import json
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-downloads-qml-') as tmp:
    root = Path(tmp)
    for name in ['Commons', 'Ui']:
        (root / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
    (root / 'Island').symlink_to(project / 'plugin')
    (root / 'shell.qml').write_text((project / 'tests/Downloads.qml').read_text())
    home = root / 'home'; home.mkdir()
    binary = root / 'bin'; binary.mkdir()
    opener = binary / 'xdg-open'
    opener.write_text('#!/usr/bin/env python3\nimport json,os,sys\nopen(os.environ["ISLAND_OPEN_LOG"],"w").write(json.dumps(sys.argv[1:]))\n')
    opener.chmod(0o755)
    (home / ".bash_profile").write_text("export PATH=" + str(binary) + ":$PATH\n")
    env = dict(os.environ, PATH=str(binary)+os.pathsep+os.environ['PATH'], ISLAND_OPEN_LOG=str(root / 'opened.json'), HOME=str(home), QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
    try:
        result = subprocess.run(['dbus-run-session', '--', 'qs', '-p', str(root), '--no-color'], env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=25)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b"").decode(errors="replace"), flush=True)
        raise
    print(result.stdout)
    assert 'DOWNLOADS_SERVICE_PASS' in result.stdout and not any(s in result.stdout for s in ['FAIL!', 'ReferenceError:', 'TypeError:'])

    assert json.loads((root / 'opened.json').read_text()) == [str(home / 'downloads/nested')]
    state = json.loads((home / '.local/state/omarchy/island/downloads.json').read_text())
    assert len(state['downloads']) == 1
    assert state['downloads'][0]['downloadPath'].endswith('/file $ & <name>.zip')
    notifications = json.loads((home / '.local/state/omarchy/island/notifications.json').read_text())
    assert 'downloads' not in notifications
