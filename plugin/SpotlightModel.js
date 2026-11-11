// QML-compatible surface picking. No pointer handlers: input stays with the UI.
function radius(item) {
  return Math.max(0, Math.min(typeof item.radius === "number" ? item.radius : 0,
                              item.width / 2, item.height / 2))
}
function contains(item, point, rounded) {
  if (point.x < 0 || point.y < 0 || point.x >= item.width || point.y >= item.height) return false
  var r = rounded ? radius(item) : 0
  var x = Math.max(r - point.x, point.x - (item.width - r), 0)
  var y = Math.max(r - point.y, point.y - (item.height - r), 0)
  return x * x + y * y <= r * r
}
function pick(item, source, point) {
  if (!item || !item.visible || !item.enabled || item.opacity <= 0) return null
  var local = item.mapFromItem(source, point.x, point.y)
  if (item.clip && !contains(item, local, false)) return null
  var children = Array.prototype.slice.call(item.children || [])
  children.sort(function(a, b) { return a.z - b.z })
  for (var i = children.length - 1; i >= 0; --i) {
    var found = pick(children[i], source, point)
    if (found) return found
  }
  // qs.Ui buttons (including adapted native panels) expose clicked and radius.
  var surface = item.islandSpotlightSurface === true ||
                (typeof item.clicked === "function" && typeof item.radius === "number")
  return surface && contains(item, local, true) ? item : null
}
