#!/usr/bin/env python3
import os,pathlib,subprocess,tempfile
project=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-motion-') as tmp:
    root=pathlib.Path(tmp)
    for name in ['Commons','Ui']: (root/name).symlink_to(pathlib.Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/Motion.qml').read_text())
    env=os.environ.copy();env['QT_QPA_PLATFORM']='wayland'
    result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=16)
    print(result.stdout)
    if 'ISLAND_MOTION_PASS' not in result.stdout or any(marker in result.stdout for marker in ['ISLAND_MOTION_FAIL','ReferenceError:','TypeError:','FAIL!']): raise SystemExit(1)
