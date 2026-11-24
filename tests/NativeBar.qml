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
        { id: "gshulga.island", format: "HH:mm", hoverDelay: 120, weatherEnabled: false, notificationDuration: 1000 }
      ] }
    })

    function updateEntryInline(id, entry) {
      if (id !== "gshulga.island") return false
      config = { position: config.position, layout: { right: [entry] } }
      return true
    }
    function mutateShellConfig(mutate) {
      const next = {bar: JSON.parse(JSON.stringify(config))}
      mutate(next)
      config = next.bar
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
        const pill = widget.parent
        const strip = pill.parent
        tryVerify(() => pill.width > 0 && pill.height > 0, 1000)
        verify(Math.abs(pill.x + pill.width / 2 - strip.width / 2) <= 1)
        verify(pill.y > 0 && pill.y + pill.height === strip.height)
        const compactWidth = pill.width
        widget.updateSetting("format", "dddd d MMMM yyyy HH:mm")
        tryVerify(() => pill.width > compactWidth + 30)
        widget.updateSetting("format", "HH:mm")
        tryCompare(pill, "width", compactWidth)
        verify(service.indicators.showOsd('{"icon":"audio-volume-high","value":50,"max":100}'))
        tryVerify(() => pill.width > compactWidth + 30)
        service.indicators.hideOsd()
        tryCompare(pill, "width", compactWidth)

        const popup = findChild(widget, "islandPopup")
        const clock = findChild(widget, "islandClock")
        mouseClick(clock)
        verify(widget.pinned, "Clicking the clock must pin the popup")
        verify(popup.pinned)
        tryVerify(() => popup.drawnWidth > compactWidth && popup.drawnWidth < popup.layoutWidth - 2)
        tryCompare(popup, "shown", 1)
        compare(pill.opacity, 0)
        compare(findChild(popup.contentItem, "islandPopupCard").y, pill.y)
        const outside = findChild(popup.contentItem, "islandOutside")
        mouseClick(outside, 2, 2)
        verify(!widget.pinned, "Clicking outside the capsule popup should dismiss it")
        tryCompare(pill, "opacity", 1)
        tryCompare(popup, "visible", false)
        compare(pill.width, compactWidth)

        widget.toggleHover()
        tryCompare(popup, "shown", 1)
        compare(pill.opacity, 1, "Hover preview should keep the clock visible")
        widget.toggleHover()
        tryCompare(popup, "visible", false)

        service.latestDownload = {
          key: "download-fixture", app: "Island", summary: "Download fixture",
          body: "Ready to open", ts: Date.now() / 1000, downloadPath: "/tmp/example.zip",
          filename: "example.zip", active: false, downloadedBytes: 1024
        }
        service.downloadAlert = true
        service.downloadTargetScreen = widget.screenName
        service.arrival++
        verify(!widget.pinned && popup.open, "The notification should open its own card")
        tryVerify(() => popup.drawnWidth > compactWidth && popup.drawnWidth < popup.layoutWidth - 2)
        tryCompare(popup, "shown", 1)
        compare(pill.opacity, 0)
        for (const other of bar.moduleWidgets("gshulga.island")) {
          if (other !== widget) compare(other.parent.opacity, 1)
        }
        tryCompare(popup, "open", false)
        tryVerify(() => popup.drawnWidth > compactWidth && popup.drawnWidth < popup.layoutWidth - 2)
        const returningWidth = popup.drawnWidth
        service.arrival++
        verify(Math.abs(popup.drawnWidth - returningWidth) <= 1,
          "Reopening changed the width from " + returningWidth + " to " + popup.drawnWidth)
        tryCompare(popup, "shown", 1)
        tryCompare(popup, "open", false)
        tryCompare(pill, "opacity", 1)
        tryCompare(popup, "visible", false)

        const handlers = IpcRegistry.handlers.filter(handler => handler.target === "island" && handler.enabled)
        compare(handlers.length, 1, "IPC should be shared across outputs")
        verify(IpcRegistry.call("island", "open", []).ran)
        verify(JSON.parse(IpcRegistry.call("island", "status", []).output).pinned)
        verify(IpcRegistry.call("island", "close", []).ran)

        widget.updateSetting("hoverDelay", 300)
        compare(host.config.layout.right[0].hoverDelay, 300)
        widget.updateSetting("verticalFormat", "HH\nmm")
        widget.openSettings()
        tryVerify(() => !!Island.IslandSettingsWindow.view)
        const settings = Island.IslandSettingsWindow.view
        findChild(settings, "settingsTab-panel").clicked()
        const placement = findChild(settings, "setting-panelPosition")
        verify(!!placement, "Panel settings should offer an edge selector")
        compare(placement.value, "top")
        placement.changed("left")
        tryCompare(widget, "configuredFormat", "HH\nmm")
        compare(host.config.position, "left")
        compare(widget.settings.hoverDelay, 300)
        tryVerify(() => pill.x > 0 && pill.x + pill.width === strip.width)
        verify(Math.abs(pill.y + pill.height / 2 - strip.height / 2) <= 1)
        Island.IslandSettingsWindow.close()

        Style.reduceMotion = true
        verify(bar.summonBarWidget("gshulga.island"))
        tryCompare(popup, "shown", 1)
        compare(pill.opacity, 0)
        verify(bar.hideBarWidget("gshulga.island"))
        compare(pill.opacity, 1)
        compare(popup.visible, false)

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
