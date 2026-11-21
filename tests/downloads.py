#!/usr/bin/env python3
"""Exercise the watcher's JSON-lines CLI with real files, never its private state."""
from session import ensure
ensure()
import json
from pathlib import Path
from queue import Queue, Empty
import subprocess
import sys
import tempfile
from threading import Thread
import time

project = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix='island-downloads-') as tmp:
    root = Path(tmp) / 'downloads'
    process = subprocess.Popen([sys.executable, str(project / 'plugin/bin/watch-downloads'), str(root)],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    lines = Queue()

    def read_lines():
        for line in process.stdout:
            lines.put(line)
        lines.put(None)

    reader = Thread(target=read_lines, daemon=True)
    reader.start()
    events = []
    active_ids = {}
    completed_ids = {}

    def receive(timeout):
        try:
            line = lines.get(timeout=timeout)
        except Empty:
            return
        assert line is not None, 'Watcher exited before the scenario completed'
        event = json.loads(line)
        if event['event'] == 'active':
            for item in event['files']:
                active_ids[item['path']] = item.pop('id')
            assert event['count'] == len(event['files']), f'Wrong active download count: {event}'
        elif event['event'] == 'complete':
            completed_ids[event['path']] = event.pop('id')
        events.append(event)

    def wait_for(predicate, description, action=None):
        deadline = time.monotonic() + 5
        while not predicate() and time.monotonic() < deadline:
            if action:
                action()
            receive(0.05)
        assert predicate(), f'{description}: {events}'

    def observe(seconds=1.3):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            receive(max(0, min(0.05, deadline - time.monotonic())))

    def completed():
        return [e for e in events if e['event'] == 'complete']

    def active_files():
        snapshots = [e for e in events if e['event'] == 'active']
        return snapshots[-1]['files'] if snapshots else None

    def wait_active(expected):
        wait_for(lambda: active_files() == expected, f'Expected active files {expected}')

    try:
        wait_active([])  # A missing root is harmless.
        staging = Path(tmp) / 'staging'
        sub = staging / 'nested'
        sub.mkdir(parents=True)
        (staging / 'old.txt').write_text('old')
        staging.rename(root)
        sub = root / 'nested'
        partial = sub / 'файл $ spaced.zip.crdownload'
        # The CLI has no ready signal for a newly created directory. Repeated real
        # writes await watch registration instead of guessing a startup sleep.
        with partial.open('w') as stream:
            def write_partial():
                stream.seek(0)
                stream.write('first')
                stream.flush()
            wait_for(lambda: active_files() == [{'path': str(partial), 'bytes': 5}],
                     'Watcher did not discover the new directory', write_partial)
        observe()
        assert completed() == [], 'Startup files or a closed partial were replayed as completed'
        partial.write_text('first and more')
        wait_active([{'path': str(partial), 'bytes': 14}])
        final = partial.with_suffix('')
        partial.rename(final)
        expected = {'event': 'complete', 'path': str(final), 'bytes': 14}
        wait_for(lambda: completed() == [expected], 'Rename did not complete exactly once')
        assert completed_ids[str(final)] == active_ids[str(partial)] == active_ids[str(final)]
        wait_active([])

        # This cancellation immediately follows an active snapshot. The final
        # empty snapshot must still arrive if publishing is currently throttled.
        canceled = sub / 'cancel.part'
        canceled.write_text('x')
        wait_active([{'path': str(canceled), 'bytes': 1}])
        canceled.unlink()
        wait_active([])
        assert completed() == [expected], 'Cancellation was announced as completion'

        deep = sub / 'new' / 'deep'
        deep.mkdir(parents=True)
        direct = deep / 'direct.txt'
        direct.write_text('download')
        wait_for(lambda: len(completed()) == 2, 'Populated subtree was not discovered')
        assert completed()[1] == {'event': 'complete', 'path': str(direct), 'bytes': 8}
        wait_active([])

        moved = sub / 'moved.part'
        moved.write_text('x')
        wait_active([{'path': str(moved), 'bytes': 1}])
        moved.rename(Path(tmp) / 'outside.txt')
        wait_active([])
        outside = Path(tmp) / 'external'
        outside.mkdir()
        (root / 'link').symlink_to(outside, target_is_directory=True)
        (outside / 'hidden').write_text('x')
        observe()
        assert len(completed()) == 2, 'Moved-out or symlinked file was announced'

        a, b = sub / 'a.part', sub / 'b.part'
        a.write_text('a')
        b.write_text('bb')
        wait_for(lambda: active_files() is not None and
                 {item['path']: item['bytes'] for item in active_files()} == {str(a): 1, str(b): 2},
                 'Concurrent downloads were not both reported')
        a.rename(sub / 'a')
        wait_for(lambda: len(completed()) == 3, 'First concurrent download did not complete')
        assert completed()[-1] == {'event': 'complete', 'path': str(sub / 'a'), 'bytes': 1}
        wait_active([{'path': str(b), 'bytes': 2}])
        b.unlink()
        wait_active([])
        observe()
        assert len(completed()) == 3, 'Completion was duplicated or cancellation completed a file'
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        reader.join(timeout=1)
        errors = process.stderr.read()
        process.stdout.close()
        process.stderr.close()
        assert not errors, errors
print('PASS: download CLI startup, recursive events, sizes, rename, cancellation and final empty snapshots')
