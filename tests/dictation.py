#!/usr/bin/env python3
from qml_result import assert_qml_pass
from session import ensure
ensure()
import os,subprocess,tempfile
from pathlib import Path
project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-dictation-qml-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'Bridge').symlink_to(project/'plugin/osd-bridge')
    (root/'shell.qml').write_text((project/'tests/Dictation.qml').read_text())
    env=dict(os.environ,QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='rhi' if os.environ.get('ISLAND_TEST_GPU') else 'software',
             ISLAND_DICTATION_CAPTURE=str(root))
    r=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
    print(r.stdout)
    assert_qml_pass(r, 'DICTATION_PASS')
    def frame(name):
        return (root/f'{name}.png').read_bytes()

    assert frame('quiet') != frame('quiet-next'), 'The quiet sine wave did not move'
    assert frame('quiet') != frame('recording-first'), 'The wave did not react to the meter'
    assert frame('recording-first') != frame('recording-next'), 'The recording sine wave did not move'
    assert frame('recording-next') != frame('processing'), 'Transcription did not change the wave'
    assert frame('processing') != frame('processing-next'), 'The transcription pulse did not move'
    assert frame('reduced-first') == frame('reduced-next'), 'Reduced recording reacted to audio'
    assert frame('reduced-next') != frame('reduced-processing'), 'Reduced motion hid the change of state'
    assert frame('reduced-processing') == frame('reduced-processing-next'), 'Reduced transcription kept moving'
