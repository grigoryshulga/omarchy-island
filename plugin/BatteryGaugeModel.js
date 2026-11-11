// Keep partial segments precise, including an empty battery and a full last cell.
function segmentFill(fraction, index, count) {
  var value = Number(fraction)
  if (!isFinite(value)) value = 0
  return Math.max(0, Math.min(1, Math.max(0, Math.min(1, value)) * count - index))
}

function leadingSegment(fraction, count) {
  var value = Number(fraction)
  if (!isFinite(value)) value = 0
  return Math.max(0, Math.min(count - 1, Math.ceil(value * count) - 1))
}

if (typeof module !== "undefined") {
  module.exports = { segmentFill: segmentFill, leadingSegment: leadingSegment }
}
