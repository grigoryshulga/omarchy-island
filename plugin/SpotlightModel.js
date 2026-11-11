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

// Signed distance and outward normal of the same rounded box as the shader.
function edgeAt(point, rect, corner) {
  var halfX = rect.width / 2, halfY = rect.height / 2
  var r = Math.max(0, Math.min(corner, halfX, halfY))
  var x = point.x - rect.x - halfX, y = point.y - rect.y - halfY
  var qx = Math.abs(x) - halfX + r, qy = Math.abs(y) - halfY + r
  var ox = Math.max(qx, 0), oy = Math.max(qy, 0)
  var length = Math.sqrt(ox * ox + oy * oy)
  var nx = length > 0 ? ox / length : qx > qy ? 1 : 0
  var ny = length > 0 ? oy / length : qx > qy ? 0 : 1
  nx *= x < 0 ? -1 : 1
  ny *= y < 0 ? -1 : 1
  return {distance: length + Math.min(Math.max(qx, qy), 0) - r, nx: nx, ny: ny}
}
function collision(previous, point, rect, corner, reach) {
  if (rect.width <= 0 || rect.height <= 0 || reach <= 0) return null
  // Small buttons need an inner region from which a collision can approach.
  var threshold = Math.min(reach, Math.min(rect.width, rect.height) * 0.24)
  var before = edgeAt(previous, rect, corner), now = edgeAt(point, rect, corner)
  var approach = (point.x - previous.x) * now.nx + (point.y - previous.y) * now.ny
  if (before.distance >= -threshold || now.distance < -threshold || now.distance > 0 || approach <= 0) return null
  return {x: point.x - now.nx * (now.distance + 2),
          y: point.y - now.ny * (now.distance + 2), nx: now.nx, ny: now.ny}
}
