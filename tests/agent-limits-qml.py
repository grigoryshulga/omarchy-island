#!/usr/bin/env python3
"""Real QML state/collector contract and keyboard UI with isolated, aggregate-only fixtures."""
from session import ensure
ensure()
import os, subprocess, tempfile
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-limits-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/AgentLimits.qml').read_text())
    helper=root/'collector'
    helper.write_text('''#!/usr/bin/env python3
import sys,json,os
from pathlib import Path
with open(os.environ['ISLAND_LIMITS_LOG'],'a') as out:out.write(json.dumps(sys.argv[1:])+'\\n')
providers=[{'id':'codex','name':'Codex','enabled':True,'secretName':'','region':'global'},{'id':'claude','name':'Claude','enabled':True,'secretName':'','region':'global'}]
if sys.argv[1] in ('providers','configure'):
 if sys.argv[1]=='configure':providers[0]['enabled']=sys.argv[3]!='disable'
 print(json.dumps({'providers':providers}))
else:
 data={'schemaVersion':1,'state':'ready','syncedAt':1,'providers':[{'id':'codex','name':'Codex','limits':[{'label':'Weekly','percent':92},{'label':'Session','percent':10}],'days':[{'date':'2026-11-12','tokens':100,'cost':0.2,'priced':True,'requests':2}],'models':[{'name':'example','tokens':100,'priced':True,'cost':0.2}]}]}
 Path(os.environ['ISLAND_LIMITS_CACHE']).write_text(json.dumps(data))
''')
    helper.chmod(0o700)
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',ISLAND_LIMITS_HELPER=str(helper),ISLAND_LIMITS_CACHE=str(root/'cache.json'),ISLAND_LIMITS_LOG=str(root/'calls.jsonl'))
    result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
    print(result.stdout)
    assert 'LIMITS_PASS' in result.stdout and not any(x in result.stdout for x in ['LIMITS_FAIL','ReferenceError:','TypeError:','Binding loop','Cannot assign','Unable to assign','FAIL!'])
    assert (root/'calls.jsonl').exists()

from module_harness import ModuleHarness
with ModuleHarness() as harness:
    harness.run(project / 'tests/AgentLimitsEditing.qml', 'LIMITS_EDIT_PASS')
