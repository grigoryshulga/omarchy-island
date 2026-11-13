#!/usr/bin/env python3
"""Capabilities: offscreen. Actual SDK compositions and keyboard/theme states."""
from session import ensure
ensure()
import shutil
import subprocess
import struct
from module_harness import ModuleHarness, PROJECT

for language in ('en', 'ru'):
    with ModuleHarness() as harness:
        shutil.copy2(PROJECT / 'design/Patterns.qml', harness.root / 'Patterns.qml')
        (harness.root / 'language').write_text(language)
        harness.run(PROJECT / 'tests/UiPatterns.qml', 'UI_PATTERNS_PASS',
                    {'OMARCHY_LANGUAGE_FILE': str(harness.root / 'language')})

with ModuleHarness() as harness:
    harness.run(PROJECT / 'tests/ModulePatterns.qml', 'MODULE_PATTERNS_PASS')

with ModuleHarness() as harness:
    captures = harness.storage / 'patterns'
    result = subprocess.run([str(PROJECT / 'bin/design-gallery'), '--patterns', '--language', 'ru',
                             '--capture-dir', str(captures)],
                            capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0 and 'PATTERNS_CAPTURE_PASS' in output
    assert not any(error in output for error in ('ERROR:', 'PATTERNS_CAPTURE_FAIL', 'TypeError:',
                   'ReferenceError:', 'Binding loop', 'Cannot assign', 'Unable to assign'))
    assert len(list(captures.glob('*.png'))) == 10
    for name, expected_width in [('dark-ready', 740), ('narrow-large', 380)]:
        data = (captures / (name + '.png')).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n'
        width, height = struct.unpack('>II', data[16:24])
        assert width == expected_width and height > 0, (name, width, height)
