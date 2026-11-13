.pragma library

// Move focus before removing an active item from Qt's Tab chain.
function sync(item, interactive) {
  if (!interactive && item.activeFocus) {
    var next = item.nextItemInFocusChain(true)
    if (next && next !== item && next.activeFocusOnTab && next.enabled && next.visible)
      next.forceActiveFocus(Qt.TabFocusReason)
    else
      item.focus = false
  }
  item.activeFocusOnTab = interactive
}
