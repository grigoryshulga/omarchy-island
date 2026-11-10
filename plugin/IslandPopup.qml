import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Keep the Wayland surface fixed. Only the card changes geometry, so the
// compositor never has to negotiate buffers during a preview expansion.
PanelWindow {
  id: root
  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  readonly property string entranceStyle: "seed-drop-stretch"
  property bool open: false
  property bool frameless: false
  property bool frameSuppressed: false
  property string triggerMode: "hover"
  property bool centerOnBar: true
  property int padding: frameSuppressed ? Style.space(6) : Style.spacing.popupPadding
  property int margin: Style.gapsOut
  property int contentWidth: Style.space(420)
  property int contentHeight: Style.space(240)
  readonly property bool pinned: triggerMode === "click"
  readonly property bool containsMouse: cardHover.hovered
  readonly property point hoverPosition: cardHover.point.position
  signal backgroundClicked(point position)
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property real thickness: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property real availableWidth: Math.max(120,(screen ? screen.width : 1920)-2*margin)
  readonly property real availableHeight: Math.max(120,(screen ? screen.height : 1080)-thickness-2*margin)
  readonly property var borderSpec: frameSuppressed ? Border.none() : Border.surfaceSpec("popups","border",Commons.Color.popups.border,Math.max(1,Style.space(2)))
  readonly property real insetTop: padding+Border.top(borderSpec)
  readonly property real insetBottom: padding+Border.bottom(borderSpec)
  readonly property real insetLeft: padding+Border.left(borderSpec)
  readonly property real insetRight: padding+Border.right(borderSpec)
  property real settledWidth: contentWidth
  property real settledHeight: contentHeight
  // Keep the destination layout while hover/alert state clears on exit.
  property real layoutWidth: contentWidth
  property real layoutHeight: contentHeight
  readonly property real drawnWidth: reveal.drawnWidth
  readonly property real drawnHeight: reveal.drawnHeight
  property bool paintOpen: false
  property bool focusPrimed: false
  readonly property real shown: reveal.shown
  default property alias contents: contentHolder.data

  function fittedContentWidth(value) { return Math.round(Math.min(availableWidth,Math.max(1,value))) }
  function fittedContentHeight(value) { return Math.round(Math.min(availableHeight,Math.max(1,value)+insetTop+insetBottom)) }
  function close() { if (owner && typeof owner.close === "function") owner.close(); else open = false }

  screen: anchorWindow ? anchorWindow.screen : null
  anchors { top: true; bottom: true; left: true; right: true }
  implicitWidth: screen ? screen.width : 1920
  implicitHeight: screen ? screen.height : 1080
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omarchy-island-popup"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open && pinned
    ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None
  visible: open || shown > 0
  // Hover previews only take input over the card; a pinned panel also gets
  // outside clicks for dismissal. The closing fade takes no input.
  mask: Region { item: !root.open ? null : root.pinned ? canvas : card }

  function syncLayout() {
    // Hover/alert flags also choose the requested size. Wait for the whole
    // state change before accepting dimensions, so closing cannot resize us.
    if(!open) return
    settledWidth = contentWidth; layoutWidth = contentWidth
    settledHeight = contentHeight; layoutHeight = contentHeight
  }
  onContentWidthChanged: Qt.callLater(syncLayout)
  onContentHeightChanged: Qt.callLater(syncLayout)
  onOpenChanged: {
    if (open) {
      frameSuppressed=frameless
      settledWidth = contentWidth
      settledHeight = contentHeight
      layoutWidth = contentWidth
      layoutHeight = contentHeight
      Qt.callLater(syncLayout)
      if (bar) bar.requestPopout(owner || root)
      // Wait for the actual output-sized Wayland configure before painting;
      // the provisional 500x500 surface must never flash on the first frame.
      Qt.callLater(revealWhenConfigured)
    } else {
      paintOpen = false
      if (bar && bar.activePopout === (owner || root)) bar.releasePopout(owner || root)
    }
    primeFocus()
  }
  // Keep the toast's compact, borderless treatment through closing.
  onFramelessChanged: Qt.callLater(function(){if(root.open) root.frameSuppressed=root.frameless})
  onPinnedChanged: primeFocus()
  onWidthChanged: revealWhenConfigured()
  onHeightChanged: revealWhenConfigured()
  onBackingWindowVisibleChanged: revealWhenConfigured()
  function revealWhenConfigured() {
    if (open && backingWindowVisible && screen && width === screen.width && height === screen.height) paintOpen = true
  }
  function primeFocus() {
    if (open && pinned) { focusPrimed = false; focusPrime.restart() }
    else { focusPrime.stop(); focusPrimed = false }
  }
  Timer { id: focusPrime; interval: 75; onTriggered: root.focusPrimed = true }
  Behavior on settledWidth { enabled: root.paintOpen && reveal.stretch >= 1; NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
  Behavior on settledHeight { enabled: root.paintOpen && reveal.stretch >= 1; NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
  PopupReveal {
    id: reveal
    open: root.paintOpen
    targetWidth: root.settledWidth
    targetHeight: root.settledHeight
  }

  readonly property string position: bar ? bar.position : "top"
  readonly property point cardOrigin: {
    var sw = screen ? screen.width : root.width, sh = screen ? screen.height : root.height
    var x = (sw-drawnWidth)/2, y = thickness+margin
    if (position === "bottom") y = sh-thickness-margin-drawnHeight
    if (position === "left") { x = thickness+margin; y = (sh-drawnHeight)/2 }
    if (position === "right") { x = sw-thickness-margin-drawnWidth; y = (sh-drawnHeight)/2 }
    return Qt.point(Math.round(Math.max(margin,Math.min(x,sw-drawnWidth-margin))),Math.round(Math.max(margin,Math.min(y,sh-drawnHeight-margin))))
  }
  Item {
    id: canvas
    anchors.fill: parent
    MouseArea {
      objectName: "islandOutside"
      anchors.fill: parent
      enabled: root.open && root.pinned
      acceptedButtons: Qt.AllButtons
      onClicked: mouse => {
        var target=root.anchorItem
        if (target && root.anchorWindow && typeof target.triggerPress === "function") {
          var point=target.mapToItem(root.anchorWindow.contentItem,0,0)
          if(mouse.x>=point.x && mouse.y>=point.y && mouse.x<=point.x+target.width && mouse.y<=point.y+target.height) { target.triggerPress(mouse.button); return }
        }
        root.close()
      }
    }
    BorderSurface {
      id: card
      objectName: "islandPopupCard"
      x: root.cardOrigin.x
      y: root.cardOrigin.y + (root.position === "bottom" ? -1 : 1)*reveal.offsetY
      width: root.drawnWidth
      height: root.drawnHeight
      color: Commons.Color.popups.background
      Behavior on color { enabled: root.paintOpen && root.shown>0.99; ColorAnimation {duration: Style.duration(120)} }
      borderSpec: root.borderSpec
      radius: Math.min(Style.cornerRadius,width/2,height/2)
      opacity: root.shown
      clip: true
      // Empty parts of the card should never count as an outside click.
      MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: mouse => root.backgroundClicked(Qt.point(mouse.x,mouse.y)) }
      Item {
        id: contentHolder
        x: (card.width-root.layoutWidth)/2+root.insetLeft
        y: root.insetTop
        opacity: reveal.contentShown
        // Measure content at its destination width. No re-wrapping on every
        // animation frame, and no size/height feedback loop through the host.
        width: Math.max(1,root.layoutWidth-root.insetLeft-root.insetRight)
        height: Math.max(1,root.layoutHeight-root.insetTop-root.insetBottom)
        LayoutMirroring.enabled: Commons.I18n.rightToLeft
        LayoutMirroring.childrenInherit: true
      }
      HoverHandler { id: cardHover }
    }
  }
}
