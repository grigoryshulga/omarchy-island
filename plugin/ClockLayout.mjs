// Shared by the bar and its editor. Missing modules retain their saved placement.
export const builtins = [
  {id:"recording",setting:"indicatorRecording",titleKey:"indicator.recording",icon:"●",side:"left"},
  {id:"remote",setting:"indicatorRemote",titleKey:"indicator.remote",icon:"●",side:"left"},
  {id:"reminders",titleKey:"clock.reminders",icon:"󰢌",side:"right"},
  {id:"update",setting:"indicatorUpdate",titleKey:"indicator.updateAvailable",icon:"",side:"right"},
  {id:"microphone",setting:"indicatorMicrophone",titleKey:"indicator.microphoneMuted",icon:"󰍭",side:"right"},
  {id:"dnd",setting:"indicatorDnd",titleKey:"dnd",icon:"󰂛",side:"right"},
  {id:"nightLight",setting:"indicatorNightLight",titleKey:"indicator.nightLight",icon:"󰔎",side:"right"},
  {id:"stayAwake",setting:"indicatorStayAwake",titleKey:"indicator.stayAwake",icon:"",side:"right"}
];
export function catalog(definitions) {
  return definitions.filter(function(entry){return !!entry.indicator}).map(function(entry){
    return {id:"module:"+entry.id,moduleId:entry.id,view:entry.indicator,pageIndex:entry.pageIndex,defaultVisible:entry.indicatorDefault!==false,title:entry.title,titleKey:entry.titleKey,icon:entry.indicatorIcon || "◇",side:"left"};
  }).concat(builtins);
}
export function valid(value) {
  if(value===null) return true;
  try {value=JSON.parse(JSON.stringify(value))} catch(e) {return false}
  if(!Array.isArray(value) || value.length>32) return false;
  var ids=[];
  return value.every(function(row){
    if(!row || typeof row.id!=="string" || !/^[a-zA-Z][a-zA-Z0-9:-]{0,99}$/.test(row.id) || ids.indexOf(row.id)>=0 || ["left","right"].indexOf(row.side)<0 || ["indicator","separator","space"].indexOf(row.kind)<0) return false;
    ids.push(row.id);return true;
  });
}
export function layout(entries,saved,settings) {
  return saved!==null && valid(saved) ? JSON.parse(JSON.stringify(saved)) : entries.filter(function(entry){return entry.defaultVisible!==false && (!entry.setting || !settings || settings[entry.setting]!==false)}).map(function(entry){return {id:entry.id,kind:"indicator",side:entry.side}});
}
export function add(rows,id,side) {
  if(rows.length>=32) return rows;
  var kind=id==="separator" || id==="space" ? id : "indicator";
  if(kind==="indicator" && rows.some(function(row){return row.id===id})) return rows;
  if(kind!=="indicator") {var n=1;while(rows.some(function(row){return row.id===id+":"+n})) n++;id+=":"+n}
  return rows.concat([{id:id,kind:kind,side:side}]);
}
export function move(rows,id,side,before) {
  var row=rows.find(function(row){return row.id===id});
  if(!row || before===id) return rows;
  var out=rows.filter(function(row){return row.id!==id});
  var at=out.findIndex(function(row){return row.id===before && row.side===side});
  out.splice(at<0 ? out.length : at,0,Object.assign({},row,{side:side}));
  return out;
}
export function step(rows,id,delta) {
  var row=rows.find(function(row){return row.id===id});
  if(!row) return rows;
  var peers=rows.filter(function(peer){return peer.side===row.side});
  var at=peers.findIndex(function(peer){return peer.id===id}),to=at+delta;
  if(to<0 || to>=peers.length) return rows;
  return move(rows,id,row.side,delta<0 ? peers[to].id : peers[to+1] ? peers[to+1].id : "");
}
