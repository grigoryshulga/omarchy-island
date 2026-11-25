// Voxtype's state file is authoritative; no invented success/error states.
function state(raw) {
  var value=String(raw || "").trim()
  return value==="recording" || value==="transcribing" ? value : "idle"
}
function parse(raw) {
  if(typeof raw!=="string" || raw.length>4096) return null
  var data
  try {data=JSON.parse(raw)} catch(e) {return null}
  return data && typeof data==="object" && !Array.isArray(data) ? data : null
}
function level(peak) {
  return typeof peak==="number" && isFinite(peak) ? Math.max(0,Math.min(1,peak)) : null
}
function frame(raw) {
  var data=parse(raw)
  return data ? level(data.peak) : null
}
function superwhisper(raw) {
  var data=parse(raw)
  return data && typeof data.mode==="string" ? {mode:state(data.mode),peak:level(data.peak) || 0} : null
}
function source(current,voxtype,superwhisper) {
  if(current==="superwhisper" && superwhisper!=="idle") return current
  if(voxtype!=="idle") return "voxtype"
  return superwhisper!=="idle" ? "superwhisper" : ""
}
function empty() {return Array(48).fill(0)}
function push(history,level) {return history.slice(1).concat([Math.max(0,Math.min(1,level))])}
function hasSignal(history) {
  for(var i=16;i<48;i++) if(history[i]>0.015) return true
  return false
}
function smoothstep(low,high,value) {
  var t=Math.max(0,Math.min(1,(value-low)/(high-low)))
  return t*t*(3-2*t)
}
function samplePeak(history,u,offset) {
  // The latest sample enters inside the right taper. Compensate for the
  // history shift by one sample, then scroll it into place between updates.
  var position=Math.max(0,Math.min(31,u*31/0.84)-offset)
  var i=Math.floor(position)+16
  return history[i]+(history[Math.min(i+1,47)]-history[i])*(position%1)
}
// Keep the Canvas fallback in step with shaders/dictation.frag.
function ribbonAt(u,peak,phase,morph) {
  var taper=smoothstep(0,0.16,u)*(1-smoothstep(0.86,1,u))
  var energy=Math.pow(smoothstep(0.015,0.9,peak),0.55)
  var pressure=energy*taper
  var ripple=Math.sin(10*u+phase)
  var eddy=Math.sin(21*u+2*phase)
  var pulse=Math.pow(0.5+0.5*Math.sin(13*u+2*phase),3)
  var voiceCenter=pressure*(0.12*ripple+0.047*eddy-0.024)
  var workCenter=0.09*ripple*taper
  var voiceThickness=0.034+0.238*pressure
  var workThickness=0.04+0.125*pulse*taper
  var voiceWeight=1-morph
  var sheen=0.42+0.32*pressure*voiceWeight+0.22*pulse*morph
  var intensity=pressure*voiceWeight+(0.44+0.56*pulse)*morph
  return {
    center:voiceCenter*voiceWeight+workCenter*morph,
    thickness:voiceThickness*voiceWeight+workThickness*morph,
    sheen:sheen,
    opacity:taper*(0.58+0.42*intensity)
  }
}
function ribbonShine(depth,ribbon) {
  return ribbon.sheen*(1-smoothstep(0.016,0.105,Math.abs(depth+ribbon.thickness*0.46)))
}
function matrix(history,start) {
  // Qt takes rows, while GLSL indexes the resulting matrix by column.
  return Qt.matrix4x4(
    history[start],history[start+4],history[start+8],history[start+12],
    history[start+1],history[start+5],history[start+9],history[start+13],
    history[start+2],history[start+6],history[start+10],history[start+14],
    history[start+3],history[start+7],history[start+11],history[start+15]
  )
}
if(typeof module!=="undefined") module.exports={state:state,frame:frame,superwhisper:superwhisper,source:source,empty:empty,push:push,hasSignal:hasSignal,samplePeak:samplePeak}
