// Controls owns favorites, tile order and grid spans; Settings can move but must remain reachable.
var mainDefaults = ["audio", "bluetooth", "network", "tailscale", "monitors", "settings"]
var favoriteDefaults = ["audio", "bluetooth", "network", "dnd", "nightLight"]
var quickDefaults = ["microphone", "dnd", "nightLight", "stayAwake", "recording", "remote"]
function safeKey(key) {
  return typeof key === "string" && (mainDefaults.concat(quickDefaults).indexOf(key) >= 0
    || /^plugin:[A-Za-z0-9][A-Za-z0-9._-]{0,159}$/.test(key))
}
function sectionKey(key) { return typeof key === "string" && /^section:[0-9]{1,6}$/.test(key) }
function normalize(data) {
  data = data || {}
  function ordered(rows, defaults, external) {
    var result = []
    if (Array.isArray(rows)) rows.slice(0, 256).forEach(function(key) {
      if ((safeKey(key) || external && sectionKey(key)) && (sectionKey(key) || defaults.indexOf(key) >= 0 || external && key.indexOf("plugin:") === 0) && result.indexOf(key) < 0) result.push(key)
    })
    defaults.forEach(function(key) {if (result.indexOf(key) < 0) result.push(key)})
    return result
  }
  var favorites = Array.isArray(data.favorites) ? data.favorites.filter(function(key,index,rows){return safeKey(key) && rows.indexOf(key)===index}).slice(0,32) : favoriteDefaults.slice()
  return {favorites:favorites, main:ordered(data.main, mainDefaults, true).filter(function(key){return !sectionKey(key)}), quick:ordered(data.quick, quickDefaults, false),
    order:ordered(data.order || ordered(data.main,mainDefaults,true).concat(ordered(data.quick,quickDefaults,false)), mainDefaults.concat(quickDefaults), true), sizes:normalizeSizes(data.sizes), labels:normalizeLabels(data.labels), sections:normalizeSections(data.sections),
    hidden:Array.isArray(data.hidden) ? data.hidden.filter(function(key,index,rows) {return safeKey(key) && key !== "settings" && rows.indexOf(key)===index}).slice(0, 256) : []}
}
function move(data, group, key, target) {
  var next = normalize(data)
  if (["main", "quick", "favorites", "order"].indexOf(group)<0) return next
  var rows = next[group]
  if (!rows || rows.indexOf(key) < 0 || rows.indexOf(target) < 0) return next
  var index = rows.indexOf(target)
  rows.splice(rows.indexOf(key), 1)
  rows.splice(index, 0, key)
  if(group==="main" || group==="quick") {
    var at=next.order.indexOf(target)
    next.order.splice(next.order.indexOf(key),1)
    next.order.splice(at,0,key)
  } else if(group==="order") {
    next.main=next.order.filter(function(value){return mainDefaults.indexOf(value)>=0 || value.indexOf("plugin:")===0})
    next.quick=next.order.filter(function(value){return quickDefaults.indexOf(value)>=0})
  }
  return next
}
function toggle(data, key) {
  var next = normalize(data)
  if (!safeKey(key) || key === "settings") return next
  var index = next.hidden.indexOf(key)
  if (index >= 0) next.hidden.splice(index, 1)
  else next.hidden.push(key)
  return next
}

function favorite(data,key) {
  var next=normalize(data), index=next.favorites.indexOf(key)
  if(!safeKey(key)) return next
  if(index>=0) next.favorites.splice(index,1)
  else if(next.favorites.length<32) next.favorites.push(key)
  return next
}

// Persist only bounded spans; old layouts retain their panel order and half-width tiles.
function normalizeSizes(sizes) {
  var result = {}
  if (!sizes || typeof sizes !== "object") return result
  Object.keys(sizes).slice(0,256).forEach(function(key) {
    if (!safeKey(key)) return
    var value = sizes[key] || {}
    result[key] = {width:span(value.width,4,2), height:span(value.height,4,1)}
  })
  return result
}
function span(value, max, fallback) {
  return typeof value === "number" && isFinite(value) ? Math.max(1,Math.min(max,Math.round(value))) : fallback
}
function resize(data,key,width,height) {
  var next=normalize(data)
  if(safeKey(key)) next.sizes[key]={width:span(width,4,2),height:span(height,4,1)}
  return next
}
function tiles(data) {
  var next=normalize(data), occupied=[], result=[]
  // Sequential packing keeps visual order identical to keyboard and saved order.
  var cursor=0
  next.order.filter(function(key){return next.hidden.indexOf(key)<0}).forEach(function(key) {
    if(sectionKey(key)) {
      var bottom=occupied.length ? Math.ceil(occupied.length/4) : 0
      var section=next.sections[key] || {title:"",gap:0}
      result.push({key:key,column:0,row:bottom+section.gap,width:4,height:1,section:true})
      cursor=(bottom+section.gap+1)*4
      for(var cell=0;cell<cursor;cell++) occupied[cell]=true
      return
    }
    var size=next.sizes[key] || {width:2,height:1}, at=cursor
    while(true) {
      var col=at%4,row=Math.floor(at/4), fits=col+size.width<=4
      for(var y=0;fits && y<size.height;y++) for(var x=0;x<size.width;x++) if(occupied[(row+y)*4+col+x]) fits=false
      if(fits) break
      at++
    }
    for(var y=0;y<size.height;y++) for(var x=0;x<size.width;x++) occupied[(row+y)*4+col+x]=true
    result.push({key:key,column:col,row:row,width:size.width,height:size.height})
    cursor=at+size.width
  })
  return result
}

function cleanText(value,limit) {
  return typeof value === "string" ? value.replace(/[\x00-\x1f\x7f]/g, "").trim().slice(0,limit) : ""
}
function normalizeLabels(labels) {
  var result={}
  if(labels && typeof labels === "object") Object.keys(labels).slice(0,256).forEach(function(key){
    if(safeKey(key)) result[key]={title:cleanText((labels[key] || {}).title,80),icon:cleanText((labels[key] || {}).icon,16)}
  })
  return result
}
function normalizeSections(sections) {
  var result={}
  if(sections && typeof sections === "object") Object.keys(sections).slice(0,64).forEach(function(key){
    if(sectionKey(key)) result[key]={title:cleanText((sections[key] || {}).title,80),gap:span((sections[key] || {}).gap+1,5,1)-1}
  })
  return result
}
function label(data,key,title,icon) {
  var next=normalize(data)
  if(safeKey(key)) next.labels[key]={title:cleanText(title,80),icon:cleanText(icon,16)}
  return next
}
function addSection(data,before,title) {
  var next=normalize(data),id=1
  if(next.order.filter(sectionKey).length>=64) return next
  while(next.order.indexOf("section:"+id)>=0) id++
  var key="section:"+id,index=next.order.indexOf(before)
  next.order.splice(index<0 ? next.order.length : index,0,key)
  next.sections[key]={title:cleanText(title,80),gap:0}
  return next
}
function section(data,key,title,gap) {
  var next=normalize(data)
  if(sectionKey(key)) next.sections[key]={title:cleanText(title,80),gap:span(gap+1,5,1)-1}
  return next
}
function removeSection(data,key) {
  var next=normalize(data)
  if(sectionKey(key)) {next.order=next.order.filter(function(k){return k!==key});delete next.sections[key]}
  return next
}
