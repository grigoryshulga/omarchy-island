// Island policy over the aggregate-only Agent Limits snapshot. QML/Node compatible.
function finite(value) { return typeof value === "number" && isFinite(value) }
function text(value, length) { return typeof value === "string" ? value.slice(0,length || 180) : "" }
function key(provider, label) { return JSON.stringify([provider,label]) }
function parse(raw) {
  try {
    if (raw.length>4194304) return null
    var data=JSON.parse(raw)
    if (!data || data.schemaVersion!==1 || !Array.isArray(data.providers)) return null
    data.providers=data.providers.filter(function(p){return p && typeof p.id==="string" && /^[a-z0-9-]{1,40}$/.test(p.id)}).slice(0,20)
    return data
  } catch(e) { return null }
}
function windows(cache, now) {
  var result=[],seen={}
  ;(cache.providers || []).forEach(function(p){
    ;(Array.isArray(p.limits) ? p.limits : []).slice(0,20).forEach(function(limit){
      if(!limit || !text(limit.label,80)) return
      var id=key(p.id,limit.label)
      if(seen[id]) return
      seen[id]=true
      var reset=Date.parse(limit.resetsAt),pending=!!limit.rolledWindows || (isFinite(reset) && reset<=now)
      var known=finite(limit.percent) && limit.percent>=0 && limit.percent<=100 && !pending
      result.push({id:id,providerId:p.id,name:text(p.name) || p.id,label:text(limit.label,80),
        remaining:known ? (limit.exhausted ? 0 : 100-limit.percent) : null,
        exhausted:known && (limit.exhausted===true || limit.percent>=100),pendingReset:pending,
        resetsAt:isFinite(reset) ? reset : 0,stale:!!p.stale || p.status==="error" || p.limitsSource==="record" || cache.state==="error" || (finite(p.limitsCheckedAt) && now-p.limitsCheckedAt>600000),
        checkedAt:finite(p.limitsCheckedAt) ? p.limitsCheckedAt : 0})
    })
  })
  return result
}
// Five percentage points of hysteresis; an unconfirmed reset cannot dismiss a warning.
function attention(rows, previous, threshold) {
  return rows.filter(function(r){return r.remaining!==null ? r.remaining<=threshold+(previous.indexOf(r.id)>=0 ? 5 : 0) : previous.indexOf(r.id)>=0}).map(function(r){return r.id})
}
function summary(rows,pins,automatic,mode) {
  var ids=mode==="auto" ? [] : pins.slice()
  if(mode!=="pinned") automatic.forEach(function(id){if(ids.indexOf(id)<0) ids.push(id)})
  return ids.map(function(id){return rows.find(function(r){return r.id===id})}).filter(function(r){return !!r})
}
function resetCountdown(row,now,strings,formatNumber) {
  if(row.pendingReset || (row.resetsAt>0 && row.resetsAt<=now)) return strings.t("limits.awaitingReset")
  if(!finite(row.resetsAt) || row.resetsAt<=0) return ""
  var minutes=Math.ceil((row.resetsAt-now)/60000),hours=Math.floor(minutes/60),days=Math.floor(hours/24)
  var key=days>0 ? "limits.daysHoursMinutes" : hours>0 ? "limits.hoursMinutes" : "limits.minutes"
  var values=days>0 ? [days,hours%24,minutes%60] : hours>0 ? [hours,minutes%60] : [minutes]
  var duration=strings.t(key).replace(/%([1-3])/g,function(_,index){return formatNumber(values[Number(index)-1])})
  return strings.t("limits.resetIn").replace("%1",duration)
}
function displayName(row) {
  if(row.providerId==="codex" && /^Weekly(?: \(7-day\))?$/.test(row.label)) return "Codex Weekly"
  return row.name+" · "+row.label
}
function tightest(rows) {
  return rows.filter(function(r){return r.remaining!==null}).reduce(function(best,r){return !best || r.remaining<best.remaining ? r : best},null)
}
function toggle(pins,id) { return pins.indexOf(id)>=0 ? pins.filter(function(p){return p!==id}) : pins.concat([id]).slice(0,100) }
function validPins(value) {
  // QML shell settings can expose a QVariantList rather than a JS Array.
  try {value=JSON.parse(JSON.stringify(value))} catch(e) {return false}
  return Array.isArray(value) && value.length<=100 && value.every(function(id){
    if(typeof id!=="string" || id.length>180) return false
    try {var pair=JSON.parse(id);return Array.isArray(pair) && pair.length===2 && /^[a-z0-9-]{1,40}$/.test(pair[0]) && typeof pair[1]==="string" && pair[1].length>0 && pair[1].length<=80} catch(e){return false}
  }) && new Set(value).size===value.length
}
function metrics(provider,range) {
  var days=provider.days && typeof provider.days==="object" && typeof provider.days.slice==="function" ? provider.days.slice(-(range==="today" ? 1 : range==="week" ? 7 : 30)) : []
  days=days.filter(function(day){return day && typeof day==="object"})
  var result={tokens:0,requests:0,cost:0,unpriced:false,available:!!(provider.total && provider.total.tokens>0) || days.some(function(day){return day.tokens>0 || day.requests>0 || day.cost>0})}
  days.forEach(function(day){
    ;["tokens","requests","cost"].forEach(function(k){if(finite(day[k]) && day[k]>=0) result[k]+=day[k]})
    if(day.unpricedTokens>0 || (day.tokens>0 && day.priced!==true)) result.unpriced=true
  })
  return result
}
// Keep delegates (and keyboard focus) alive when measurements replace the snapshot.
// Existing entries retain their order; new identities are appended.
function syncIdentities(model, ids, role) {
  for (var i = model.count - 1; i >= 0; i--)
    if (ids.indexOf(model.get(i)[role]) < 0) model.remove(i)
  ids.forEach(function(id) {
    for (var j = 0; j < model.count; j++)
      if (model.get(j)[role] === id) return
    var item = {}
    item[role] = id
    model.append(item)
  })
}

