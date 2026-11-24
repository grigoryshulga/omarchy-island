import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "." as Island
import "PanelGeometry.js" as Geometry
import "SettingsModel.mjs" as Settings
import "DesignTokens.js" as Tokens

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
  readonly property string position: Geometry.positions.includes(barConfig.position) ? barConfig.position : "top"
  readonly property bool vertical: Geometry.vertical(position)
  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property string panelShape: Settings.get(islandSettings, "panelShape")
  readonly property string panelBackground: Settings.get(islandSettings, "panelBackground")
  readonly property int edgeInset: panelShape === "pill" ? Style.space(6) : 0
  readonly property int panelSize: barSize + edgeInset
  readonly property var screenBarSizes: {
    const sizes = {}
    for (const screen of Quickshell.screens) sizes[screen.name] = panelSize
    return sizes
  }
  readonly property string fontFamily: Style.font.family
  readonly property color barForeground: panelBackground === "oledBlack"
    ? Design.color(Tokens.readable(Commons.Color.bar.text, background, 7)) : Commons.Color.bar.text
  readonly property color foreground: barForeground
  readonly property color background: {
    const theme = Commons.Color.bar.background
    switch (panelBackground) {
    case "oledBlack": return "black"
    case "transparent": return Qt.rgba(theme.r, theme.g, theme.b, 0)
    case "hyprland": return Qt.rgba(theme.r, theme.g, theme.b, hyprlandOpacity)
    default: return theme
    }
  }
  readonly property color urgent: Commons.Color.bar.active
  readonly property bool foregroundAnimationEnabled: !Style.reduceMotion

  property bool barHidden: false
  property real hyprlandOpacity: 1
  property var activePopout: null
  property Item tooltipTarget: null
  property string tooltipText: ""

  function setPosition(edge) {
    if (shell && edge !== position && Geometry.positions.includes(edge))
      shell.mutateShellConfig(config => { config.bar.position = edge })
  }

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
  IslandIpc { widget: root.islandForIpc() }

  function refreshOpacity() {
    if (panelBackground === "hyprland") opacityQuery.running = true
  }
  Component.onCompleted: refreshOpacity()
  onPanelBackgroundChanged: refreshOpacity()
  Process {
    id: opacityQuery
    command: ["hyprctl", "-j", "getoption", "decoration:active_opacity"]
    stdout: StdioCollector {
      onStreamFinished: root.hyprlandOpacity = Geometry.parseOpacity(text, root.hyprlandOpacity)
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "fullscreen") Hyprland.refreshToplevels()
      if (event && event.name === "configreloaded") root.refreshOpacity()
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
      readonly property bool showingPill: !root.barHidden && !fullscreen
      onShowingPillChanged: if (!showingPill) island.close()

      screen: modelData
      visible: !root.barHidden && !remap.remapping
      color: "transparent"
      anchors {
        top: root.vertical || root.position === "top"
        bottom: root.vertical || root.position === "bottom"
        left: !root.vertical || root.position === "left"
        right: !root.vertical || root.position === "right"
      }
      implicitWidth: root.vertical ? root.panelSize : 0
      implicitHeight: root.vertical ? 0 : root.panelSize
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: root.panelSize
      WlrLayershell.namespace: "omarchy-bar"
      WlrLayershell.layer: WlrLayer.Top
      mask: Region { item: pill.visible && island.pillInteractive ? pill : null }

      ScreenMoveRemap { id: remap; window: panel }

      Rectangle {
        objectName: "islandBarBackdrop"
        anchors.fill: parent
        visible: root.panelShape === "bar" && pill.visible
        opacity: pill.opacity
        color: root.background
      }

      Item {
        id: pill
        objectName: "islandPill"
        width: root.vertical ? root.barSize : Math.min(parent.width, Math.ceil(island.implicitWidth))
        height: root.vertical ? Math.min(parent.height, Math.ceil(island.implicitHeight)) : root.barSize
        x: root.vertical ? (root.position === "left" ? root.edgeInset : 0) : (parent.width - width) / 2
        y: root.vertical ? (parent.height - height) / 2 : (root.position === "top" ? root.edgeInset : 0)
        opacity: island.pillOpacity
        visible: panel.showingPill && opacity > 0

        ContainerSurface {
          anchors.fill: parent
          visible: root.panelShape === "pill"
          color: root.background
          radius: Design.cardRadius
        }

        Rectangle {
          objectName: "islandNotchBackdrop"
          anchors.fill: parent
          visible: root.panelShape === "notch"
          color: root.background
          radius: Design.cardRadius
          topLeftRadius: root.position === "top" || root.position === "left" ? 0 : radius
          topRightRadius: root.position === "top" || root.position === "right" ? 0 : radius
          bottomLeftRadius: root.position === "bottom" || root.position === "left" ? 0 : radius
          bottomRightRadius: root.position === "bottom" || root.position === "right" ? 0 : radius
        }

        Island.BarWidget {
          id: island
          bar: root
          service: Preferences.service
          standalone: true
          ipcEnabled: false
          anchors.fill: parent
          settings: root.islandSettings
          Connections {
            target: root
            // Local edits are immediate, then the shell broadcasts the saved
            // settings to every output.
            function onIslandSettingsChanged() { island.settings = root.islandSettings }
          }
        }
      }

      PopupWindow {
        visible: pill.visible && island.pillInteractive && root.tooltipText !== "" && !!root.tooltipTarget
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
          rect: Qt.rect(pill.x, pill.y, pill.width, pill.height)
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
