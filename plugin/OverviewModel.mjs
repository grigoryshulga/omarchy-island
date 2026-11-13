// Pure presentation settings; unknown module IDs survive temporary removal.
export const sizes = ["minimal", "compact", "standard", "large"];
export function valid(value) {
  try {value=JSON.parse(JSON.stringify(value))} catch(e) {return false}
  if(!Array.isArray(value) || value.length>100) return false;
  var seen=[];
  return value.every(function(row) {
    if(!row || typeof row.id!=="string" || !/^[a-zA-Z][a-zA-Z0-9-]{0,79}$/.test(row.id) || seen.indexOf(row.id)>=0 || typeof row.visible!=="boolean" || sizes.indexOf(row.size)<0) return false;
    seen.push(row.id);return true;
  });
}
export function supported(entry) {
  return sizes.filter(function(size){return size==="standard" || (entry.overviewSizes || []).indexOf(size)>=0});
}
export function layout(definitions, saved) {
  var entries=definitions.filter(function(entry){return !!entry.overview});
  var rows=valid(saved) ? saved : [];
  var ids=rows.map(function(row){return row.id});
  entries.sort(function(a,b) {
    var ai=ids.indexOf(a.id),bi=ids.indexOf(b.id);
    return (ai<0 ? ids.length+definitions.indexOf(a) : ai)-(bi<0 ? ids.length+definitions.indexOf(b) : bi);
  });
  return entries.map(function(entry) {
    var row=rows.find(function(row){return row.id===entry.id});
    return {id:entry.id,visible:row ? row.visible : true,size:row && supported(entry).indexOf(row.size)>=0 ? row.size : "standard"};
  });
}
export function update(definitions, saved, id, patch, step) {
  var rows=layout(definitions,saved),at=rows.findIndex(function(row){return row.id===id});
  if(at<0) return rows;
  rows[at]=Object.assign({},rows[at],patch || {});
  var to=Math.max(0,Math.min(rows.length-1,at+(step || 0)));
  if(to!==at) rows.splice(to,0,rows.splice(at,1)[0]);
  return rows.concat((valid(saved) ? saved : []).filter(function(row){return !definitions.some(function(entry){return entry.overview && entry.id===row.id})}));
}
