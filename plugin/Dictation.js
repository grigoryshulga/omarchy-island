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
  // The latest sample enters inside the taper near the icon. Compensate for the
  // history shift by one sample, then scroll it into place between updates.
  var position=Math.max(0,Math.min(31,u*31/0.84)-offset)
  var i=Math.floor(position)+16
  return history[i]+(history[Math.min(i+1,47)]-history[i])*(position%1)
}
// Keep the Canvas fallback in step with shaders/dictation.frag.
function ribbonAt(u,peak,phase,morph,reveal) {
  var taper=smoothstep(0,0.16,u)*(1-smoothstep(0.86,1,u))
  var energy=Math.pow(smoothstep(0.015,0.9,peak),0.55)
  var pressure=energy*taper
  var ripple=Math.sin(10*u+phase)
  var eddy=Math.sin(21*u+2*phase)
  var pulse=Math.pow(0.5+0.5*Math.sin(16*u+2*phase),2)
  var voiceCenter=pressure*(0.095*ripple+0.044*eddy-0.012)
  var workCenter=0.058*ripple*taper
  var voiceThickness=0.034+0.228*pressure
  var workThickness=0.042+0.17*pulse*taper
  var voiceWeight=1-morph
  var sheen=0.42+0.32*pressure*voiceWeight+0.22*pulse*morph
  var intensity=pressure*voiceWeight+(0.44+0.56*pulse)*morph
  var wake=0.5+0.5*Math.sin(57*u+4*phase)
  // The leading bead reveals the fixed grid, then retraces it on dismissal.
  var front=1.10-1.18*reveal
  var visibility=smoothstep(front-0.05,front+0.04,u)
  var bead=1-smoothstep(0.012,0.074,Math.abs(u-front))
  return {
    center:voiceCenter*voiceWeight+workCenter*morph,
    thickness:voiceThickness*voiceWeight+workThickness*morph+0.14*bead*taper,
    sheen:Math.max(sheen,0.84*bead),
    reflection:0.42*intensity,
    split:morph*taper*smoothstep(0.25,0.76,pulse),
    droplets:voiceWeight*smoothstep(0.32,0.84,pressure)*smoothstep(0.58,0.95,wake),
    dropletGap:0.066+0.058*wake,
    opacity:visibility*taper*Math.max(0.58+0.42*intensity,0.88*bead)
  }
}
function ribbonInk(depth,ribbon) {
  var distance=Math.abs(depth)
  var body=1-smoothstep(ribbon.thickness-0.044,ribbon.thickness+0.044,distance)
  var channel=ribbon.split*(1-smoothstep(0.017,0.076,distance))
  var dropletDistance=Math.abs(depth+ribbon.thickness+ribbon.dropletGap)
  var droplet=ribbon.droplets*(1-smoothstep(0.012,0.057,dropletDistance))
  return Math.max(body*(1-0.91*channel),0.83*droplet)
}
function ribbonShine(depth,ribbon) {
  var surface=1-smoothstep(0.014,0.093,Math.abs(depth+ribbon.thickness*0.52))
  var reflection=1-smoothstep(0.014,0.054,Math.abs(depth-ribbon.thickness*0.64))
  return Math.max(ribbon.sheen*surface,ribbon.reflection*reflection)
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
if(typeof module!=="undefined") module.exports={state:state,frame:frame,superwhisper:superwhisper,source:source,empty:empty,push:push,hasSignal:hasSignal,samplePeak:samplePeak,ribbonAt:ribbonAt,ribbonInk:ribbonInk}
