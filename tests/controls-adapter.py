#!/usr/bin/env python3
"""Cache invalidation and source isolation for embedded system panels."""
from session import ensure
ensure()
from pathlib import Path
import os
import shutil
import subprocess
from qml_result import assert_qml_pass
import sys
import tempfile
import unittest

project = Path(__file__).resolve().parents[1]
helpers = project / 'plugin/controls'
sys.path.insert(0, str(helpers / 'lib'))
import adapter

SOURCE = '''import QtQuick
import qs.Ui
import qs.Commons
import "Model.js" as Model
Panel {
  id: root
  property int answer: Model.answer()
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

    def run_panel(self, output, checks="", answer=1):
        for name in ('Commons', 'Ui'):
            path = self.root / name
            if not path.exists():
                path.symlink_to(Path('/usr/share/omarchy/shell') / name)
        island = self.root / 'Island'
        if not island.exists():
            island.symlink_to(project / 'plugin')
        (self.root / 'shell.qml').write_text('''import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  FloatingWindow {
    visible: true; implicitWidth: 400; implicitHeight: 300
    Loader { id: panel; anchors.fill: parent; source: "''' + output.as_uri() + '''" }
    TestCase {
      id: test; when: false
      function run() {
        tryCompare(panel, "status", Loader.Ready)
        var page = panel.item
        compare(page.answer, ''' + str(answer) + ''')
        verify(!page.manageIpc, "Embedded panels must not own global IPC")
        page.open()
        tryVerify(function() { return page.keyboardTarget && page.keyboardTarget.activeFocus })
        var content = page.keyboardTarget
        verify(content.visible && content.width > 0 && content.height > 0)
        compare(content.mapToItem(panel, 0, 0).x, 0, "Content must stay in the host window")
        ''' + checks + '''
        page.close()
        tryCompare(page, "opened", false)
        verify(!content.visible, "Closed panel left visible content")
        console.log("ADAPTER_PASS")
        Qt.quit()
      }
    }
    Timer { interval: 100; running: true; onTriggered: {
      try { test.run() } catch(error) { console.log("ADAPTER_FAIL", error, error.stack); Qt.quit() }
    }}
  }
}
''')
        result = subprocess.run(['qs', '-p', str(self.root), '--no-color'],
                                env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software'),
                                capture_output=True, text=True, timeout=10)
        assert_qml_pass(result, 'ADAPTER_PASS')

    def source_files(self):
        return {p.relative_to(self.source): p.read_bytes() for p in self.source.rglob('*') if p.is_file()}

    def test_reuses_cache_and_rebuilds_changed_model(self):
        original = self.source_files()
        first = self.build()
        self.assertEqual(first, self.build())
        self.run_panel(first, answer=1)
        self.assertEqual(original, self.source_files())
        (self.source / 'Model.js').write_text('function answer() { return 2 }\n')
        second = self.build()
        self.assertNotEqual(first, second)
        self.run_panel(second, answer=2)
        self.run_panel(first, answer=1)  # A rebuild must not mutate an in-use copy.

    def test_rebuilds_changed_helpers(self):
        local_helpers = self.root / 'helpers'
        local_helpers.mkdir()
        for path in helpers.glob("*.qml"):
            shutil.copyfile(path, local_helpers / path.name)
        for path in helpers.glob("*.js"):
            shutil.copyfile(path, local_helpers / path.name)
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
        source = source.replace('id: root', 'id: root\n  property var moves: []\n  function reorderMonitor(dx) { moves = moves.concat([dx]) }')
        (self.source / 'Panel.qml').write_text(source)
        output = self.build()
        self.run_panel(output, '''keyClick(Qt.Key_Right, Qt.ControlModifier)
        keyClick(Qt.Key_Left, Qt.ControlModifier)
        compare(JSON.stringify(page.moves), "[1,-1]")''')

    def test_rejects_new_host_contract(self):
        (self.source / 'Panel.qml').write_text(SOURCE.replace('id: panel', 'id: panel\n    unknownFutureProperty: true'))
        with self.assertRaisesRegex(adapter.AdaptationError, 'unknownFutureProperty'):
            self.build()

    def test_rejects_extra_surfaces_and_ambiguous_hosts(self):
        for extra in ['PanelWindow {}', 'KeyboardPanel {}']:
            with self.subTest(extra=extra):
                source = SOURCE.replace('  id: root', '  id: root\n  ' + extra)
                (self.source / "Panel.qml").write_text(source)
                with self.assertRaises(adapter.AdaptationError):
                    self.build()

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
        (self.source / 'Panel.qml').write_text(source)
        self.run_panel(self.build(), '''compare(page.label, "KeyboardPanel {")
        verify(page.match("{")); verify(page.match("}")); verify(!page.match("plain"))''')

    def test_all_installed_controls_and_source_immutability(self):
        for name in ['audio', 'bluetooth', 'network', 'tailscale', 'monitor']:
            with self.subTest(panel=name):
                directory = Path('/usr/share/omarchy/shell/plugins/panels') / name
                before = {p.relative_to(directory): p.read_bytes() for p in directory.rglob('*') if p.is_file()}
                output = adapter.build(directory, 'Panel.qml', self.cache, name, helpers)
                self.assertTrue(output.is_file())
                self.assertEqual(before, {p.relative_to(directory): p.read_bytes() for p in directory.rglob('*') if p.is_file()})

    def test_design_preserves_literal_text_and_visibility(self):
        source = SOURCE.replace('content: PanelKeyCatcher { implicitHeight: 100 }', '''content: PanelKeyCatcher {
          property string payload: "Style.font.body and PanelSeparator { are plain data"
          Text { objectName: "literalLabel"; text: parent.payload; font.pixelSize: Style.font.body }
          PanelSeparator { objectName: "gap"; visible: root.opened }
          TextField { objectName: "password"; text: "literal $ & <b>"; password: true }
          Button { objectName: "closeButton"; text: "Close"; focusable: true; onClicked: root.close() }
        }''')
        (self.source / 'Panel.qml').write_text(source)
        self.run_panel(self.build(), '''var label = findChild(content, "literalLabel")
        compare(label.text, "Style.font.body and PanelSeparator { are plain data")
        compare(label.font.pixelSize, Island.Design.type.body)
        Commons.Style.fontOverrides = ({})
        Commons.Style.fontBaseSize *= 1.5
        tryCompare(label.font, "pixelSize", Island.Design.type.body)
        var field = findChild(content, "password")
        compare(field.text, "literal $ & <b>")
        compare(field.echoMode, TextInput.Password)
        var gap = findChild(content, "gap")
        verify(gap.visible)
        var button = findChild(content, "closeButton")
        button.forceActiveFocus(); keyClick(Qt.Key_Return)
        tryCompare(page, "opened", false)
        verify(!gap.visible)
        page.open()
        tryVerify(function() { return gap.visible })''')



if __name__ == '__main__':
    unittest.main()
