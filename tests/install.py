#!/usr/bin/env python3
"""Exercise the real installer in temporary homes without touching the desktop."""
from session import ensure
ensure()
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
base = {
    'version': 1,
    'bar': {'layout': {
        'center': [{'id': 'omarchy.clock', 'format': 'dddd HH:mm'}],
        'left': [{'id': 'custom.dashboard', 'tiles': [{'id': 'omarchy.clock'}]}],
        'right': [{'id': 'omarchy.audio'}],
    }},
    'disabledPlugins': ['unrelated.plugin'],
}

with tempfile.TemporaryDirectory(prefix='island-install-') as directory:
    root = Path(directory)
    commands = root / 'bin'
    commands.mkdir()
    for name in ['omarchy', 'omarchy-shell', 'qs', 'wl-copy', 'wl-paste', 'parec']:
        path = commands / name
        path.write_text('#!/bin/sh\nexit 0\n')
        path.chmod(0o755)
    lock = commands / 'omarchy-hyprland-session-locked'
    lock.write_text('#!/bin/sh\ntest "$ISLAND_TEST_LOCKED" = 1\n')
    lock.chmod(0o755)
    system = root / 'system'
    for module in ['Commons', 'Ui']:
        (system / 'shell' / module).mkdir(parents=True)

    def run(script, env, expected=0):
        result = subprocess.run([str(project / 'bin' / script)], env=env,
                                text=True, capture_output=True)
        assert result.returncode == expected, result.stdout + result.stderr

    for initially_disabled in [False, True]:
        home = root / ('disabled' if initially_disabled else 'enabled')
        config = home / '.config/omarchy/shell.json'
        config.parent.mkdir(parents=True)
        original = copy.deepcopy(base)
        if initially_disabled:
            original['disabledPlugins'].append('omarchy.notifications')
        config.write_text(json.dumps(original))
        env = dict(os.environ, HOME=str(home), OMARCHY_PATH=str(system),
                   PATH=str(commands) + os.pathsep + os.environ['PATH'],
                   ISLAND_TEST_LOCKED='0')
        state = home / '.local/state/omarchy/island'
        target = home / '.config/omarchy/plugins/gshulga.island'

        # A locked session must fail before changing configuration or copying code.
        run('install', dict(env, ISLAND_TEST_LOCKED='1'), expected=1)
        assert json.loads(config.read_text()) == original
        assert not target.exists()

        run('install', env)
        installed = json.loads(config.read_text())
        assert installed['bar']['layout']['center'][0]['id'] == 'gshulga.island'
        assert installed['bar']['layout']['center'][0]['format'] == 'dddd HH:mm'
        assert installed['bar']['layout']['left'] == original['bar']['layout']['left']
        assert 'omarchy.notifications' in installed['disabledPlugins']
        assert (target / 'shaders/spotlight.frag.qsb').read_bytes() == (project / 'plugin/shaders/spotlight.frag.qsb').read_bytes()
        record = (state / 'install.json').read_bytes()

        # Reinstall within the same second, preserving the original restore record.
        installed['unrelatedPreference'] = 'keep me'
        config.write_text(json.dumps(installed))
        run('install', env)
        assert (state / 'install.json').read_bytes() == record
        assert len(list(state.glob('shell-before-*.json'))) == 2
        assert json.loads(config.read_text())['disabledPlugins'].count('omarchy.notifications') == 1

        run('uninstall', env)
        restored = json.loads(config.read_text())
        assert restored['bar'] == original['bar']
        assert restored['unrelatedPreference'] == 'keep me'
        assert ('omarchy.notifications' in restored['disabledPlugins']) == initially_disabled
        assert 'unrelated.plugin' in restored['disabledPlugins']
        assert 'gshulga.island' in restored['disabledPlugins']

        # A normal install works again after removal.
        run('install', env)
        assert 'gshulga.island' not in json.loads(config.read_text())['disabledPlugins']
        run('uninstall', env)

print('PASS: installer preflight, backups, reinstall, nested clocks and configuration restoration.')
