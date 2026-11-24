import QtQuick
import QtTest
import Quickshell
import qs.Commons
import "gshulga.island/plugin" as Island
import "gshulga.island-bar" as Adapter

ShellRoot {
  QtObject {
    id: host
    property var config: ({
      position: "top",
      layout: { left: [{ id: "omarchy.workspaces" }], right: [
        { id: "gshulga.island", format: "HH:mm", hoverDelay: 120, weatherEnabled: false }
      ] }
    })

    function updateEntryInline(id, entry) {
      if (id !== "gshulga.island") return false
      config = { position: config.position, layout: { right: [entry] } }
      return true
    }
  }

  Island.Service { id: service }
  Adapter.Bar { id: bar; shell: host; barConfig: host.config }

  TestCase {
    id: test
    when: false

    function run() {
      try {
        tryVerify(() => bar.moduleWidgets("gshulga.island").length === Quickshell.screens.length, 1000)
        const widget = bar.moduleWidgets("gshulga.island")[0]
        verify(!!widget, "Island is missing from the output")
        compare(widget.service, service, "The existing service must power the standalone Island")
        compare(widget.configuredFormat, "HH:mm")
        compare(widget.fixedEdge, "center")
        compare(bar.moduleWidgets("omarchy.workspaces").length, 0)
        tryVerify(() => widget.width > 0 && widget.height > 0, 1000)
        verify(Math.abs(widget.x + widget.width / 2 - widget.parent.width / 2) <= 1)
        compare(widget.height, bar.barSize)

        verify(bar.summonBarWidget("gshulga.island"))
        verify(bar.isBarWidgetOpen("gshulga.island"))
        const popup = findChild(widget, "islandPopup")
        verify(!!popup && popup.pinned)
        verify(bar.hideBarWidget("gshulga.island"))
        verify(!bar.isBarWidgetOpen("gshulga.island"))
        const clock = findChild(widget, "islandClock")
        mouseClick(clock)
        verify(widget.pinned, "Clicking the clock must pin the popup")
        mouseClick(clock)
        verify(!widget.pinned, "Clicking the clock again must dismiss the popup")

        const handlers = IpcRegistry.handlers.filter(handler => handler.target === "island" && handler.enabled)
        compare(handlers.length, 1, "IPC should be shared across outputs")
        verify(IpcRegistry.call("island", "open", []).ran)
        verify(JSON.parse(IpcRegistry.call("island", "status", []).output).pinned)
        verify(IpcRegistry.call("island", "close", []).ran)

        widget.updateSetting("hoverDelay", 300)
        compare(host.config.layout.right[0].hoverDelay, 300)
        host.config = { position: "left", layout: { center: [
          { id: "gshulga.island", hoverDelay: 450, verticalFormat: "HH\nmm", weatherEnabled: false }
        ] } }
        tryCompare(widget, "configuredFormat", "HH\nmm")
        compare(widget.settings.hoverDelay, 450)
        tryCompare(widget, "width", bar.barSize)
        verify(Math.abs(widget.y + widget.height / 2 - widget.parent.height / 2) <= 1)

        verify(bar.summonBarWidget("gshulga.island"))
        bar.barHidden = true
        verify(!widget.visible && !widget.pinned)
        bar.barHidden = false
        verify(widget.visible)
        console.log("ISLAND_NATIVE_BAR_PASS")
      } catch (error) {
        console.log("ISLAND_NATIVE_BAR_FAIL", String(error), error.stack)
      }
      Qt.quit()
    }
  }
  Timer { interval: 250; running: true; onTriggered: test.run() }
}
