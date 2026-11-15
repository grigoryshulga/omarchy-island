#!/usr/bin/env python3
from qml_result import assert_qml_pass
from session import ensure
ensure()
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
    assert_qml_pass(result, 'ISLAND_MOTION_PASS')
