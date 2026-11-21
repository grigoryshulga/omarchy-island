import QtQuick

// Qt writes "value" through QAccessibleValueInterface. This focus target owns
// that writable property so an AT edit preserves the host's backend binding.
// Both IslandSlider and Omarchy PanelSlider expose the same interaction API.
Item {
  id: root
  required property var slider
  anchors.fill: parent
  readonly property bool islandHandlesHorizontalKeys: true
  Accessible.role: Accessible.Slider
  Accessible.focusable: true
  readonly property real minimumValue: slider.minimum
  readonly property real maximumValue: slider.maximum
  readonly property real stepSize: slider.step
  readonly property real displayedValue: slider.liveValue
  property real value: 0
  Component.onCompleted: value = displayedValue
  onDisplayedValueChanged: value = displayedValue
  onValueChanged: {
    if (value === displayedValue) return
    commit(value)
    value = displayedValue
  }

  function commit(requested) {
    if (!enabled || !visible || !isFinite(requested)) return
    var next = Math.max(minimumValue, Math.min(maximumValue, slider.integer ? Math.round(requested) : requested))
    slider.liveValue = next
    slider.moved(next)
    slider.released(next)
  }

  Keys.onPressed: event => {
    if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier)) {
      event.accepted = false
      return
    }
    var text = String(event.text || "").toLowerCase()
    var forward = event.key === Qt.Key_Right || text === "l" || text === "д"
    var back = event.key === Qt.Key_Left || text === "h" || text === "р"
    if (forward || back) commit(displayedValue + ((forward !== LayoutMirroring.enabled) ? stepSize : -stepSize))
    else if (event.key === Qt.Key_Home) commit(minimumValue)
    else if (event.key === Qt.Key_End) commit(maximumValue)
    else { event.accepted = false; return }
    event.accepted = true
  }
}
