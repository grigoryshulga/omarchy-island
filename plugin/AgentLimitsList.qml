import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import qs.Commons
import "sdk" as UI
import "AgentLimitsModel.js" as Model

Column {
  id: root
  required property var backend
  required property var strings
  property var feedback: null
  property bool editing: false
  property string draggingId: ""
  property string beforeId: ""
  property point pointerPosition: Qt.point(0, 0)
  property bool canceled: false
  signal editProvider(string id)
  function focusProvider(id) {
    for (var i = 0; i < groups.count; i++) {
      var group = groups.itemAt(i)
      if (!id || group.providerId === id) { group.focusEditor(); return }
    }
  }

  function cancelDrag() {
    if (!draggingId) return false
    canceled = true
    draggingId = ""
    return true
  }
  function track(position) {
    pointerPosition = position
    var point = root.mapFromItem(null, position.x, position.y)
    beforeId = ""
    for (var i = 0; i < groups.count; i++) {
      var item = groups.itemAt(i)
      if (item.providerId !== draggingId && point.y < item.y + item.height / 2) {
        beforeId = item.providerId
        break
      }
    }
  }
  function moveBy(id, direction) {
    var ids = providers.map(function(p) { return p.id }), index = ids.indexOf(id)
    if (index < 0 || index + direction < 0 || index + direction >= ids.length) return
    backend.moveProvider(id, direction < 0 ? ids[index - 1] : ids[index + 2] || "")
  }
  // Use the host viewport, preserving the stable Wayland surface while dragging.
  Timer {
    interval: 30; repeat: true; running: root.draggingId !== "" && root.visible
    onTriggered: {
      var viewport = root.parent
      while (viewport && !("contentY" in viewport)) viewport = viewport.parent
      if (!viewport) return
      var point = viewport.mapFromItem(null, root.pointerPosition.x, root.pointerPosition.y)
      var step = point.y < Style.space(40) ? -Style.space(12) : point.y > viewport.height - Style.space(40) ? Style.space(12) : 0
      viewport.contentY = Math.max(0, Math.min(Math.max(0, viewport.contentHeight - viewport.height), viewport.contentY + step))
      root.track(root.pointerPosition)
    }
  }
  readonly property var providers: backend ? backend.cache.providers : []
  signal settingRequested(string key, var value)

  spacing: Design.gap.medium
  LayoutMirroring.enabled: Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit: true
  onVisibleChanged: if (!visible) cancelDrag()
  onEditingChanged: if (!editing) cancelDrag()
  onProvidersChanged: syncProviders()
  Component.onCompleted: syncProviders()

  function syncProviders() {
    var ids = providers.map(function(p) { return p.id })
    Model.syncIdentities(providerItems, ids, "providerId")
    // Move existing delegates after a persisted reorder, never recreate them.
    if (!draggingId) ids.forEach(function(id, at) {
      for (var i = at; i < providerItems.count; i++)
        if (providerItems.get(i).providerId === id) { if (i !== at) providerItems.move(i, at, 1); break }
    })
  }

  ListModel { id: providerItems }

  Repeater {
    id: groups
    model: providerItems
    AgentLimitsProviderGroup {
      id: group
      required property string providerId
      width: root.width
      provider: root.providers.find(function(p) { return p.id === providerId }) || ({id: providerId})
      rows: root.backend ? root.backend.rows.filter(function(row) { return row.providerId === providerId }) : []
      pins: root.backend ? root.backend.pins : []
      now: root.backend ? root.backend.now : 0
      editingPins: root.editing
      strings: root.strings
      feedback: root.feedback
      onEditRequested: root.editProvider(providerId)
      onMoveRequested: direction => root.moveBy(providerId, direction)
      opacity: drag.active && !root.canceled ? 0.65 : 1
      z: drag.active ? 1 : 0
      transform: Translate { y: drag.active && !root.canceled ? drag.translation.y : 0 }
      Item {
        width: parent.width; height: 0
        Rectangle {
          width: parent.width; height: Math.max(1, Style.space(2)); color: Design.accent
          visible: root.draggingId !== "" && root.beforeId === group.providerId
        }
      }
      DragHandler {
        id: drag
        enabled: root.editing && !!root.backend && !root.backend.busy
        target: null
        xAxis.enabled: false
        onActiveChanged: {
          if (active) { root.canceled = false; root.draggingId = group.providerId; root.track(centroid.scenePosition) }
          else {
            if (!root.canceled && root.draggingId) root.backend.moveProvider(group.providerId, root.beforeId)
            root.draggingId = ""
          }
        }
        onCentroidChanged: if (active) root.track(centroid.scenePosition)
      }
      onPinsRequested: pins => root.settingRequested("agentLimitsPins", pins)
    }
  }

  Rectangle {
    width: parent.width; height: Math.max(1, Style.space(2)); color: Design.accent
    visible: root.draggingId !== "" && root.beforeId === ""
  }

  UI.DataState {
    visible: root.providers.length === 0
    width: parent.width
    title: root.strings.t("limits.noWindows")
  }
}
