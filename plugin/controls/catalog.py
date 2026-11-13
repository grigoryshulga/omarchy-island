"""Resolve installed standard panels through Omarchy's public manifest catalog."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from adapter import AdaptationError, adapt_qml, read_entry_point


def catalog():
    base = Path(os.environ.get('OMARCHY_PATH') or '/usr/share/omarchy')
    environment = dict(os.environ, OMARCHY_PATH=str(base))
    result = subprocess.run([str(base / 'bin/omarchy-plugin-catalog')], env=environment,
                            capture_output=True, timeout=5, check=True)
    if len(result.stdout) > 2_000_000:
        raise ValueError('Controls catalog exceeds limit')
    rows = json.loads(result.stdout)
    found = {}
    if not isinstance(rows, list):
        raise ValueError("Invalid Controls catalog")
    for row in rows[:1024]:
        if not isinstance(row, dict):
            continue
        key = row.get('id', '')
        if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,159}', key) or key in ('gshulga.island', 'omarchy.audio', 'omarchy.bluetooth', 'omarchy.network', 'omarchy.tailscale', 'omarchy.monitor'):
            continue
        entries = row.get('entryPoints') or {}
        if not isinstance(entries, dict) or not isinstance(row.get('sourceDir'), str):
            continue
        source = Path(row['sourceDir'])
        if not source.is_absolute():
            continue
        entry = None
        for name in ('panel', 'barWidget'):
            candidate = entries.get(name)
            if not isinstance(candidate, str) or not candidate or Path(candidate).is_absolute() or '..' in Path(candidate).parts:
                continue
            try:
                adapt_qml(read_entry_point(source / candidate))
            except (AdaptationError, OSError, UnicodeError):
                continue
            entry = candidate
            break
        if not entry:
            continue
        widget = row.get('barWidget')
        defaults = widget.get('defaults', {}) if isinstance(widget, dict) else {}
        if not isinstance(defaults, dict):
            defaults = {}
        found[key] = {'defaults': defaults, 'id': key, 'name': str(row.get('name') or key)[:160],
                      'source': str(source), 'entry': entry}
    return list(found.values())
