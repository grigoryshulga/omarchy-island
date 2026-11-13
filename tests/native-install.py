#!/usr/bin/env python3
"""Validate and clone through Omarchy's real CLI, using an isolated home and IPC stub."""
from session import ensure
ensure()
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

project = Path(__file__).resolve().parents[1]
manifest = json.loads((project / 'manifest.json').read_text())
flat = json.loads((project / 'plugin/manifest.json').read_text())
flat['entryPoints'] = {kind: 'plugin/' + entry for kind, entry in flat['entryPoints'].items()}
assert manifest == flat, 'Root and legacy manifests disagree'

with tempfile.TemporaryDirectory(prefix='island-native-') as directory:
    root = Path(directory)
    source = root / 'source'
    shutil.copytree(project, source, ignore=shutil.ignore_patterns('.git', '.local', '__pycache__'))
    subprocess.run(['omarchy', 'plugin', 'validate', str(source)], check=True)
    subprocess.run(['omarchy', 'plugin', 'validate', str(source / 'plugin')], check=True)
    subprocess.run(['git', 'init', '-q', '--initial-branch=main', str(source)], check=True)
    subprocess.run(['git', '-C', str(source), 'add', '.'], check=True)
    subprocess.run(['git', '-C', str(source), '-c', 'user.name=Fixture', '-c',
                    'user.email=fixture@example.invalid', 'commit', '-qm', 'Fixture'], check=True)
    home = root / 'home'
    home.mkdir()
    commands = root / 'commands'
    commands.mkdir()
    ipc = commands / 'omarchy-shell'
    ipc.write_text('#!/bin/sh\nexit 0\n')
    ipc.chmod(0o755)
    url = 'https://github.com/grigoryshulga/omarchy-island.git'
    env = dict(os.environ, HOME=str(home), PATH=str(commands)+os.pathsep+os.environ['PATH'],
               GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='url.'+source.as_uri()+'.insteadOf',
               GIT_CONFIG_VALUE_0=url)
    # The URL policy sees HTTPS; git obtains the fixture via a per-process URL rewrite.
    result = subprocess.run(['omarchy', 'plugin', 'add', url, '--yes'], env=env,
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stdout+result.stderr
    installed = home / '.config/omarchy/plugins/gshulga.island'
    assert json.loads((installed / 'manifest.json').read_text()) == manifest
    assert (installed / '.git').is_dir()
    assert (installed / 'plugin/BarWidget.qml').is_file()
    assert (installed / 'plugin/shaders/spotlight.frag.qsb').read_bytes() == (project / 'plugin/shaders/spotlight.frag.qsb').read_bytes()
    assert 'Enable it later' in result.stdout, 'Plugin was enabled before notifications were disabled'
    guard = subprocess.run([str(installed / 'bin/install')], env=env, capture_output=True, text=True)
    assert guard.returncode == 1 and 'managed by Omarchy' in guard.stderr
    status = subprocess.check_output(['git', '-C', str(installed), 'status', '--porcelain'], text=True)
    assert not status, 'Native checkout was modified'
    for module in ['Commons', 'Ui']:
        (root / module).symlink_to(Path('/usr/share/omarchy/shell') / module)
    (root / 'Services').symlink_to('/usr/share/omarchy/shell/services')
    (root / 'shell.qml').write_text((project / 'tests/NativeRegistry.qml').read_text().replace('ROOT_MANIFEST', json.dumps(manifest)))
    qml_env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
    result = subprocess.run(['qs', '-p', str(root), '--no-color'], env=qml_env,
                            capture_output=True, text=True, timeout=8)
    assert 'ISLAND_NATIVE_REGISTRY_PASS' in result.stdout+result.stderr, result.stdout+result.stderr

print('PASS: native clone, root/legacy manifests, clean git checkout, clock replacement and restoration.')
