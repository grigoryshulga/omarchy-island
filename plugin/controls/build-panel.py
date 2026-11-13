#!/usr/bin/env python3
"""Generate one embedded system panel without modifying installed plugins."""
import json
import os
from pathlib import Path
import sys
import subprocess
from catalog import catalog

sys.path.insert(0, str(Path(__file__).resolve().parent / 'lib'))
from adapter import AdaptationError, build

PANELS = {'audio': 'audio', 'bluetooth': 'bluetooth', 'network': 'network',
          'tailscale': 'tailscale', 'monitors': 'monitor'}

def main():
    if len(sys.argv) == 2 and sys.argv[1] == '--catalog':
        print(json.dumps([{'key': 'plugin:' + row['id'], 'name': row['name']} for row in catalog()]))
        return
    if len(sys.argv) != 2:
        raise AdaptationError('unknown Controls section')
    key = sys.argv[1]
    entry = 'Panel.qml'
    settings = {}
    if key.startswith('plugin:'):
        row = next((row for row in catalog() if 'plugin:' + row['id'] == key), None)
        if not row:
            raise AdaptationError('Controls plugin is no longer installed')
        directory, entry, plugin_id = Path(row['source']), row['entry'], row['id']
        settings = row['defaults']
    elif key in PANELS:
        directory = Path(os.environ.get('OMARCHY_PATH') or '/usr/share/omarchy') / 'shell/plugins/panels' / PANELS[key]
        plugin_id = 'omarchy.' + PANELS[key]
    else:
        raise AdaptationError('unknown Controls section')
    cache = Path(os.environ.get('XDG_CACHE_HOME') or str(Path.home() / '.cache')) / 'omarchy-island/controls'
    output = build(directory, entry, cache, plugin_id, Path(__file__).resolve().parent)
    print(json.dumps({'url': output.as_uri(), 'settings': settings}))

if __name__ == '__main__':
    try:
        main()
    except (AdaptationError, OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'island-controls: {error}', file=sys.stderr)
        sys.exit(1)
