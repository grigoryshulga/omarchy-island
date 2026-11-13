#!/usr/bin/env python3
"""Check separation from the user's desktop and persistent settings."""
from session import ensure
ensure()
import os
from pathlib import Path
import subprocess

root = Path(os.environ['ISLAND_TEST_SESSION'])
assert Path(os.environ['HOME']) == root / 'home'
assert Path(os.environ['XDG_RUNTIME_DIR']) == root / 'runtime'
assert (root / 'runtime').stat().st_mode & 0o777 == 0o700
for name in ['DISPLAY', 'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE',
             'SWAYSOCK', 'SESSION_MANAGER', 'SSH_AUTH_SOCK', 'XAUTHORITY',
             'XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME']:
    assert name not in os.environ, name
assert os.environ['QT_QPA_PLATFORM'] == 'offscreen'
assert os.environ['DBUS_SYSTEM_BUS_ADDRESS'] == 'unix:path=' + str(root / 'no-system-bus')
assert os.environ['PULSE_SERVER'] == 'unix:' + str(root / 'no-pulse')
result = subprocess.run(['dbus-send', '--session', '--print-reply',
    '--dest=org.freedesktop.DBus', '/org/freedesktop/DBus',
    'org.freedesktop.DBus.ListNames'], capture_output=True, text=True, check=True)
assert 'org.freedesktop.Notifications' not in result.stdout
print('PASS: private HOME, runtime and D-Bus; no inherited desktop connections.')

# Exercise the public launcher with a contaminated parent environment and failure.
import json
import sys
runner = Path(__file__).resolve().parents[1] / 'bin/test-session'
probe = '''import json, os, sys
from pathlib import Path
assert not any(k in os.environ for k in ('DISPLAY', 'WAYLAND_DISPLAY', 'SWAYSOCK', 'XAUTHORITY'))
assert os.environ['DBUS_SESSION_BUS_ADDRESS'] != 'unix:path=/invalid-parent-bus'
assert os.environ['HOME'] != '/invalid-parent-home'
print(json.dumps(os.environ['ISLAND_TEST_SESSION']))
sys.exit(7)
'''
contaminated = dict(os.environ, DISPLAY=':987', WAYLAND_DISPLAY='host-wayland',
                    SWAYSOCK='/invalid-parent-sway', XAUTHORITY='/invalid-parent-auth',
                    DBUS_SESSION_BUS_ADDRESS='unix:path=/invalid-parent-bus',
                    HOME='/invalid-parent-home')
result = subprocess.run([str(runner), '--', sys.executable, '-c', probe],
                        env=contaminated, capture_output=True, text=True, timeout=15)
assert result.returncode == 7, result.stdout + result.stderr
assert not Path(json.loads(result.stdout)).exists(), 'Temporary session survived failure'
print('PASS: contaminated parent discarded, exit status preserved, failure cleanup.')
