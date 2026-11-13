"""Private compositor setup shared by local runs and CI."""
import os
from pathlib import Path
import subprocess
import sys
import time

if not os.environ.get('ISLAND_TEST_SESSION'):
    raise SystemExit('Use bin/test-session; this entry point requires a private session.')
command = sys.argv[1:]
wayland = command[:1] == ['--wayland']
if wayland:
    command.pop(0)
if command[:1] == ['--']:
    command.pop(0)
runtime = Path(os.environ['XDG_RUNTIME_DIR'])
runtime.mkdir(mode=0o700, exist_ok=True)
os.umask(0o077)
if not wayland:
    raise SystemExit(subprocess.call(command))
config = runtime / 'sway.conf'
config.write_text('output HEADLESS-1 mode 1920x1080\nseat seat0 fallback true\nxwayland disable\n')
env = dict(os.environ, WLR_BACKENDS='headless', WLR_RENDERER='pixman',
           WLR_LIBINPUT_NO_DEVICES='1', WLR_HEADLESS_OUTPUTS='1')
with (runtime / 'compositor.log').open('w+') as log:
    compositor = subprocess.Popen(['sway', '-c', str(config)], env=env, stdout=log, stderr=log)
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline and compositor.poll() is None:
            sockets = list(runtime.glob('wayland-*'))
            sockets = [path for path in sockets if path.is_socket()]
            if sockets:
                os.environ['WAYLAND_DISPLAY'] = sockets[0].name
                os.environ['QT_QPA_PLATFORM'] = 'wayland'
                raise SystemExit(subprocess.call(command))
            time.sleep(.05)
        log.seek(0)
        raise SystemExit('Headless compositor failed; no desktop fallback.\n' + log.read())
    finally:
        if compositor.poll() is None:
            compositor.terminate()
            try:
                compositor.wait(timeout=3)
            except subprocess.TimeoutExpired:
                compositor.kill()
                compositor.wait()
