// Canonical Island primitives. QML consumes these directly; Node is only tooling.
var typography = {
  caption: {source: "body", size: 12, line: 16, weight: 400},
  label: {source: "subtitle", size: 13, line: 20, weight: 500},
  body: {source: "title", size: 14, line: 20, weight: 400},
  title: {source: "title", size: 14, line: 20, weight: 600},
  section: {source: "heading", size: 16, line: 24, weight: 600},
  page: {source: "display", size: 24, line: 32, weight: 600},
  metric: {source: "displayLarge", size: 28, line: 36, weight: 500},
  hero: {source: "displayLarge", factor: 1.5, size: 42, line: 48, weight: 600},
  bar: {source: "body", size: 12, line: 16, weight: 400}
}
var spacing = {micro: 2, tight: 4, small: 8, medium: 12, large: 16, section: 24, page: 32, spacious: 48}
var geometry = {control: 36, compactControl: 32, field: 40, option: 48, cardPadding: 16, panelPadding: 16, controlRadius: 8}
var motion = {feedback: 120, transition: 180, reveal: 240, spinner: 900}

function channels(color) { return Array.isArray(color) ? color : [color.r, color.g, color.b, color.a] }
function mix(a, b, amount) {
  a = channels(a); b = channels(b)
  return [a[0]+(b[0]-a[0])*amount, a[1]+(b[1]-a[1])*amount, a[2]+(b[2]-a[2])*amount, 1]
}
function opaque(color, backdrop) {
  var c = channels(color)
  return mix(backdrop, c, c[3] === undefined ? 1 : c[3])
}
function luminance(color) {
  var c = channels(color).slice(0,3).map(function(v) { return v <= 0.04045 ? v/12.92 : Math.pow((v+0.055)/1.055,2.4) })
  return c[0]*0.2126+c[1]*0.7152+c[2]*0.0722
}
function contrast(a, b) {
  var x=luminance(a), y=luminance(b)
  return (Math.max(x,y)+0.05)/(Math.min(x,y)+0.05)
}
// Keep the theme hue when possible. A low-contrast theme is corrected toward
// its most legible neutral, with the smallest sufficient change.
function readable(color, background, minimum) {
  var c=opaque(color,background)
  if(contrast(c,background)>=minimum) return c
  // QColor quantizes channels. Leave a small margin so rounding cannot turn
  // a 4.5:1 result into 4.4999:1 in the actual rendered component.
  minimum+=0.01
  var black=[0,0,0,1], white=[1,1,1,1]
  var target=contrast(black,background)>contrast(white,background) ? black : white
  if(contrast(target,background)<minimum) return target
  var low=0, high=1
  for(var i=0;i<20;i++) {
    var mid=(low+high)/2
    if(contrast(mix(c,target,mid),background)>=minimum) high=mid
    else low=mid
  }
  return mix(c,target,high)
}
if(typeof module!=="undefined") module.exports={typography:typography,spacing:spacing,geometry:geometry,motion:motion,mix:mix,opaque:opaque,luminance:luminance,contrast:contrast,readable:readable}
