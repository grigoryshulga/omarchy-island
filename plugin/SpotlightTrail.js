// Retain a bounded path in memory. Samples outlive pointer motion, so the
// wake fades at its original positions instead of catching up under the head.
var lifetime = 720
function weight(age) {
  var t = Math.max(0, Math.min(1, age / lifetime))
  return 1 - t * t * (3 - 2 * t)
}
function advance(samples, previous, point, now) {
  var next = samples.filter(function(sample) { return now - sample.time < lifetime })
  var last = next.length ? next[next.length - 1] : null
  var anchor = last || previous
  var dx = point.x - anchor.x, dy = point.y - anchor.y
  if (dx * dx + dy * dy >= 1 && (!last || now - last.time >= 60)) {
    if (!last) next.push({x: previous.x, y: previous.y, time: now - 32})
    next.push({x: point.x, y: point.y, time: now})
  }
  return next.slice(-12)
}
