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
  return data && typeof data.mode==="string"
    ? {mode:state(data.mode),peak:level(data.peak) || 0,inputMeter:data.inputMeter===true} : null
}
function source(current,voxtype,superwhisper,hex) {
  if(current==="hex" && hex!=="idle") return current
  if(current==="superwhisper" && superwhisper!=="idle") return current
  if(voxtype!=="idle") return "voxtype"
  if(superwhisper!=="idle") return "superwhisper"
  return hex!=="idle" ? "hex" : ""
}
function empty() {return Array(48).fill(0)}
function push(history,level) {return history.slice(1).concat([Math.max(0,Math.min(1,level))])}
function captureInput(groups,provider) {
  // Meter the source connected to the recording, including device overrides.
  var name=provider==="hex" ? "hex" : "superwhisper-capture"
  for(var group of groups) {
    if(group.target && group.target.name===name && group.source) return group.source
  }
  return null
}
function meterPeak(provider,input) {
  return level(provider) || level(input) || 0
}
function voiceStrength(peak) {
  return Math.sqrt(Math.max(0,Math.min(1,(peak-0.008)/0.57)))
}
function smoothstep(low,high,value) {
  var t=Math.max(0,Math.min(1,(value-low)/(high-low)))
  return t*t*(3-2*t)
}
// Keep the Canvas fallback in step with shaders/dictation.frag.
function waveAt(u,energy,phase,morph,reveal,rowStep) {
  var taper=smoothstep(0,0.10,u)*(1-smoothstep(0.90,1,u))
  var angle=4*Math.PI*u-2*phase
  var drift=Math.sin(2*Math.PI*u-phase+0.9)
  var upper=energy*(0.103+0.218*(0.5+0.5*Math.sin(angle)))
  var lower=energy*(0.108+0.200*(0.5+0.5*Math.sin(angle-0.69)))
  var voiceCenter=energy*(0.047*Math.sin(angle-0.32)+0.023*drift)
  var workAngle=4*Math.PI*u-phase
  var workWidth=0.023+0.086*(0.5+0.5*Math.sin(workAngle))
  var workCenter=0.019*Math.sin(workAngle-0.55)
  var center=(voiceCenter*(1-morph)+workCenter*morph)*taper
  var halfStep=0.5*rowStep
  var upperWidth=halfStep+(upper*(1-morph)+workWidth*morph)*taper
  var lowerWidth=halfStep+(lower*(1-morph)+workWidth*morph)*taper
  var pass=1.22-1.44*((phase/Math.PI)%1)
  var trail=u-pass
  var sweep=morph*smoothstep(-0.08,0,trail)*(1-smoothstep(0.04,0.20,trail))
  return {
    top:(center-upperWidth)*reveal,
    bottom:(center+lowerWidth)*reveal,
    opacity:Math.min(1,reveal*2)*taper,
    definition:smoothstep(0,0.28,energy)*(1-morph)+0.72*morph,
    sweep:sweep,
    rowStep:rowStep
  }
}
function waveEdge(y,wave) {
  // Soften the line by lighting the adjacent rows, while keeping each dot sharp.
  var distance=Math.min(Math.abs(y-wave.top),Math.abs(y-wave.bottom))/wave.rowStep
  return 1-smoothstep(0.12,1.39-0.46*wave.definition,distance)
}
function waveInk(y,wave) {
  var fill=0.28*smoothstep(wave.top-0.028,wave.top+0.023,y)
    *(1-smoothstep(wave.bottom-0.023,wave.bottom+0.028,y))
  var stroke=(0.43+0.52*wave.definition+0.18*wave.sweep)*waveEdge(y,wave)
  var grid=0.075-0.027*smoothstep(0,0.5,Math.abs(y))+0.07*wave.sweep
  return wave.opacity*Math.max(grid,fill+(1-fill)*stroke)
}
if(typeof module!=="undefined") module.exports={state:state,frame:frame,superwhisper:superwhisper,source:source,
  empty:empty,push:push,captureInput:captureInput,meterPeak:meterPeak,voiceStrength:voiceStrength,
  waveAt:waveAt,waveInk:waveInk}
