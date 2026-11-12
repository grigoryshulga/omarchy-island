// Screen-local popup placement. Clamp the destination rectangle before
// animating it so the card's cross-axis center does not drift near edges.
function vertical(position) { return position === "left" || position === "right" }
function available(position, sw, sh, thickness, margin) {
  return {width: Math.max(1, sw - 2 * margin - (vertical(position) ? thickness : 0)),
    height: Math.max(1, sh - 2 * margin - (vertical(position) ? 0 : thickness))}
}
function origin(position, sw, sh, thickness, margin, width, height, anchorX, anchorY) {
  var x = anchorX - width / 2, y = anchorY - height / 2
  if (position === "left") x = thickness + margin
  else if (position === "right") x = sw - thickness - margin - width
  else if (position === "bottom") y = sh - thickness - margin - height
  else y = thickness + margin
  return {x: Math.max(margin, Math.min(x, sw - width - margin)),
    y: Math.max(margin, Math.min(y, sh - height - margin))}
}
if (typeof module !== "undefined") module.exports = {vertical: vertical, available: available, origin: origin}
