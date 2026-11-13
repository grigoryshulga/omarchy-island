#!/usr/bin/env python3
"""QML → stdin protocol → real storage/parser, with only HTTP replaced."""
from session import ensure
ensure()
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-ics-qml-') as temporary:
    root = Path(temporary)
    for name in ('Commons', 'Ui'):
        (root / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
    (root / 'Island').symlink_to(project / 'plugin')
    bridge = root / 'Bridge';(bridge / 'bin').mkdir(parents=True)
    for name in ('CalendarState.qml', 'CalendarEvents.js', 'Security.js'):
        (bridge / name).write_text((project / 'plugin' / name).read_text())
    (bridge / 'bin/calendar-data').write_text('''import importlib.machinery,importlib.util,json,sys
from pathlib import Path
sys.path.insert(0, %r)
loader=importlib.machinery.SourceFileLoader('data', %r)
spec=importlib.util.spec_from_loader(loader.name,loader);data=importlib.util.module_from_spec(spec);loader.exec_module(data)
request=json.loads(sys.stdin.readline())
raw=Path(%r).read_bytes()
def fake_fetch(url,cache):
    if request.get('refresh'):raise data.CalendarError('network')
    return raw,'version',''
data.fetch=fake_fetch
data.deadline=lambda seconds,operation:operation()
data.run_worker=lambda source,year,refresh:data.worker(dict(source=source,year=year,refresh=refresh))
print(json.dumps(data.operate(request)))
''' % (str(project / 'plugin/bin'), str(project / 'plugin/bin/calendar-data'), str(project / 'tests/fixtures/calendar.ics')))
    (root / 'shell.qml').write_text((project / 'tests/CalendarSubscriptions.qml').read_text())
    result = subprocess.run(['qs', '-p', str(root), '--no-color'], env=dict(os.environ,
        XDG_STATE_HOME=str(root / 'state'), QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software'),
        capture_output=True, text=True, timeout=35)
    output = result.stdout + result.stderr
    print(output)
    assert 'CALENDAR_SUBSCRIPTIONS_PASS' in output and not any(marker in output for marker in
        ('CALENDAR_SUBSCRIPTIONS_FAIL', 'ReferenceError:', 'TypeError:', 'Binding loop', 'Cannot assign', 'Unable to assign', 'FAIL!'))
    assert 'private-token' not in output
