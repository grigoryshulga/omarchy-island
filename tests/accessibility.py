#!/usr/bin/env python3
"""Exercise native Qt accessibility interfaces in the offscreen Quickshell session."""
from session import ensure
ensure()
from module_harness import ModuleHarness, PROJECT
from pathlib import Path
import shlex
import subprocess
import sys

helpers = PROJECT / "plugin/controls"
sys.path.insert(0, str(helpers / "lib"))
import adapter

with ModuleHarness() as harness:
    module = harness.root / 'IslandTest'
    module.mkdir()
    (module / 'qmldir').write_text('module IslandTest\nplugin probe\n')
    source = PROJECT / 'tests/AccessibilityProbe.cpp'
    libexec = subprocess.check_output(['pkg-config', '--variable=libexecdir', 'Qt6Core'], text=True).strip()
    cflags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', 'Qt6Quick'], text=True))
    subprocess.run([Path(libexec) / 'moc', *cflags, source, '-o', module / 'AccessibilityProbe.moc'], check=True)
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'Qt6Quick'], text=True))
    subprocess.run(['c++', '-shared', '-fPIC', '-I', module, source, '-o', module / 'libprobe.so', *flags], check=True)
    # Mount all five controls from the installed, adapted panels. Replace
    # their hardware callbacks with local value storage; no real device I/O.
    panel_root = Path('/usr/share/omarchy/shell/plugins/panels')
    control_blocks = []
    for panel in ('audio', 'monitor'):
        adapted, _ = adapter.adapt_qml((panel_root / panel / 'Panel.qml').read_text(), harness.root / 'Island/controls')
        syntax = adapter.tokens(adapted)
        for slider in (node for node in adapter.object_nodes(syntax) if node.type_name == 'PanelSlider'):
            children = adapter.object_nodes(adapter.tokens(adapted[slider.open_token.end:slider.close_token.start]))
            accessibility = next((child for child in children if child.type_name == 'SliderAccessibility'), None)
            if not accessibility:
                continue
            body = adapted[slider.open_token.end:slider.close_token.start]
            start, end = accessibility.type_token.start, accessibility.close_token.end
            control_blocks.append('PanelSlider { width: 200; value: root.mockLevel; onMoved: value => root.mockLevel=value; Island.' + body[start:end] + ' }')
    (harness.root / 'NativeSliders.qml').write_text('''import QtQuick
import qs.Ui
import "Island" as Island
Column {
  id: root
  property real mockLevel: 0.5
  function streamLabel(node) {return node}
  QtObject {id: streamRow; property string node: "Player A"}
  QtObject {id: outputHeader; property string text: "Output"}
  QtObject {id: microphoneHeader; property string text: "Microphone"}
  QtObject {id: brightnessHeader; property string text: "Brightness"}
  QtObject {id: textSizeHeader; property string text: "Text size"}
  QtObject {id: outputPercent; property string text: "50%"}
  QtObject {id: microphonePercent; property string text: "40%"}
  QtObject {id: brightnessPercent; property string text: "70%"}
  QtObject {id: textSizePx; property string text: "14px"}
  QtObject {id: streamPct; property string text: "90%"}
''' + '\n'.join(control_blocks) + '\n}')
    harness.run(PROJECT / 'tests/Accessibility.qml', 'ACCESSIBILITY_PASS',
                {'QML_IMPORT_PATH': str(harness.root)})
