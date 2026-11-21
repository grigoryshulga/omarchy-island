#!/usr/bin/env python3
"""Compare actual shader frames, including a silent audio monitor."""
from qml_result import assert_qml_pass
from session import ensure
ensure()
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-artwork-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/ArtworkFrames.qml').read_text())
    (root/'contrast.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="240" height="160"><rect width="240" height="160" fill="white"/><path d="M0 100 L240 20 V110 L0 160Z" fill="black"/></svg>')
    # The offscreen platform defaults to GL 2; the shipped QSB uses GL 3.3.
    source=root/'format.cpp'
    source.write_text('''#include <QSurfaceFormat>
__attribute__((constructor)) static void format() {
  QSurfaceFormat f; f.setRenderableType(QSurfaceFormat::OpenGL);
  f.setVersion(3,3); f.setProfile(QSurfaceFormat::CoreProfile);
  QSurfaceFormat::setDefaultFormat(f);
}
''')
    library=root/'format.so'
    flags=shlex.split(subprocess.check_output(['pkg-config','--cflags','--libs','Qt6Gui'],text=True))
    subprocess.run(['c++','-shared','-fPIC',str(source),'-o',str(library),*flags],check=True)
    env=dict(os.environ,QT_QPA_PLATFORM=os.environ.get('QT_QPA_PLATFORM','offscreen'),QT_QUICK_BACKEND='rhi',QSG_RHI_BACKEND='opengl',QSG_RENDER_LOOP='basic')
    env.setdefault('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}')
    env['LD_PRELOAD']=str(library)+((':'+env['LD_PRELOAD']) if env.get('LD_PRELOAD') else '')
    result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=25)
    print(result.stdout)
    assert_qml_pass(result, 'ARTWORK_FRAMES_PASS')
