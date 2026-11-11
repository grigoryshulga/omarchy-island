#!/usr/bin/env python3
"""Generate one embedded system panel without modifying installed plugins."""
import json
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / 'lib'))
from adapter import AdaptationError, build

PANELS = {'audio': 'audio', 'bluetooth': 'bluetooth', 'network': 'network',
          'tailscale': 'tailscale', 'monitors': 'monitor'}

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in PANELS:
        raise AdaptationError('unknown Controls section')
    directory = Path(os.environ.get('OMARCHY_PATH') or '/usr/share/omarchy') / 'shell/plugins/panels' / PANELS[sys.argv[1]]
    cache = Path(os.environ.get('XDG_CACHE_HOME') or str(Path.home() / '.cache')) / 'omarchy-island/controls'
    output = build(directory, 'Panel.qml', cache, 'omarchy.' + PANELS[sys.argv[1]], Path(__file__).resolve().parent)
    print(json.dumps({'url': output.as_uri()}))

if __name__ == '__main__':
    try:
        main()
    except (AdaptationError, OSError) as error:
        print(f'island-controls: {error}', file=sys.stderr)
        sys.exit(1)
