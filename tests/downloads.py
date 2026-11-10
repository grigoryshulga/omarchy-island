#!/usr/bin/env python3
"""Exercise real inotify events, including the recursive and rename paths."""
import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import time

project = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('downloads', str(project / 'plugin/bin/watch-downloads'))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp) / 'downloads'
    events = []
    watcher = module.Watcher(root, events.append)

    def pump(seconds=0.35):
        until = time.monotonic() + seconds
        while time.monotonic() < until:
            watcher.read()
            watcher.tick()
            time.sleep(0.01)

    def completed():
        return [Path(e['path']).name for e in events if e['event'] == 'complete']

    try:
        # Missing root is harmless; existing files are not replayed.
        watcher.add_tree(root)
        root.mkdir()
        (root / 'old.txt').write_text('old')
        sub = root / 'nested'
        sub.mkdir()
        watcher.add_tree(root)
        pump()
        assert completed() == []
        partial = sub / 'файл $ spaced.zip.crdownload'
        with partial.open('w') as stream:
            stream.write('first'); stream.flush()
            pump()
            assert events[-1]['count'] == 1
            assert events[-1]['files'][0]['bytes'] == 5
            assert completed() == []
        pump(1.1)
        assert completed() == [], 'A closed partial is not a completed download'
        partial.write_text('first and more')
        pump()
        assert events[-1]['files'][0]['bytes'] == 14
        final = partial.with_suffix('')
        partial.rename(final)
        pump(1.2)
        assert completed() == [final.name]
        assert [e for e in events if e['event']=='complete'][0]['bytes'] == 14
        assert events[-1] == {'event': 'active', 'count': 0, 'files': []}
        # A new subtree is watched even when created and populated at once.
        deep = sub / 'new' / 'deep'
        deep.mkdir(parents=True)
        (deep / 'direct.txt').write_text('download')
        pump(1.2)
        assert completed().count('direct.txt') == 1
        # Cancellation and moves outside the tree do not complete.
        canceled = sub / 'cancel.part'
        canceled.write_text('x'); pump()
        canceled.unlink(); pump()
        moved = sub / 'moved.part'
        moved.write_text('x'); pump()
        moved.rename(Path(tmp) / 'outside.txt'); pump(1.2)
        assert completed() == [final.name, 'direct.txt']
        assert events[-1]['count'] == 0
        # Symlink subtrees are never traversed.
        outside = Path(tmp) / 'external'; outside.mkdir()
        (root / 'link').symlink_to(outside, target_is_directory=True)
        pump()
        (outside / 'hidden').write_text('x'); pump(1.2)
        assert len(completed()) == 2
        # Several concurrent downloads keep the OSD active until the last one.
        a = (sub / 'a.part').open('w'); b = (sub / 'b.part').open('w')
        a.write('a'); a.flush(); b.write('b'); b.flush(); pump()
        assert events[-1]['count'] == 2
        a.close(); b.close()
        (sub / 'a.part').rename(sub / 'a'); pump(1.2)
        assert events[-1]['count'] == 1
        (sub / 'b.part').unlink(); pump()
        assert events[-1]['count'] == 0
    finally:
        watcher.close()
print('Download watcher tests passed')
