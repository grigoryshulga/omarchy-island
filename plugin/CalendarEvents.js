.pragma library
function parse(text) {
  if(typeof text!=="string" || text.length>16*1024*1024) return null
  try {
    var value=JSON.parse(text)
    if(value.error) return {error:String(value.error)}
    if(!Array.isArray(value.sources) || value.sources.length>6 || !Array.isArray(value.events) || value.events.length>12000 || typeof value.year!=="number") return null
    if(value.sources.some(function(s){return !s || typeof s.id!=="string" || typeof s.name!=="string" || typeof s.enabled!=="boolean"})) return null
    if(value.events.some(function(e){return !e || typeof e.title!=="string" || typeof e.location!=="string" || typeof e.sourceName!=="string" || !isFinite(e.start) || !isFinite(e.end) || !/^\d{4}-\d{2}-\d{2}$/.test(e.startDay) || !/^\d{4}-\d{2}-\d{2}$/.test(e.endDay)})) return null
    return value
  } catch(e) {return null}
}
function days(events) {
  var marked={}
  events.forEach(function(event){
    var day=new Date(event.startDay+"T12:00:00Z")
    for(var i=0;i<380;i++) {
      var key=day.toISOString().slice(0,10)
      if(key>event.endDay) break
      marked[key]=true
      day.setUTCDate(day.getUTCDate()+1)
    }
  })
  return Object.keys(marked)
}
function onDay(events,key) {
  return events.filter(function(event){return event.startDay<=key && event.endDay>=key})
    .sort(function(a,b){return Number(b.allDay)-Number(a.allDay) || a.start-b.start})
}
