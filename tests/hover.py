#!/usr/bin/env python3
"""Offscreen pointer events through the clock's real hover/open/close logic."""
from session import ensure
ensure()
from module_harness import ModuleHarness, PROJECT

with ModuleHarness() as harness:
    # Only replace the native surface backend: offscreen Qt has no layer shell.
    # Keep the actual popup card, hover handler and all BarWidget logic.
    popup = harness.root / 'Island/IslandPopup.qml'
    source = popup.read_text().replace('PanelWindow {', 'FloatingWindow {', 1)
    source = source.replace('  anchors { top: true; bottom: true; left: true; right: true }\n', '')
    source = source.replace('  exclusionMode: ExclusionMode.Ignore\n', '')
    source = source.replace('  WlrLayershell.keyboardFocus: open && pinned\n'
                            '    ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)\n'
                            '    : WlrKeyboardFocus.None\n', '')
    source = '\n'.join(line for line in source.splitlines()
                       if 'WlrLayershell.' not in line and 'mask: Region' not in line)
    popup.write_text(source)
    harness.run(PROJECT / 'tests/Hover.qml', 'HOVER_PASS')
