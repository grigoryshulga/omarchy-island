.pragma library

// Walk civil dates in UTC so DST transitions cannot duplicate a grid cell.
function civilDate(year,month,day) {
  var date = new Date(0)
  date.setUTCFullYear(year,month,day)
  date.setUTCHours(12,0,0,0)
  return date
}
function key(year,month,day) {
  return String(year).padStart(4,"0")+"-"+String(month+1).padStart(2,"0")+"-"+String(day).padStart(2,"0")
}
function parts(date) {
  var y=date.getUTCFullYear(), m=date.getUTCMonth(), d=date.getUTCDate()
  return {year:y,month:m,day:d,key:key(y,m,d)}
}
function localDate(year,month,day) {
  var date=new Date(0)
  date.setFullYear(year,month,day)
  date.setHours(12,0,0,0)
  return date
}
function weekdays(start) {
  return Array.from({length:7},function(_,i) { return (start+i)%7 })
}
function monthCells(year,month,start,today) {
  var first=civilDate(year,month,1)
  var leading=(first.getUTCDay()-start+7)%7
  var out=[]
  for(var i=0;i<42;i++) {
    var date=civilDate(year,month,1-leading+i), cell=parts(date)
    cell.inMonth=cell.year===year && cell.month===month
    cell.today=cell.key===today
    out.push(cell)
  }
  return out
}
function stepMonth(year,month,delta) { return parts(civilDate(year,month+delta,1)) }
function stepDay(day,delta) { return parts(civilDate(day.year,day.month,day.day+delta)) }
