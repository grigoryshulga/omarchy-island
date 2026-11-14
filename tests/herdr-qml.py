#!/usr/bin/env python3
from session import ensure
ensure()
from module_harness import ModuleHarness, PROJECT
with ModuleHarness() as harness:
    harness.run(PROJECT / 'tests/Herdr.qml', 'HERDR_PASS')
