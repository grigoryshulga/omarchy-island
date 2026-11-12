// Presentation helpers; bridge data and answers never become shell text.
var busyStates = ["preparing", "starting", "queued", "running", "waiting"]
function busy(row) { return row && busyStates.indexOf(row.status) >= 0 }
// Requests include questions, approvals and authentication handled in T3.
function statusRole(row) {
  if(row && row.requestId) return "warning"
  if(row && row.status==="failed") return "danger"
  if(row && row.status==="completed") return "success"
  if(busy(row)) return "info"
  return "secondaryText"
}
function statusRank(row) {return row && row.requestId ? 0 : busy(row) ? 2 : 1}
function overviewRows(rows) {
  var working=0
  return rows.filter(function(row){
    if(row.requestId || row.status==="failed") return true
    return busy(row) && ++working<=2
  }).map(function(row){return row.id})
}
function counts(rows) {
  var result={attention:0,working:0,finished:0,failed:0,other:0}
  rows.forEach(function(row){
    if(row.requestId) result.attention++
    else if(busy(row)) result.working++
    else if(row.status==="completed") result.finished++
    else if(row.status==="failed") result.failed++
    else result.other++
  })
  return result
}
function toggle(selected, value, multi) {
  if (!multi) return [value]
  return selected.indexOf(value) >= 0 ? selected.filter(function(v){return v!==value}) : selected.concat([value])
}
function answer(question, selected, custom) {
  var value=String(custom || "").trim()
  if(value && question.allowCustomAnswer) return question.multiSelect ? (selected.indexOf(value)>=0 ? selected.slice() : selected.concat([value])) : [value]
  return selected.slice()
}
function valid(question, values) {return (!question.required || values.length>0) && (question.multiSelect || values.length<=1)}
function optionDescription(option) {
  var description=String(option.description || "").trim()
  return description===String(option.label || "").trim() ? "" : description
}
function duration(row, now, format) {
  if(!row || !row.startedAt) return ""
  var seconds=Math.max(0,Math.floor((row.finishedAt || now)-row.startedAt))
  return format(Math.floor(seconds/60))+":"+(seconds%60<10 ? format(0) : "")+format(seconds%60)
}
// Collapse preparatory run states; metadata refreshes are not transitions.
function alertState(row) {
  return row.requestId ? "request:"+row.requestId : busy(row) ? "running" : row.status
}
function transitions(previous, next) {
  if(previous===null) return []
  return next.filter(function(row) {
    var old=previous.find(function(item){return item.id===row.id})
    var state=alertState(row)
    return state!=="idle" && (old ? alertState(old)!==state : !!row.requestId || busy(row))
  })
}
if(typeof module!=="undefined") module.exports={overviewRows:overviewRows,counts:counts,statusRole:statusRole,statusRank:statusRank,alertState:alertState,transitions:transitions,busy:busy,toggle:toggle,answer:answer,valid:valid,duration:duration,optionDescription:optionDescription}
