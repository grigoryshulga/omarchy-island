import QtQuick
import QtQuick.Controls as Controls

// Native panel content in Island's existing surface. No extra Wayland window,
// global IPC or bar popout coordination; the native controller owns lifecycle.
Item {
  id: root
  property Item anchorItem: null
  property var owner: null
  property var bar: null
  property bool open: false
  property Item focusTarget: null
  property int contentWidth: width
  property int contentHeight: height
  property Component content: null
  property bool contentRequested: false
  property bool scrollContent: false
  readonly property Item loadedContent: loader.item
  readonly property real loadedContentHeight: loader.item ? loader.item.implicitHeight : 0
  default property alias contents: holder.data
  function ensureContent() { contentRequested=true;return loader.item }
  function fittedContentWidth(value,cap) { return cap>0 ? Math.min(value,cap) : value }
  function fittedContentHeight(value,cap) { return cap>0 ? Math.min(value,cap) : value }
  function focusContent() { if(open && focusTarget) focusTarget.forceActiveFocus() }
  onOpenChanged: if(open) {contentRequested=true;Qt.callLater(focusContent)}
  visible: open
  Item {
    id:holder
    anchors.fill:parent
    Flickable {
      id:viewport
      objectName:"inlinePanelViewport"
      anchors.fill:parent
      contentWidth:width
      contentHeight:root.scrollContent && loader.item ? Math.max(height,loader.item.implicitHeight) : height
      interactive:root.scrollContent && contentHeight>height
      flickableDirection:Flickable.VerticalFlick
      boundsBehavior:Flickable.StopAtBounds
      clip:true
      Controls.ScrollBar.vertical:Controls.ScrollBar {policy:root.scrollContent ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff}
      Loader {
      id:loader
      width:viewport.width
      height:viewport.contentHeight
      active:!!root.content && (root.open || root.contentRequested)
      sourceComponent:root.content
      focus:true
      onLoaded:Qt.callLater(root.focusContent)
      }
    }
  }
}