function movePin(pins, id, direction) {
  var result = pins.slice(), from = result.indexOf(id), to = from + direction
  if (from < 0 || to < 0 || to >= result.length || Math.abs(direction) !== 1) return result
  result.splice(to, 0, result.splice(from, 1)[0])
  return result
}

function windowLabel(row, strings) {
  var labels = {"Weekly": "weekly", "Weekly (7-day)": "weekly", "Session": "session"}
  return Object.prototype.hasOwnProperty.call(labels, row.label) ? strings.t("limits.window." + labels[row.label]) : row.label
}

function freshness(row, now, strings, formatNumber) {
  if (row.stale) return strings.t("limits.cached")
  if (!finite(row.checkedAt) || row.checkedAt <= 0 || row.checkedAt > now)
    return strings.t("limits.checkedUnknown")
  var minutes = Math.floor((now - row.checkedAt) / 60000)
  return minutes < 1 ? strings.t("limits.checkedNow")
    : strings.t("limits.checkedMinutes").replace("%1", formatNumber(minutes))
}

function balances(provider, formatNumber) {
  return (Array.isArray(provider.balance) ? provider.balance : []).filter(function(balance) {
    return balance && finite(balance.total) && typeof balance.currency === "string"
  }).map(function(balance) {
    return text(balance.currency, 12) + " " + formatNumber(balance.total, 2)
  }).join(" · ")
}

if(typeof module!=="undefined") module.exports={syncIdentities:syncIdentities,movePin:movePin,windowLabel:windowLabel,freshness:freshness,balances:balances,displayName:displayName,resetCountdown:resetCountdown,parse:parse,key:key,windows:windows,attention:attention,summary:summary,tightest:tightest,toggle:toggle,validPins:validPins,metrics:metrics}
