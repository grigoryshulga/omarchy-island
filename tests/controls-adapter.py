#!/usr/bin/env python3
"""Cache invalidation and source isolation for embedded system panels."""
from pathlib import Path
import sys
import tempfile
import unittest

project = Path(__file__).resolve().parents[1]
helpers = project / 'plugin/controls'
sys.path.insert(0, str(helpers / 'lib'))
import adapter

SOURCE = '''import QtQuick
import qs.Ui
Panel {
  id: root
  function close() { controller.hide() }
  ShellIpc { target: "fixture"; function open() { root.open() } }
  BarIconButton { id: button; bar: root.bar; text: "x" }
  KeyboardPanel {
    id: panel
    open: root.opened
    focusTarget: panel.loadedContent
    content: PanelKeyCatcher { implicitHeight: 100 }
  }
}
'''


class ControlsAdapter(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='island-adapter-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        (self.source / 'Panel.qml').write_text(SOURCE)
        (self.source / 'Model.js').write_text('function answer() { return 1 }\n')
        self.cache = self.root / 'cache'

    def build(self):
        return adapter.build(self.source, 'Panel.qml', self.cache, 'fixture', helpers)

    def test_reuses_cache_and_rebuilds_changed_model(self):
        original = {p.name: p.read_bytes() for p in self.source.iterdir()}
        first = self.build()
        self.assertEqual(first, self.build())
        transformed = first.read_text()
        self.assertIn('IslandHost {', transformed)
        self.assertIn('IslandDisabledIpc {', transformed)
        self.assertIn('IslandHiddenBarButton {', transformed)
        self.assertIn('manageIpc: false', transformed)
        self.assertIn('function close() { controller.hide() }', transformed)
        self.assertEqual(original, {p.name: p.read_bytes() for p in self.source.iterdir()})
        (self.source / 'Model.js').write_text('function answer() { return 2 }\n')
        second = self.build()
        self.assertNotEqual(first, second)
        self.assertIn('return 1', (first.parent / 'Model.js').read_text())
        self.assertIn('return 2', (second.parent / 'Model.js').read_text())
        self.assertIn((project / 'plugin').as_uri(), (second.parent / 'ControlSwitch.qml').read_text())

    def test_rebuilds_changed_helpers(self):
        import shutil
        local_helpers = self.root / 'helpers'
        local_helpers.mkdir()
        for name in adapter.HELPER_NAMES:
            shutil.copyfile(helpers / name, local_helpers / name)
        def build():
            return adapter.build(self.source, 'Panel.qml', self.cache, 'fixture', local_helpers)
        first = build()
        host = local_helpers / 'IslandHost.qml'
        host.write_text(host.read_text() + '\n// updated container\n')
        self.assertNotEqual(first, build())

    def test_monitor_sideways_reorder_contract(self):
        source = SOURCE.replace(
            'content: PanelKeyCatcher { implicitHeight: 100 }',
            """content: PanelKeyCatcher {
      implicitHeight: 100
      reorderableSideways: true
      onReorderSidewaysRequested: function(dx) { root.reorderMonitor(dx) }
    }""")
        source = source.replace('id: root', 'id: root\n  function reorderMonitor(dx) {}')
        (self.source / 'Panel.qml').write_text(source)
        output = self.build()
        self.assertIn('reorderableSideways: true', output.read_text())
        self.assertIn('onReorderSidewaysRequested:', output.read_text())

    def test_rejects_new_host_contract(self):
        (self.source / 'Panel.qml').write_text(SOURCE.replace('id: panel', 'id: panel\n    unknownFutureProperty: true'))
        with self.assertRaisesRegex(adapter.AdaptationError, 'unknownFutureProperty'):
            self.build()

    def test_rejects_extra_surfaces_and_ambiguous_hosts(self):
        for extra in ['PanelWindow {}', 'KeyboardPanel {}']:
            with self.subTest(extra=extra):
                source = SOURCE.replace('  id: root', '  id: root\n  ' + extra)
                with self.assertRaises(adapter.AdaptationError):
                    adapter.transform_qml(source)

    def test_rejects_symlink_and_path_escape(self):
        (self.source / 'secret').symlink_to('/etc/passwd')
        with self.assertRaises(adapter.AdaptationError):
            self.build()
        (self.source / 'secret').unlink()
        with self.assertRaises(adapter.AdaptationError):
            adapter.build(self.source, '../Panel.qml', self.cache, 'fixture', helpers)

    def test_comments_and_regex_do_not_change_parse(self):
        source = SOURCE.replace('  id: root', '''  id: root
  // KeyboardPanel { fake }
  property string label: "KeyboardPanel {"
  function match(s) { return /[{}]/.test(s) }
''')
        transformed = adapter.transform_qml(source)
        self.assertIn('/[{}]/.test(s)', transformed)
        self.assertIn('IslandHost {', transformed)

    def test_all_installed_controls_and_source_immutability(self):
        for name in ['audio', 'bluetooth', 'network', 'tailscale', 'monitor']:
            with self.subTest(panel=name):
                directory = Path('/usr/share/omarchy/shell/plugins/panels') / name
                before = adapter.tree_digest(directory, skip_vcs=True)
                output = adapter.build(directory, 'Panel.qml', self.cache, name, helpers)
                self.assertTrue(output.is_file())
                self.assertEqual(before, adapter.tree_digest(directory, skip_vcs=True))

    def test_design_preserves_literal_text_and_visibility(self):
        source = SOURCE.replace('content: PanelKeyCatcher { implicitHeight: 100 }', '''content: PanelKeyCatcher {
          property string payload: "Style.font.body and PanelSeparator { are plain data"
          Text { text: parent.payload; font.pixelSize: Style.font.body }
          PanelSeparator { visible: root.opened }
          TextField { text: "literal $ & <b>"; password: true }
          Button { text: "Open"; onClicked: root.close() }
        }''')
        transformed = adapter.transform_qml(source)
        self.assertIn('"Style.font.body and PanelSeparator { are plain data"', transformed)
        self.assertIn('ControlGap { visible: root.opened }', transformed)
        self.assertIn('font.pixelSize: IslandKit.Design.type.body', transformed)
        self.assertIn('text: "literal $ & <b>"; password: true', transformed)
        self.assertIn('onClicked: root.close()', transformed)


if __name__ == '__main__':
    unittest.main()
