#!/usr/bin/env python3
"""Capabilities: offscreen. Independent stores, migration, restart, corruption and privacy."""
from session import ensure
ensure()
import json
import stat
import subprocess
import sys
from module_harness import ModuleHarness, PROJECT

NOW = 1794560000


def run(harness, module, count, clear=False, dnd=False, failure=''):
    harness.run(PROJECT / 'tests/ModuleStorage.qml', 'MODULE_STORAGE_PASS', {
        'ISLAND_STORAGE_MODULE': module, 'ISLAND_STORAGE_COUNT': str(count),
        'ISLAND_STORAGE_CLEAR': str(int(clear)), 'ISLAND_STORAGE_DND': str(int(dnd)),
        'ISLAND_STORAGE_FAILURE': failure,
    })
    path = harness.storage / (module + '.json')
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    assert stat.S_IMODE(path.parent.stat().st_mode) == 0o700
    data = json.loads(path.read_text())
    assert 'islandMigrationPending' not in data
    assert set(data) == ({'version', 'downloads'} if module == 'downloads' else {'version', 'history', 'muted', 'dnd'})
    return data


# Both startup orders work; each retires only its migrated legacy fields.
for order in [('downloads', 'notifications'), ('notifications', 'downloads')]:
    with ModuleHarness() as harness:
        legacy = harness.storage / 'state.json'
        rows = [{'downloadPath': str(harness.storage / 'downloads/file.zip'), 'ts': NOW, 'downloadedBytes': 7},
                {'downloadPath': '/outside/file', 'ts': NOW},
                {'downloadPath': str(harness.storage / 'downloads/expired.zip'), 'ts': NOW - 1801}]
        payload = {'version': 1, 'downloads': rows, 'dnd': True, 'muted': ['Muted sender'], 'history': [
            {'key': 'code', 'summary': 'Verification code 654321', 'body': 'Use 654321 to sign in',
             'code': '654321', 'codes': '654321', 'ts': NOW, 'closed_ts': NOW, 'closed_reason': 'dismissed'}]}
        original = json.dumps(payload)
        legacy.write_text(original)
        for index, module in enumerate(order):
            other = harness.storage / (order[1-index] + '.json')
            before = other.read_bytes() if other.exists() else None
            data = run(harness, module, 1, dnd=True)
            assert '654321' not in json.dumps(data), 'Migration persisted a verification code'
            assert (other.read_bytes() if other.exists() else None) == before
            remaining = json.loads(legacy.read_text()) if legacy.exists() else {}
            owned = ('downloads', 'recents') if module == 'downloads' else ('history', 'muted', 'dnd')
            assert not any(key in remaining for key in owned), 'Migrated personal data remained in legacy'
            if index == 0:
                assert ('history' if module == 'downloads' else 'downloads') in remaining, 'Unmigrated peer was erased'
            else:
                assert not legacy.exists(), 'Completed migration left a permanent legacy copy'
            run(harness, module, 1, clear=True)
            run(harness, module, 0)  # Cleared rows must not reappear from legacy.
            (harness.storage / (module + '.json')).write_text('{broken')
            run(harness, module, 0)  # Corruption also must not reimport stale rows.

# Older recents schema and an interrupted initial migration remain recoverable.
with ModuleHarness() as harness:
    legacy = harness.storage / 'state.json'
    legacy.write_text(json.dumps({'recents': [{'downloadPath': str(harness.storage / 'downloads/old.zip'), 'ts': NOW}]}))
    (harness.storage / 'downloads.json').write_text('{"islandMigrationPending":true}')
    run(harness, 'downloads', 1)

with ModuleHarness() as harness:
    run(harness, 'downloads', 0)
    run(harness, 'notifications', 0)

for module, failure in [('downloads', 'timeout'), ('notifications', 'error'), ('downloads', 'missing')]:
    with ModuleHarness() as harness:
        run(harness, module, 0, failure=failure)

helper = PROJECT / 'plugin/bin/prepare-module-state'


def retire(harness, module, now=NOW):
    return subprocess.run([sys.executable, str(helper), str(harness.storage / (module+'.json')),
                           str(harness.storage / 'state.json'), 'retire', str(now)],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


with ModuleHarness() as harness:
    legacy=harness.storage / 'state.json'
    original=json.dumps({'history':[{'key':'unmigrated','closed_ts':NOW}], 'downloads':[{'ts':NOW}]})
    legacy.write_text(original)
    target=harness.storage / 'notifications.json'
    for incomplete in ('{"islandMigrationPending":true}', '{broken'):
        target.write_text(incomplete)
        assert retire(harness, 'notifications').returncode != 0
        assert legacy.read_text() == original, 'Uncommitted migration removed its source'
    # Concurrent acknowledgements must not overwrite each other's cleanup.
    target.write_text('{"version":1,"history":[],"muted":[],"dnd":false}')
    (harness.storage / 'downloads.json').write_text('{"version":1,"downloads":[]}')
    jobs=[subprocess.Popen([sys.executable, str(helper), str(harness.storage / (module+'.json')),
                           str(legacy), 'retire', str(NOW)], stdout=subprocess.PIPE) for module in ('notifications','downloads')]
    for job in jobs:
        job.communicate(timeout=5)
        assert job.returncode == 0
    assert not legacy.exists()

for owner, peer, ttl, time_field in [('notifications','downloads',1800,'ts'), ('downloads','history',86400,'closed_ts')]:
    with ModuleHarness() as harness:
        legacy=harness.storage / 'state.json'
        legacy.write_text(json.dumps({peer:[{time_field:NOW,'body':'private legacy data'}]}))
        run(harness, owner, 0)
        assert peer in json.loads(legacy.read_text()), 'Live peer data expired too soon'
        assert retire(harness, owner, NOW+ttl+1).returncode == 0
        assert not legacy.exists(), 'Disabled peer retained expired personal data'

print('PASS: independent module storage, migration in either order, restart, corrupt cache, redaction and private permissions.')
