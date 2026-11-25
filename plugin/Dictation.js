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
function matrix(history,start) {
  // Qt takes rows, while GLSL indexes the resulting matrix by column.
  return Qt.matrix4x4(
    history[start],history[start+4],history[start+8],history[start+12],
    history[start+1],history[start+5],history[start+9],history[start+13],
    history[start+2],history[start+6],history[start+10],history[start+14],
    history[start+3],history[start+7],history[start+11],history[start+15]
  )
}
if(typeof module!=="undefined") module.exports={state:state,frame:frame,superwhisper:superwhisper,source:source,empty:empty,push:push}
