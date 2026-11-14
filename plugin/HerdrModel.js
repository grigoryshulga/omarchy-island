function statusRole(status) {
  return status==="blocked" ? "warning" : status==="working" ? "info" : status==="done" ? "success" : "secondaryText"
}
// A missing source resets its baseline: reconnecting must not replay old work.
function transitions(previous, sources) {
  var next={}, alerts=[]
  sources.forEach(function(source) {
    if(source.status!=="connected") return
    var rows=source.rows || [], old=previous[source.id]
    next[source.id]=rows
    if(!old) return
    rows.forEach(function(row) {
      var before=old.find(function(item){return item.id===row.id})
      if((!before && row.status==="blocked") || (before && before.status!==row.status && (row.status==="blocked" || row.status==="done" || (before.status==="working" && row.status==="idle")))) alerts.push(row)
    })
  })
  alerts.sort(function(a,b){return (b.status==="blocked" ? 1 : 0)-(a.status==="blocked" ? 1 : 0)})
  return {baseline:next,alerts:alerts}
}
if(typeof module!=="undefined") module.exports={transitions:transitions,statusRole:statusRole}
