// Voxtype's state file is authoritative; no invented success/error states.
function state(raw) {
  var value=String(raw || "").trim()
  return value==="recording" || value==="transcribing" ? value : "idle"
}
function frame(raw) {
  if(typeof raw!=="string" || raw.length>4096) return null
  var data
  try {data=JSON.parse(raw)} catch(e) {return null}
  if(!data || typeof data!=="object" || Array.isArray(data)) return null
  if(typeof data.peak!=="number" || !isFinite(data.peak)) return null
  return Math.max(0,Math.min(1,data.peak))
}
function empty() {return Array(48).fill(0)}
function push(history,level) {return history.slice(1).concat([Math.max(0,Math.min(1,level))])}
if(typeof module!=="undefined") module.exports={state:state,frame:frame,empty:empty,push:push}
