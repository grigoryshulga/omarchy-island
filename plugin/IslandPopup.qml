import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PanelGeometry.js" as Geometry

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
  property bool bareCard:false
  property bool bareCardShown:false
  property bool frameSuppressed: false
  property string triggerMode: "hover"
  property bool centerOnBar: false
  property bool forwardAnchorClicks: true
  property bool morphFromAnchor: false
  property bool morphing: false
  readonly property bool animateMorph: Preferences.panelDuration(1) > 0
  readonly property real morphTarget: paintOpen && morphing ? 1 : 0
  property real animatedMorph: morphTarget
  readonly property real morphProgress: animateMorph ? animatedMorph : morphTarget
  readonly property bool replacingAnchor: morphing && (open || morphProgress > 0)
  readonly property real anchorCoverage: morphing ? Math.min(1, morphProgress * 5) : 0
  Behavior on animatedMorph {
    enabled: root.animateMorph
    NumberAnimation {
      duration: Preferences.panelDuration(root.paintOpen ? 280 : 240)
      easing.type: root.paintOpen ? Easing.Bezier : Easing.InOutCubic
      easing.bezierCurve: Style.easeOut
    }
  }
  property Item alignmentItem: anchorItem
  readonly property point anchorCenter: {
    anchorWatcher.transform
    return anchorWindow && alignmentItem ? alignmentItem.mapToItem(anchorWindow.contentItem,alignmentItem.width/2,alignmentItem.height/2) : Qt.point(width/2,height/2)
  }
  TransformWatcher { id: anchorWatcher; a: root.anchorWindow ? root.anchorWindow.contentItem : null; b: root.alignmentItem }
  property int padding: bareCardShown ? 0 : frameSuppressed ? Design.gap.small : Design.panelPadding
  property int margin: Style.gapsOut
  property int contentWidth: Style.space(420)
  property int contentHeight: Style.space(240)
  readonly property bool pinned: triggerMode === "click"
  readonly property bool containsMouse: cardHover.hovered
  readonly property point hoverPosition: cardHover.point.position
  signal backgroundClicked(point position)
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property real thickness: bar ? ("panelSize" in bar ? bar.panelSize : bar.barSize) : Style.bar.sizeHorizontal
  readonly property real availableWidth: Geometry.available(position,screen ? screen.width : 1920,screen ? screen.height : 1080,thickness,margin).width
  readonly property real availableHeight: Geometry.available(position,screen ? screen.width : 1920,screen ? screen.height : 1080,thickness,margin).height
  readonly property var borderSpec: Design.popupBorder
  readonly property real insetTop: padding+Border.top(borderSpec)
  readonly property real insetBottom: padding+Border.bottom(borderSpec)
  readonly property real insetLeft: padding+Border.left(borderSpec)
  readonly property real insetRight: padding+Border.right(borderSpec)
  property real settledWidth: contentWidth
  property real settledHeight: contentHeight
  // Keep the destination layout while hover/alert state clears on exit.
  property real layoutWidth: contentWidth
  property real layoutHeight: contentHeight
  readonly property real drawnWidth: morphing ? interpolate(anchorItem.width, settledWidth) : reveal.drawnWidth
  readonly property real drawnHeight: morphing ? interpolate(anchorItem.height, settledHeight) : reveal.drawnHeight
  property bool paintOpen: false
  property bool focusPrimed: false
  readonly property real shown: morphing ? morphProgress : reveal.shown
  // Reveal full-width content once the card is large enough to read it.
  readonly property real contentOpacity: morphing ? Math.max(0, (morphProgress - 0.93) / 0.07) : reveal.contentShown
  readonly property real entranceOffset: morphing ? 0 : reveal.offsetY
  readonly property color anchorColor: morphing && bar ? bar.background : Design.canvas
  readonly property color cardColor: morphing ? Qt.rgba(
    interpolate(anchorColor.r, Design.canvas.r), interpolate(anchorColor.g, Design.canvas.g),
    interpolate(anchorColor.b, Design.canvas.b), interpolate(anchorColor.a, Design.canvas.a)) : Design.canvas
  default property alias contents: contentHolder.data

  function interpolate(start, end) { return start + (end - start) * morphProgress }
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
      // Finish an in-flight transition from its current geometry when an
      // alert is replaced or the popup is reopened during the return.
      const resumingMorph = morphing && shown > 0
      if (shown <= 0) morphing = morphFromAnchor
      frameSuppressed=frameless
      bareCardShown=bareCard
      if (!resumingMorph) {
        settledWidth = contentWidth
        settledHeight = contentHeight
        layoutWidth = contentWidth
        layoutHeight = contentHeight
      }
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
  // Keep the toast's compact treatment through closing.
  onBareCardChanged:Qt.callLater(function(){if(root.open) root.bareCardShown=root.bareCard})
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
  Behavior on settledWidth { enabled: root.paintOpen && (root.morphing ? root.morphProgress > 0 : reveal.stretch >= 1); NumberAnimation { duration: Preferences.duration(200); easing.type: Easing.OutCubic } }
  Behavior on settledHeight { enabled: root.paintOpen && (root.morphing ? root.morphProgress > 0 : reveal.stretch >= 1); NumberAnimation { duration: Preferences.duration(200); easing.type: Easing.OutCubic } }
  PopupReveal {
    id: reveal
    open: root.paintOpen && !root.morphing
    targetWidth: root.settledWidth
    targetHeight: root.settledHeight
  }

  readonly property string position: bar ? bar.position : "top"
  readonly property point cardOrigin: {
    var sw = screen ? screen.width : root.width, sh = screen ? screen.height : root.height
    var destination = Geometry.origin(position,sw,sh,thickness,margin,layoutWidth,layoutHeight,
      centerOnBar ? sw/2 : anchorCenter.x,centerOnBar ? sh/2 : anchorCenter.y)
    var widthAtDestination = morphing ? settledWidth : drawnWidth
    var heightAtDestination = morphing ? settledHeight : drawnHeight
    var x = destination.x + (layoutWidth-widthAtDestination)/2
    var y = destination.y
    if (Geometry.vertical(position)) {
      x = position === "right" ? destination.x+layoutWidth-widthAtDestination : destination.x
      y += (layoutHeight-heightAtDestination)/2
    } else if (position === "bottom") y += layoutHeight-heightAtDestination
    if (morphing && anchorWindow) {
      // The anchor window is a thin strip. Translate its local rectangle to
      // the popup's output coordinates before interpolating the two cards.
      const anchorX = anchorCenter.x - anchorItem.width / 2 + (position === "right" ? sw - anchorWindow.width : 0)
      const anchorY = anchorCenter.y - anchorItem.height / 2 + (position === "bottom" ? sh - anchorWindow.height : 0)
      // Hold the screen-facing edge in place while the card grows inward.
      if (position === "left") x = anchorX
      else if (position === "right") x = anchorX + anchorItem.width - widthAtDestination
      else if (position === "bottom") y = anchorY + anchorItem.height - heightAtDestination
      else y = anchorY
      x = interpolate(anchorX, x)
      y = interpolate(anchorY, y)
    }
    return Qt.point(Math.round(x),Math.round(y))
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
        if (root.forwardAnchorClicks && target && root.anchorWindow && typeof target.triggerPress === "function") {
          var barX=mouse.x-(root.position==="right" ? root.width-root.anchorWindow.width : 0)
          var barY=mouse.y-(root.position==="bottom" ? root.height-root.anchorWindow.height : 0)
          var point=target.mapFromItem(root.anchorWindow.contentItem,barX,barY)
          if(target.contains(point)) {
            if (typeof target.triggerPressAt==="function") target.triggerPressAt(mouse.button,point)
            else target.triggerPress(mouse.button)
            return
          }
        }
        root.close()
      }
    }
    ContainerSurface {
      id: card
      objectName: "islandPopupCard"
      x: root.cardOrigin.x + (Geometry.vertical(root.position) ? (root.position === "right" ? -1 : 1)*root.entranceOffset : 0)
      y: root.cardOrigin.y + (Geometry.vertical(root.position) ? 0 : (root.position === "bottom" ? -1 : 1)*root.entranceOffset)
      width: root.drawnWidth
      height: root.drawnHeight
      color: root.cardColor
      Behavior on color { enabled: root.paintOpen && root.shown>0.99; ColorAnimation {duration: Preferences.duration(120)} }
      borderSpec: root.borderSpec
      radius: Design.cardRadius
      opacity: root.morphing ? root.anchorCoverage : root.shown
      clip: true
      // Empty parts of the card should never count as an outside click.
      MouseArea { objectName:"islandPopupBackground";anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: mouse => {if(mouse.button===Qt.RightButton) root.close();else root.backgroundClicked(Qt.point(mouse.x,mouse.y))} }
      Item {
        id: contentHolder
        x: (card.width-root.layoutWidth)/2+root.insetLeft
        y: root.insetTop
        opacity: root.contentOpacity
        transform: Translate { y: root.morphing ? Design.gap.tight * (1 - root.contentOpacity) : 0 }
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
