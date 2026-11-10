#!/usr/bin/env python3
import os,subprocess,tempfile
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-indicators-qml-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'Bridge').symlink_to(project/'plugin/osd-bridge')
    (root/'shell.qml').write_text((project/'tests/Indicators.qml').read_text())
    env=dict(os.environ,QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='rhi' if os.environ.get('ISLAND_TEST_GPU') else 'software')
    r=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
    print(r.stdout)
    assert 'INDICATORS_PASS' in r.stdout and not any(s in r.stdout for s in ['INDICATORS_FAIL','ReferenceError:','TypeError:']),r.stdout
