import QtQuick
import QtQuick.Controls as Controls

// KeyboardPanel's content contract, hosted in Island's existing surface.
Item {
  id: root
  property Item anchorItem: null
  property var owner: null
  property var bar: null
  property var islandHost: null
  property var page: null
  property bool open: false
  property Item focusTarget: null
  property int padding: 0
  property int margin: 0
  property int gap: 0
  property bool centerOnBar: false
  property var borderSpec: null
  property int contentWidth: width
  property int contentHeight: height
  property bool islandContentWidthHint: false
  property bool islandContentHeightHint: false
  property Component content: null
  property bool contentRequested: false
  // Other panels own their scroll areas and reveal keyboard selections there.
  // Network lays out its header and sections in a plain Column.
  readonly property bool scrollContent: page && page.moduleName === "omarchy.network"
  readonly property Item loadedContent: loader.item
  readonly property real loadedContentHeight: loader.item ? loader.item.implicitHeight : 0
  default property alias contents: holder.data

  function ensureContent() { contentRequested = true; return loader.item }
  function fittedContentWidth(value, cap) { return Math.min(width, cap > 0 ? Math.min(value, cap) : value) }
  function fittedContentHeight(value, cap) { return Math.min(height, cap > 0 ? Math.min(value, cap) : value) }
  function focusContent() { if (open && focusTarget) focusTarget.forceActiveFocus() }
  onOpenChanged: if (open) { contentRequested = true; Qt.callLater(focusContent) }
  onLoadedContentHeightChanged: if (page) page.inlineContentHeight = loadedContentHeight
  onPageChanged: if (page) page.inlineContentHeight = loadedContentHeight
  visible: open
  Item {
    id: holder
    anchors.fill: parent
    Flickable {
      id: viewport
      objectName: "inlinePanelViewport"
      anchors.fill: parent
      contentWidth: width
      contentHeight: root.scrollContent ? Math.max(height, root.loadedContentHeight) : height
      interactive: root.scrollContent && contentHeight > height
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
      Loader {
        id: loader
        width: viewport.width
        height: viewport.contentHeight
        active: !!root.content && (root.open || root.contentRequested)
        sourceComponent: root.content
        focus: true
        onLoaded: Qt.callLater(root.focusContent)
      }
    }
  }
}
