// Presentation helpers; bridge data and answers never become shell text.
var busyStates = ["preparing", "starting", "queued", "running", "waiting"]
function busy(row) { return row && busyStates.indexOf(row.status) >= 0 }
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
if(typeof module!=="undefined") module.exports={busy:busy,toggle:toggle,answer:answer,valid:valid,duration:duration,optionDescription:optionDescription}
