import QtQuick
import QtTest
import Quickshell
import "Controls" as Controls

ShellRoot {
  FloatingWindow {
    visible: true
    implicitWidth: 300
    implicitHeight: 200
    Controls.ControlKeyCatcher {
      id: catcher
      anchors.fill: parent
      property var reorders: []
      property var moves: []
      property bool rtl: false
      LayoutMirroring.enabled: rtl
      onReorderSidewaysRequested: dx => reorders = reorders.concat([dx])
      onMoveRequested: (dx, dy) => moves = moves.concat([[dx, dy]])
    }
    TestCase {
      id: test
      when: false
      function test_sidewaysReorder() {
        catcher.forceActiveFocus()
        wait(50)
        // Default behavior stays navigation, without reordering a display.
        keyClick(Qt.Key_Right, Qt.ControlModifier)
        compare(catcher.reorders.length, 0)
        compare(catcher.moves.length, 1)
        catcher.reorderableSideways = true
        for (var key of [Qt.Key_Right, Qt.Key_L, Qt.Key_Left, Qt.Key_H])
          keyClick(key, Qt.ControlModifier)
        compare(JSON.stringify(catcher.reorders), "[1,1,-1,-1]")
        compare(catcher.moves.length, 1)
        catcher.rtl = true
        catcher.reorders = []
        for (var key of [Qt.Key_Right, Qt.Key_L, Qt.Key_Left, Qt.Key_H])
          keyClick(key, Qt.ControlModifier)
        compare(JSON.stringify(catcher.reorders), "[-1,-1,1,1]")
        catcher.blocked = true
        keyClick(Qt.Key_Left, Qt.ControlModifier)
        compare(catcher.reorders.length, 4)
        catcher.blocked = false
        keyClick(Qt.Key_Right)
        compare(catcher.reorders.length, 4)
        compare(catcher.moves.length, 2)
        console.log("CONTROL_KEYS_PASS")
        Qt.quit()
      }
    }
    Timer { interval: 100; running: true; onTriggered: test.test_sidewaysReorder() }
  }
}
