.pragma library

function validPath(path, directory) {
  return typeof path === "string" && path.length <= 4096 && path.indexOf(directory+"/") === 0
    && !/[\x00-\x1f\x7f]/.test(path) && !path.split("/").some(function(p){return p===".." || p==="."})
}
function bytes(value) {return typeof value==="number" && isFinite(value) && value>=0 ? Math.floor(value) : 0}
function retain(rows, directory, now) {
  if(!Array.isArray(rows)) return []
  return rows.filter(function(r){return r && !r.active && validPath(r.downloadPath,directory) && typeof r.ts==="number" && isFinite(r.ts) && r.ts>now-1800 && r.ts<=now+60})
    .slice(0,30).map(function(r){return row(r.downloadPath,r.ts,r.downloadedBytes,false)})
}
function row(path, ts, size, active) {
  var filename=path.substring(path.lastIndexOf("/")+1)
  if(active) filename=filename.replace(/\.(crdownload|part|partial|download|tmp)$/i,"") || filename
  return {key:active ? "active_"+path : "download_"+ts.toString().replace(".","_"),downloadPath:path,ts:ts,
    active:!!active,filename:filename,downloadedBytes:bytes(size),summary:filename}
}
function sizeText(value, format) {
  var size=bytes(value), units=["B","KiB","MiB","GiB","TiB"],unit=0
  while(size>=1024 && unit<units.length-1) {size/=1024;unit++}
  var number=unit===0 ? size : Math.round(size*10)/10
  return (format ? format(number) : String(number))+" "+units[unit]
}
