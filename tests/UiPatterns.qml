import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/sdk" 1.0 as UI

ShellRoot {
  Commons.Translations { id: translations; directory: Qt.resolvedUrl("Island/i18n") }
  FloatingWindow {
    visible: true; implicitWidth: 1000; implicitHeight: 1200
    Patterns { id: gallery; width: 680; height: implicitHeight; strings: translations }
    Island.KeyboardNavigation { id: navigation; scope: gallery; containers: [gallery] }
    TestCase {
      id: test; when: false
      function checkPatterns() {
        gallery.setTheme("dark"); wait(30)
        var row = gallery.row, editor = gallery.editor
        compare(row.selected, false)
        row.forceActiveFocus(); keyClick(Qt.Key_Return)
        verify(row.selected); compare(gallery.rowActions, 1)
        var action = findChild(row, "patternRowAction")
        verify(navigation.candidates().indexOf(row) >= 0)
        verify(navigation.candidates().indexOf(action) >= 0, "Nested actions must remain keyboard reachable")
        action.forceActiveFocus(); keyClick(Qt.Key_Return)
        compare(gallery.actions, 1); compare(gallery.rowActions, 1)
        verify(editor.activeFocus, "Row action must focus its editor without activating the row")
        mouseClick(action); compare(gallery.actions, 2); compare(gallery.rowActions, 1)
        editor.text = "http://invalid"; wait(20)
        verify(!!gallery.fieldView.error); verify(editor.invalid)
        var draft = editor.text
        gallery.setTheme("light"); wait(30)
        compare(editor.text, draft); verify(editor.activeFocus)
        compare(editor.background.border.color, UI.Design.focusRing)
        row.forceActiveFocus(); wait(20)
        compare(editor.background.border.color, UI.Design.danger)
        editor.text = "https://calendar.example/events.ics"; wait(20)
        compare(gallery.fieldView.error, ""); compare(editor.background.border.color, UI.Design.fieldBorder)
        var oldHeight = row.implicitHeight
        gallery.width = 300; gallery.longText = true
        Commons.Style.fontOverrides = ({}); Commons.Style.fontBaseSize = 15
        wait(40); verify(row.stacked); verify(row.implicitHeight > oldHeight)
        var at = action.mapToItem(row, 0, 0)
        verify(at.x >= 0 && at.x + action.width <= row.width + 1, "Actions overflow a narrow row")
        verify(editor.width <= gallery.width && editor.width > 0)
        Commons.Style.cornerRadius = 0; compare(row.radius, 0); compare(editor.background.radius, 0)
        gallery.setMode("loading"); wait(30)
        var spinner = findChild(gallery.stateView, "t3SpinnerGlyph").parent
        verify(spinner.animating)
        gallery.visible = false; wait(20); verify(!spinner.animating)
        gallery.visible = true; Commons.Style.reduceMotion = true; wait(20); verify(!spinner.animating)
        Commons.Style.reduceMotion = false; wait(20); verify(spinner.animating)
        gallery.setMode("error"); wait(20)
        var retry = findChild(gallery.stateView, "dataStateAction")
        retry.forceActiveFocus(); keyClick(Qt.Key_Space)
        compare(gallery.mode, "loading"); compare(gallery.actions, 3)
        gallery.setMode("empty"); wait(20); verify(!retry.visible)
        gallery.setMode("disabled"); wait(20)
        verify(!editor.enabled && !row.enabled)
        compare(row.opacity, UI.Design.disabledOpacity)
        var count = gallery.rowActions
        mouseClick(row, 30, 30); compare(gallery.rowActions, count)
        var toggle = findChild(gallery, "patternSwitch")
        compare(toggle.opacity, UI.Design.disabledOpacity)
        console.log("UI_PATTERNS_PASS"); Qt.quit()
      }
    }
    Timer { interval: 150; running: true; onTriggered: { try { test.checkPatterns() } catch(error) { console.log("MODULES_FAIL", error.message, error.stack); Qt.quit() } } }
    Timer { interval: 9000; running: true; onTriggered: { console.log("MODULES_FAIL timeout"); Qt.quit() } }
  }
}
