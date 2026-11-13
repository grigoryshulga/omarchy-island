#!/usr/bin/env python3
"""Capabilities: offscreen. Third-module registration, shared state and UI lifetime."""
from session import ensure
ensure()
from module_harness import ModuleHarness, PROJECT
import os

with ModuleHarness() as harness:
    # A new integration changes only the catalog and adds its own files.
    harness.register('sample', PROJECT / 'tests/modules')
    harness.run(PROJECT / 'tests/Modules.qml', 'MODULES_PASS')

with ModuleHarness() as harness:
    harness.run(PROJECT / 'tests/ModuleActions.qml', 'MODULE_ACTIONS_PASS')

with ModuleHarness() as harness:
    # Any accidental native command bypass must fail the scenario, not hit desktop.
    binary=harness.root / 'bin';binary.mkdir()
    log=harness.storage / 'bypassed'
    for name in ('omarchy-audio-output-sink', 'tailscale', 'omarchy-menu'):
        command=binary / name
        command.write_text('#!/usr/bin/python3\nfrom pathlib import Path\nPath('+repr(str(log))+').touch()\n')
        command.chmod(0o755)
    harness.run(PROJECT / 'tests/ModuleControls.qml', 'MODULE_CONTROLS_PASS', {
        'PATH':str(binary)+os.pathsep+os.environ['PATH'],
        'ISLAND_CONTROLS_HELPER':str(PROJECT / 'tests/modules/controls-process-fixture.py'),
    })
    assert not log.exists(), 'Controls bypassed the injected host/commands'
