// Native omarchy-reminder JSON is presentation data, never shell text.
function rows(data, now) {
  if(!data || !Array.isArray(data.reminders)) return []
  return data.reminders.filter(function(r){return r && typeof r.at==='number' && isFinite(r.at) && r.at>now && typeof r.unit==='string'})
    .map(function(r){return {unit:r.unit,at:r.at,label:String(r.label || r.message || '').slice(0,4096)}})
    .sort(function(a,b){return a.at-b.at})
}
function dayKey(at) {
  var d=new Date(at*1000)
  return String(d.getFullYear()).padStart(4,'0')+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')
}
function remaining(at, now, format) {
  var seconds=Math.max(0,Math.ceil(at-now)),minutes=Math.floor(seconds/60)
  return format(minutes)+':'+(seconds%60<10 ? format(0) : '')+format(seconds%60)
}
if(typeof module!=='undefined') module.exports={rows:rows,dayKey:dayKey,remaining:remaining}
