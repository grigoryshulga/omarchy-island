"""Keep direct Python test invocations as isolated as bin/test."""
import os
from pathlib import Path
import sys

WAYLAND = {'popup-motion.py', 'panel-layout.py', 'popup-theme.py', 'settings.py',
           'indicators.py', 'dictation.py'}


def ensure():
    if os.environ.get('ISLAND_TEST_SESSION'):
        return
    script = Path(sys.argv[0]).resolve()
    needs_wayland = script.name in WAYLAND or (
        script.name == 'keyboard.py' and os.environ.get('QT_QPA_PLATFORM') != 'offscreen')
    runner = script.parents[1] / 'bin/test-session'
    argv = [str(runner)] + (['--wayland'] if needs_wayland else [])
    os.execv(str(runner), [*argv, '--', '/usr/bin/python3', str(script), *sys.argv[1:]])
