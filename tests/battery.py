#!/usr/bin/env python3
"""Exercise battery UI and native command protocol without changing system power."""
import os,subprocess,tempfile,json
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-battery-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/Battery.qml').read_text())
    helper=root/'power.py'
    helper.write_text('''import sys,json
from pathlib import Path
state=Path(__file__).with_suffix('.json');log=Path(__file__).with_suffix('.log')
if sys.argv[1]=='list':
 active=state.read_text() if state.exists() else 'balanced'
 for name in ['performance','balanced','power-saver']:print(name+'\\t'+str(int(name==active)))
else:
 with log.open('a') as out:out.write(json.dumps(sys.argv[2:])+'\\n')
 if sys.argv[3]=='power-saver':raise SystemExit(1)
 state.write_text(sys.argv[3])
''')
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',ISLAND_POWER_HELPER=str(helper))
    env.setdefault('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}')
    try:r=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=12)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b'').decode());raise
    print(r.stdout)
    assert 'BATTERY_PASS' in r.stdout and not any(x in r.stdout for x in ['BATTERY_FAIL','ReferenceError:','TypeError:','Binding loop','Cannot assign','Unable to assign','FAIL!']),r.stdout
    assert [json.loads(line) for line in helper.with_suffix('.log').read_text().splitlines()]==[['battery','performance'],['ac','power-saver']]
