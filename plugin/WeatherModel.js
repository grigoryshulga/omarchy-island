.pragma library

function number(value,min,max) {
  if(value===null || value===undefined || value==="" || typeof value==="boolean") return null
  var n=Number(value)
  return isFinite(n) && n>=min && n<=max ? n : null
}
function text(value,max) { return typeof value==="string" ? value.slice(0,max).replace(/[\x00-\x1f\x7f]/g,"").trim() : "" }
function coordinates(value) {
  if(!value || typeof value!=="object") return null
  var lat=number(value.latitude,-90,90),lon=number(value.longitude,-180,180)
  return lat===null || lon===null ? null : {latitude:lat,longitude:lon}
}
function location(raw) {
  try {
    var value=JSON.parse(raw), point=coordinates(value)
    return {name:text(value.name,128),latitude:point ? point.latitude : null,longitude:point ? point.longitude : null}
  } catch(e) { return {name:"",latitude:null,longitude:null} }
}
// Open-Meteo WMO codes: clear, partly cloudy, overcast, fog, drizzle, rain,
// snow and thunder. The scene adds the moon for clear/partly-cloudy nights.
function kind(code) {
  var n=number(code,0,99)
  if(n===null) return -1
  if(n===0) return 0
  if(n===1 || n===2) return 1
  if(n===3) return 2
  if(n===45 || n===48) return 3
  if(n===51 || n===53 || n===55 || n===56 || n===57) return 4
  if(n===61 || n===63 || n===65 || n===66 || n===67 || n===80 || n===81 || n===82) return 5
  if(n===71 || n===73 || n===75 || n===77 || n===85 || n===86) return 6
  if(n===95 || n===96 || n===99) return 7
  return -1
}
function parseReport(raw) {
  if(typeof raw!=="string" || raw.length>262144) return null
  try {
    var payload=JSON.parse(raw), data=payload.forecast, c=data && data.current
    if(!c || !payload.location || !coordinates(payload.location)) return null
    var temp=number(c.temperature_2m,-100,70),code=number(c.weather_code,0,99),stamp=number(payload.fetchedAt,1,4102444800)
    if(temp===null || code===null || stamp===null) return null
    var daily=data.daily || {},days=[]
    for(var i=0;i<Math.min(4,(daily.time || []).length);i++) {
      var date=String(daily.time[i]),min=number((daily.temperature_2m_min || [])[i],-100,70),max=number((daily.temperature_2m_max || [])[i],-100,70)
      if(!/^\d{4}-\d{2}-\d{2}$/.test(date) || isNaN(Date.parse(date+"T12:00:00Z")) || min===null || max===null || min>max) continue
      days.push({date:date,min:min,max:max,code:number((daily.weather_code || [])[i],0,99)})
    }
    return {location:text(payload.location.name,128),country:text(payload.location.country,128),fetchedAt:stamp,
      current:{temperature:temp,feels:number(c.apparent_temperature,-120,90),wind:number(c.wind_speed_10m,0,500),humidity:number(c.relative_humidity_2m,0,100),code:code,isDay:Number(c.is_day)!==0},days:days}
  } catch(e) { return null }
}
function parseSuggestions(raw,query) {
  if(typeof raw!=="string" || raw.length>65536) return []
  try {
    var payload=JSON.parse(raw)
    if(payload.query!==query || !Array.isArray(payload.results)) return []
    return payload.results.slice(0,5).filter(function(row){return coordinates(row) && text(row.name,128)!==""}).map(function(row){return {name:text(row.name,128),description:text(row.description,256),latitude:Number(row.latitude),longitude:Number(row.longitude)}})
  } catch(e) { return [] }
}
// Same metric/imperial preferences as Omarchy's weather panel.
function imperial(override,locale,country) {
  if(override==="imperial") return true
  if(override==="metric") return false
  var name=String(country || "").trim().toLowerCase()
  if(name) return ["united states","united states of america","us","usa","liberia","myanmar","burma"].indexOf(name)>=0
  return /^en[_-](US|LR)($|[_.-])|^my($|[_.-])/.test(String(locale || ""))
}
function temperature(celsius,useImperial) { return celsius===null || celsius===undefined ? null : Math.round(useImperial ? celsius*9/5+32 : celsius) }
function nativeSettings(raw) {
  try {
    var config=JSON.parse(raw),layout=config.bar && config.bar.layout || {}
    for(var section in layout) {
      var entries=layout[section]
      if(!Array.isArray(entries)) continue
      for(var i=0;i<entries.length;i++) if(entries[i] && entries[i].id==="omarchy.weather") return {unit:entries[i].unit || "",refreshMinutes:Math.max(1,Math.min(120,Number(entries[i].refreshMinutes)||15))}
    }
  } catch(e) {}
  return {unit:"",refreshMinutes:15}
}
