#!/usr/bin/env python3
"""Check the weather layout in an isolated process; optionally capture GPU frames."""
from session import ensure
ensure()
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-weather-summary-') as temporary:
    root=Path(temporary)
    for name in ('Commons','Ui'):
        (root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/WeatherSummary.qml').read_text())
    env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',OMARCHY_PATH='/usr/share/omarchy')
    if os.environ.get('ISLAND_TEST_GPU'):
        # Match the shipped QSB profile, as in artwork-render.py.
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
        env.update(QT_QUICK_BACKEND='rhi',QSG_RHI_BACKEND='opengl',QSG_RENDER_LOOP='basic')
        env['LD_PRELOAD']=str(library)+((':'+env['LD_PRELOAD']) if env.get('LD_PRELOAD') else '')
    for language in ('ru','en','ar'):
        (root/'language').write_text(language)
        env['OMARCHY_LANGUAGE_FILE']=str(root/'language')
        if os.environ.get('ISLAND_WEATHER_CAPTURE'):
            capture=Path(os.environ['ISLAND_WEATHER_CAPTURE']).resolve()/language
            capture.mkdir(parents=True,exist_ok=True)
            env['ISLAND_WEATHER_CAPTURE']=str(capture)
        result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
        print(result.stdout)
        assert 'WEATHER_SUMMARY_PASS' in result.stdout and not any(marker in result.stdout for marker in (
            'WEATHER_SUMMARY_FAIL','ReferenceError:','TypeError:','Binding loop','Cannot assign',
            'Unable to assign','recursive rearrange','FAIL!','Failed to build graphics pipeline')),result.stdout
