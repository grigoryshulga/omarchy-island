// QML-compatible surface picking. No pointer handlers: input stays with the UI.
function radius(item) {
  return Math.max(0, Math.min(typeof item.effectiveRadius === "number" ? item.effectiveRadius : typeof item.radius === "number" ? item.radius : 0,
                              item.width / 2, item.height / 2))
}
function power(item) {
  return typeof item.roundingPower === "number" ? Math.max(1,Math.min(10,item.roundingPower)) : 2
}
function contains(item, point, rounded) {
  if (point.x < 0 || point.y < 0 || point.x >= item.width || point.y >= item.height) return false
  var r = rounded ? radius(item) : 0
  var x = Math.max(r - point.x, point.x - (item.width - r), 0)
  var y = Math.max(r - point.y, point.y - (item.height - r), 0)
  var p=power(item)
  return r===0 || Math.pow(x/r,p)+Math.pow(y/r,p)<=1
}
function pick(item, source, point) {
  if (!item || !item.visible || !item.enabled || item.opacity <= 0) return null
  var local = item.mapFromItem(source, point.x, point.y)
  if (item.clip && !contains(item, local, false)) return null
  var children = item.islandSpotlightLeaf === true ? [] : Array.prototype.slice.call(item.children || [])
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
function edgeAt(point, rect, corner, exponent) {
  var halfX = rect.width / 2, halfY = rect.height / 2
  var r = Math.max(0, Math.min(corner, halfX, halfY))
  var x = point.x - rect.x - halfX, y = point.y - rect.y - halfY
  var qx = Math.abs(x) - halfX + r, qy = Math.abs(y) - halfY + r
  var ox = Math.max(qx, 0), oy = Math.max(qy, 0)
  var p=exponent || 2
  var scale=Math.max(ox,oy)
  var length=scale>0 ? scale*Math.pow(Math.pow(ox/scale,p)+Math.pow(oy/scale,p),1/p) : 0
  var gx=length>0 ? Math.pow(ox/length,p-1) : 0
  var gy=length>0 ? Math.pow(oy/length,p-1) : 0
  var normalLength=Math.sqrt(gx*gx+gy*gy)
  var nx = length > 0 ? gx / normalLength : qx > qy ? 1 : 0
  var ny = length > 0 ? gy / normalLength : qx > qy ? 0 : 1
  nx *= x < 0 ? -1 : 1
  ny *= y < 0 ? -1 : 1
  return {distance: length + Math.min(Math.max(qx, qy), 0) - r, nx: nx, ny: ny}
}
function collision(previous, point, rect, corner, reach, exponent) {
  if (rect.width <= 0 || rect.height <= 0 || reach <= 0) return null
  // Small buttons need an inner region from which a collision can approach.
  var threshold = Math.min(reach, Math.min(rect.width, rect.height) * 0.24)
  var before = edgeAt(previous, rect, corner, exponent), now = edgeAt(point, rect, corner, exponent)
  var approach = (point.x - previous.x) * now.nx + (point.y - previous.y) * now.ny
  if (before.distance >= -threshold || now.distance < -threshold || now.distance > 0 || approach <= 0) return null
  return {x: point.x - now.nx * (now.distance + 2),
          y: point.y - now.ny * (now.distance + 2), nx: now.nx, ny: now.ny}
}

// Nearby rims share the cursor light without making layout wrappers surfaces.
// Fully clipped/partly clipped cards are omitted rather than inventing a rim
// along the viewport cut. Four uniforms bound the per-pixel shader work.
function neighbors(root, source, point, reach) {
  var found = []
  function visit(item, clip) {
    if (!item || !item.visible || !item.enabled || item.opacity <= 0) return
    var at = item.mapToItem(source, 0, 0)
    var rect = {x: at.x, y: at.y, width: item.width, height: item.height}
    var right = at.x + item.width, bottom = at.y + item.height
    if (clip && (right <= clip.x || bottom <= clip.y || at.x >= clip.right || at.y >= clip.bottom)) return
    if (item.clip) {
      clip = {x: Math.max(at.x, clip ? clip.x : at.x), y: Math.max(at.y, clip ? clip.y : at.y),
              right: Math.min(right, clip ? clip.right : right), bottom: Math.min(bottom, clip ? clip.bottom : bottom)}
    }
    var surface = item.islandSpotlightSurface === true ||
                  (typeof item.clicked === "function" && typeof item.radius === "number")
    if (surface && item.width > 0 && item.height > 0 &&
        (!clip || (at.x >= clip.x && at.y >= clip.y && right <= clip.right && bottom <= clip.bottom))) {
      var r = radius(item), distance = edgeAt(point, rect, r, power(item)).distance
      // Excludes the hovered surface and enclosing cards, avoiding stacked rims.
      if (distance > 0 && distance < reach) found.push({rect: rect, radius: r, power: power(item), distance: distance})
    }
    if (item.islandSpotlightLeaf === true) return
    var children = item.children || []
    for (var i = 0; i < children.length; ++i) visit(children[i], clip)
  }
  visit(root, null)
  found.sort(function(a, b) { return a.distance - b.distance })
  return found.slice(0, 4)
}
