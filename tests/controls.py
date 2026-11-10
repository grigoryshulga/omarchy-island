#!/usr/bin/env python3
"""Exercise inline native panels without changing radios, devices or connections."""
import os,subprocess,tempfile
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-controls-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/Controls.qml').read_text())
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    env.setdefault('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}')
    try:result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b" ").decode());raise
    print(result.stdout)
    assert 'CONTROLS_PASS' in result.stdout and not any(x in result.stdout for x in ['CONTROLS_FAIL','ReferenceError:','TypeError:','Binding loop','Cannot assign','Unable to assign']),result.stdout
