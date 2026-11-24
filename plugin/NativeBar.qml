import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "." as Island

Item {
  id: root

  property var shell: null
  property var barConfig: ({})

  readonly property string islandId: "gshulga.island"
  readonly property var islandSettings: {
    const layout = barConfig.layout || {}
    for (const section of Util.barSections) {
      const entries = Array.isArray(layout[section]) ? layout[section] : []
      for (const entry of entries) {
        if (entry === islandId) return { id: islandId }
        if (entry && entry.id === islandId) return entry
      }
    }
    return {}
  }
  readonly property string position: ["bottom", "left", "right"].includes(barConfig.position) ? barConfig.position : "top"
  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property var screenBarSizes: ({})
  readonly property string fontFamily: Style.font.family
  readonly property color barForeground: Commons.Color.bar.text
  readonly property color foreground: barForeground
  readonly property color background: Commons.Color.bar.background
  readonly property color urgent: Commons.Color.bar.active
  readonly property bool foregroundAnimationEnabled: !Style.reduceMotion

  property bool barHidden: false
  property var activePopout: null
  property Item tooltipTarget: null
  property string tooltipText: ""

  function requestPopout(owner) {
    if (activePopout && activePopout !== owner) activePopout.close()
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  function moduleWidgets(id) {
    return id === islandId ? panels.instances.map(panel => panel.widget) : []
  }

  function islandForIpc() {
    const widgets = moduleWidgets(islandId)
    const focusedScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    return widgets.find(widget => widget.opened)
      || widgets.find(widget => widget.screenName === focusedScreen)
      || widgets[0]
  }

  function summonBarWidget(id) {
    const widget = id === islandId ? islandForIpc() : null
    if (!widget) return false
    widget.open()
    return true
  }

  function hideBarWidget(id) {
    const widget = id === islandId ? islandForIpc() : null
    if (!widget) return false
    widget.close()
    return true
  }

  function isBarWidgetOpen(id) {
    const widget = id === islandId ? islandForIpc() : null
    return !!widget && widget.opened
  }

  // Embedded native panels use the same command interface as on the stock bar.
  function run(command) {
    if (command) Util.execDetached(command)
  }

  function showTooltip(target, text) {
    tooltipDelay.stop()
    tooltipTarget = target
    tooltipText = ""
    if (text) tooltipDelay.restart()
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target) return
    tooltipDelay.stop()
    tooltipTarget = null
    tooltipText = ""
  }

  Timer {
    id: tooltipDelay
    interval: 400
    onTriggered: if (root.tooltipTarget && root.tooltipTarget.tooltipHovered)
      root.tooltipText = root.tooltipTarget.tooltipText
  }

  Process {
    id: hiddenProbe
    running: true
    command: ["test", "-f", togglesFile.path + "/bar-off"]
    onExited: code => { root.barHidden = code === 0 }
  }

  FileView {
    id: togglesFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: hiddenProbe.running = true
  }

  ShellIpc {
    target: "omarchy.bar"
    function syncHidden(): void { hiddenProbe.running = true }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "fullscreen") Hyprland.refreshToplevels()
    }
  }

  Variants {
    id: panels
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      readonly property alias widget: island
      readonly property var monitor: Hyprland.monitorFor(screen)
      readonly property bool fullscreen: {
        const workspace = monitor ? monitor.activeWorkspace : null
        return !!workspace && Hyprland.toplevels.values.some(window =>
          window.workspace && window.workspace.id === workspace.id
          && window.lastIpcObject && (Number(window.lastIpcObject.fullscreen) & 2) !== 0)
      }

      screen: modelData
      visible: !root.barHidden && !remap.remapping
      color: "transparent"
      anchors {
        top: root.vertical || root.position === "top"
        bottom: root.vertical || root.position === "bottom"
        left: !root.vertical || root.position === "left"
        right: !root.vertical || root.position === "right"
      }
      implicitWidth: root.vertical ? root.barSize : 0
      implicitHeight: root.vertical ? 0 : root.barSize
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: root.barSize
      WlrLayershell.namespace: "omarchy-bar"
      WlrLayershell.layer: WlrLayer.Top
      mask: Region { item: island.visible ? island : null }

      ScreenMoveRemap { id: remap; window: panel }

      Rectangle {
        objectName: "islandBarBackground"
        anchors.fill: island
        visible: island.visible
        color: root.background
        radius: Math.min(Design.cardRadius, width / 2, height / 2)
      }

      Island.BarWidget {
        id: island
        bar: root
        service: Preferences.service
        anchors.centerIn: parent
        width: root.vertical ? parent.width : Math.min(parent.width, implicitWidth)
        height: root.vertical ? Math.min(parent.height, implicitHeight) : parent.height
        visible: !root.barHidden && !panel.fullscreen
        settings: root.islandSettings
        onVisibleChanged: if (!visible) close()
        Connections {
          target: root
          // Local edits are immediate, then the shell broadcasts the saved
          // settings to every output.
          function onIslandSettingsChanged() { island.settings = root.islandSettings }
        }
      }

      PopupWindow {
        visible: island.visible && root.tooltipText !== "" && !!root.tooltipTarget
          && root.tooltipTarget.QsWindow.window === island.QsWindow.window
        color: "transparent"
        implicitWidth: tooltip.implicitWidth
        implicitHeight: tooltip.implicitHeight
        anchor {
          id: tooltipAnchor
          window: panel
          adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
          edges: root.position === "bottom" ? Edges.Top : root.position === "left" ? Edges.Right
            : root.position === "right" ? Edges.Left : Edges.Bottom
          gravity: tooltipAnchor.edges
          rect: Qt.rect(island.x, island.y, island.width, island.height)
        }
        BorderSurface {
          id: tooltip
          implicitWidth: label.implicitWidth + 2 * Style.spacing.controlPaddingX
          implicitHeight: label.implicitHeight + 2 * Style.spacing.controlPaddingY
          color: Commons.Color.tooltip.background
          borderSpec: Border.surfaceSpec("tooltip", "border", Commons.Color.tooltip.border, 1)
          radius: Style.cornerRadius
          PlainText {
            id: label
            anchors.centerIn: parent
            typeRole: "caption"
            color: Commons.Color.tooltip.text
            text: root.tooltipText
          }
        }
      }
    }
  }
}
