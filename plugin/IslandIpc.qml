import QtQuick
import qs.Commons

QtObject {
  id: root
  property bool enabled: true
  property var widget: null

  readonly property ShellIpc handler: ShellIpc {
    enabled: root.enabled
    target: "island"
    function open(): void { if (root.widget) root.widget.open() }
    function close(): void { if (root.widget) root.widget.close() }
    function settings(): void { if (root.widget) root.widget.openSettings() }
    function timers(): void { if (root.widget) root.widget.openModuleDetails("timers") }
    function controls(): void { if (root.widget) root.widget.openControls() }
    function calendar(): void { if (root.widget) root.widget.openCalendar() }
    function weather(): void { if (root.widget) root.widget.openWeather() }
    function toggle(): void { if (root.widget) root.widget.toggle() }
    function hover(): void { if (root.widget) root.widget.toggleHover() }
    function status(): string { return root.widget ? root.widget.ipcStatus() : "{}" }
  }
}
