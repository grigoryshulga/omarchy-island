#!/usr/bin/env python3
from session import ensure
ensure()
import os,pathlib,subprocess,tempfile
project=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-overview-') as tmp:
    root=pathlib.Path(tmp)
    for name in ['Commons','Ui']: (root/name).symlink_to(pathlib.Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/Overview.qml').read_text())
    env=os.environ.copy();env['QT_QPA_PLATFORM']='offscreen';env['QT_QUICK_BACKEND']='software'
    result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=19)
    print(result.stdout)
    if 'OVERVIEW_PASS' not in result.stdout or any(marker in result.stdout for marker in ['FAIL!', 'OVERVIEW_FAIL', 'TypeError:', 'ReferenceError:', 'Binding loop', 'Cannot assign', 'Unable to assign']): raise SystemExit(1)
