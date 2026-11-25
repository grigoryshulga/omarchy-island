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
function source(current,voxtype,superwhisper) {
  if(current==="superwhisper" && superwhisper!=="idle") return current
  if(voxtype!=="idle") return "voxtype"
  return superwhisper!=="idle" ? "superwhisper" : ""
}
function empty() {return Array(48).fill(0)}
function push(history,level) {return history.slice(1).concat([Math.max(0,Math.min(1,level))])}
function superwhisperInput(groups) {
  // Meter the source connected to the recording, including device overrides.
  for(var group of groups) {
    if(group.target && group.target.name==="superwhisper-capture" && group.source) return group.source
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
function waveAt(u,energy,phase,morph,reveal) {
  var taper=smoothstep(0,0.10,u)*(1-smoothstep(0.90,1,u))
  var crest=0.5+0.5*Math.sin(4*Math.PI*u-2*phase)
  var undertow=0.5+0.5*Math.sin(9.1*u+phase+1.1)
  var progress=0.5+0.5*Math.sin(14*u-phase)
  var center=0.042*Math.sin(11*u-2*phase)+0.045*energy*(2*undertow-1)
  var width=0.054+energy*(0.10+0.244*(0.72*crest+0.28*undertow))
  center=(center*(1-morph)+0.026*Math.sin(11*u-phase)*morph)*taper
  width=(width*(1-morph)+(0.058+0.084*progress)*morph)*taper
  return {
    top:(center-width*(0.91+0.09*undertow))*reveal,
    bottom:(center+width*(0.87+0.13*crest))*reveal,
    opacity:Math.min(1,reveal*2)*taper
  }
}
function waveEdge(y,wave) {
  var distance=Math.min(Math.abs(y-wave.top),Math.abs(y-wave.bottom))
  return 1-smoothstep(0.015,0.088,distance)
}
function waveInk(y,wave) {
  var fill=smoothstep(wave.top-0.032,wave.top+0.019,y)
    *(1-smoothstep(wave.bottom-0.024,wave.bottom+0.024,y))
  var grid=0.075-0.027*smoothstep(0,0.5,Math.abs(y))
  return wave.opacity*Math.max(grid,fill*(0.32+0.66*waveEdge(y,wave)))
}
if(typeof module!=="undefined") module.exports={state:state,frame:frame,superwhisper:superwhisper,source:source,
  empty:empty,push:push,superwhisperInput:superwhisperInput,meterPeak:meterPeak,voiceStrength:voiceStrength,
  waveAt:waveAt,waveInk:waveInk}
