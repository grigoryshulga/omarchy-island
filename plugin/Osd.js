// Validate native OSD payloads before presenting them inside the bar.
function parse(raw) {
  if(typeof raw!=="string" || raw.length>8192) return null
  var data
  try {data=JSON.parse(raw)} catch(e) {return null}
  if(!data || typeof data!=="object" || Array.isArray(data)) return null
  for(var key of ["icon","message","progressText"])
    if(data[key]!==undefined && typeof data[key]!=="string") return null
  var icon=String(data.icon || "").slice(0,128)
  var message=String(data.message || "").slice(0,2048)
  var progressText=String(data.progressText || "").slice(0,128)
  var hasProgress=!message && data.value!==undefined && data.value!==null && String(data.value).trim()!==""
  var value=0
  if(hasProgress) {
    if(typeof data.value!=="number" && typeof data.value!=="string") return null
    if(data.max!==undefined && typeof data.max!=="number" && typeof data.max!=="string") return null
    var amount=Number(data.value),maximum=data.max===undefined || data.max==="" ? 100 : Number(data.max)
    if(!isFinite(amount) || !isFinite(maximum) || maximum<=0) return null
    value=Math.max(0,Math.min(1,amount/maximum))
  }
  if(!hasProgress && !message && !icon) return null
  var duration=1200
  if(data.duration!==undefined && data.duration!=="") {
    if(typeof data.duration!=="number" && typeof data.duration!=="string") return null
    duration=Number(data.duration)
    if(!isFinite(duration)) return null
    duration=duration<=0 ? 0 : Math.max(200,Math.min(60000,duration))
  }
  var name=icon.toLowerCase()
  var kind=name==="download" ? "download" : name==="layout" ? "layout" : name.indexOf("volume")===0 || ["mute","muted"].indexOf(name)>=0 ? "volume" : ["brightness","display"].indexOf(name)>=0 ? "brightness" : name==="keyboard" ? "keyboard" : name.indexOf("mic")===0 ? "microphone" : "message"
  return {iconName:icon,message:message,progressText:progressText,hasProgress:hasProgress,value:value,duration:duration,kind:kind,muted:kind==="volume" && name.indexOf("mute")>=0}
}
if(typeof module!=="undefined") module.exports={parse:parse}
