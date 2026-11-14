// Calendar-keyed usage aggregation shared by QML and Node checks.
function number(value) { return typeof value === "number" && isFinite(value) && value >= 0 ? value : 0 }
function dayKey(date) { return date.getFullYear()+"-"+String(date.getMonth()+1).padStart(2,"0")+"-"+String(date.getDate()).padStart(2,"0") }
function periodKeys(range, now) {
  var date = new Date(now), count = range === "today" ? 1 : range === "week" ? 7 : 30, keys = []
  for (var i=count-1;i>=0;i--) { var day=new Date(date.getFullYear(),date.getMonth(),date.getDate()-i); keys.push(dayKey(day)) }
  return keys
}
function empty() { return {tokens:0,cost:0,requests:0,unpricedTokens:0} }
function add(to, from) {
  if (!from) return
  ;["tokens","cost","requests"].forEach(function(k){to[k]+=number(from[k])})
  to.unpricedTokens+=from.unpricedTokens === undefined && from.priced!==true ? number(from.tokens) : number(from.unpricedTokens)
}
function analyze(cache, range, providerId, selected, now) {
  var keys=periodKeys(range,now), today=keys[keys.length-1], hourly=range==="today"
  var providers=(cache.providers || []).filter(function(p){return !providerId || p.id===providerId})
  var series=(hourly ? Array.from({length:24},function(_,i){return String(i)}) : keys).map(function(key){return {key:key,totals:empty(),parts:[]}})
  var total=empty(), rows=[], models=Object.create(null), partialHours=[], missing=[]
  providers.forEach(function(p){
    var days=Array.isArray(p.days) ? p.days : [], hours=Array.isArray(p.hours) ? p.hours : []
    var available=number((p.total || {}).tokens)>0 || number((p.total || {}).requests)>0 || days.some(function(d){return number(d.tokens)>0 || number(d.requests)>0})
    var currentHours=p.usageDay===today || (!p.usageDay && cache.syncedAt && dayKey(new Date(cache.syncedAt))===today)
    var daily=empty(), metrics=empty(), modelPeriods=[]
    keys.forEach(function(key){days.filter(function(d){return d.date===key}).forEach(function(d){add(daily,d)})})
    if (hourly && daily.tokens>0 && (!currentHours || !hours.some(function(h){return number(h.tokens)>0}))) partialHours.push(p.name)
    series.forEach(function(point){
      var buckets=hourly ? (currentHours ? hours.filter(function(h){return String(h.hour)===point.key}) : []) : days.filter(function(d){return d.date===point.key})
      var part=empty()
      buckets.forEach(function(bucket){add(point.totals,bucket);add(part,bucket);if(selected===point.key) add(metrics,bucket)})
      point.parts.push({id:p.id,totals:part})
    })
    if (!selected) metrics=daily
    if (selected && hourly) modelPeriods=currentHours ? [(p.modelHours || {})[selected] || []] : []
    else (selected ? [selected] : keys).forEach(function(key){modelPeriods.push((p.modelDays || {})[key] || [])})
    modelPeriods.forEach(function(period){period.forEach(function(m){
      var name=String(m.name || ""), id=JSON.stringify([p.id,name])
      if (!models[id]) models[id]={id:id,name:name,providerId:p.id,provider:p.name,totals:empty()}
      add(models[id].totals,m)
    })})
    add(total,metrics)
    rows.push({id:p.id,name:p.name,available:available,totals:metrics})
    if (!available) missing.push(p.name)
  })
  var modelRows=Object.keys(models).map(function(k){return models[k]}), attributed=empty()
  modelRows.forEach(function(m){add(attributed,m.totals)})
  return {total:total,series:series,providers:rows,models:modelRows,missing:missing,partialHours:partialHours,
    available:rows.some(function(p){return p.available}),
    unattributed:{tokens:Math.max(0,total.tokens-attributed.tokens),cost:Math.max(0,total.cost-attributed.cost)},keys:keys}
}
function compact(value, strings, format) {
  var units=[[1e9,"limits.unit.billion"],[1e6,"limits.unit.million"],[1e3,"limits.unit.thousand"]]
  for(var i=0;i<units.length;i++) if(value>=units[i][0]) return strings.t(units[i][1]).replace("%1",format(value/units[i][0],1))
  return format(value)
}
if(typeof module!=="undefined") module.exports={analyze:analyze,periodKeys:periodKeys,compact:compact}
