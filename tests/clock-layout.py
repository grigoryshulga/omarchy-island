#!/usr/bin/env python3
"""Capabilities: offscreen. Clock builder editing, focus and persistence requests."""
from session import ensure
ensure()
from module_harness import ModuleHarness, PROJECT
with ModuleHarness() as harness:
    harness.register('sample', PROJECT / 'tests/modules')
    harness.run(PROJECT / 'tests/ClockLayout.qml', 'CLOCK_LAYOUT_PASS')
