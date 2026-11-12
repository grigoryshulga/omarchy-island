#!/usr/bin/env python3
"""Real calendar and reminder service against an isolated native CLI substitute."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-calendar-') as directory:
    root=Path(directory)
    for name in ('Commons','Ui'):(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/Calendar.qml').read_text())
    binary=root/'bin';binary.mkdir()
    script=binary/'omarchy-reminder'
    script.write_text('''#!/usr/bin/env python3
import json,os,pathlib,sys,time
root=pathlib.Path(os.environ['REMINDER_TEST_DIR']);state=root/'state.json';args=sys.argv[1:]
rows=json.loads(state.read_text()) if state.exists() else []
if args==['show','--json']:print(json.dumps({'reminders':rows}));sys.exit()
with (root/'calls.jsonl').open('a') as f:f.write(json.dumps(args)+'\\n')
if args==['clear']:rows=[]
else:rows.append({'unit':'omarchy-reminder-5m-test','at':int(time.time())+int(args[0])*60,'label':args[1] if len(args)>1 else 'Reminder'})
state.write_text(json.dumps(rows))
''')
    script.chmod(0o755)
    result=subprocess.run(['qs','-p',str(root),'--no-color'],env=dict(os.environ,
        PATH=str(binary)+os.pathsep+os.environ['PATH'],REMINDER_TEST_DIR=str(root),
        QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software'),capture_output=True,text=True,timeout=14)
    output=result.stdout+result.stderr
    print(output)
    assert 'CALENDAR_REMINDERS_PASS' in output and not any(marker in output for marker in
        ('CALENDAR_REMINDERS_FAIL','ReferenceError:','TypeError:','Binding loop','Cannot assign','Unable to assign'))
    calls=[json.loads(line) for line in (root/'calls.jsonl').read_text().splitlines()]
    assert calls==[['5','literal $(touch /tmp/island-never); <b>'],['clear']],calls
