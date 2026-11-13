#!/usr/bin/env python3
"""Send real window key events through the four pages and native controls."""
from session import ensure
ensure()
import os,subprocess,tempfile
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-keyboard-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    source = (project/'tests/Keyboard.qml').read_text()
    if os.environ.get('QT_QPA_PLATFORM') == 'offscreen':
        source = source.replace('  PanelWindow {', '  FloatingWindow {')
        source = '\n'.join(line for line in source.splitlines()
                           if not any(value in line for value in ['WlrLayershell.', 'exclusionMode:', 'anchors {top:true;left:true}']))
    (root/'shell.qml').write_text(source)
    env=dict(os.environ,QT_QPA_PLATFORM=os.environ.get('QT_QPA_PLATFORM','wayland'),QT_QUICK_BACKEND='software')
    try:r=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=13)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b'').decode());raise
    print(r.stdout)
    assert 'KEYBOARD_PASS' in r.stdout and not any(x in r.stdout for x in ['KEYBOARD_FAIL','ReferenceError:','TypeError:','Binding loop','Cannot assign','Unable to assign','FAIL!']),r.stdout
