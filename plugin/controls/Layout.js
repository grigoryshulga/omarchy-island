// Controls owns favorites and both full-view groups; Settings can move but must remain reachable.
var mainDefaults = ["audio", "bluetooth", "network", "tailscale", "monitors", "settings"]
var favoriteDefaults = ["audio", "bluetooth", "network", "dnd", "nightLight"]
var quickDefaults = ["microphone", "dnd", "nightLight", "stayAwake", "recording", "remote"]
function safeKey(key) {
  return typeof key === "string" && (mainDefaults.concat(quickDefaults).indexOf(key) >= 0
    || /^plugin:[A-Za-z0-9][A-Za-z0-9._-]{0,159}$/.test(key))
}
function normalize(data) {
  data = data || {}
  function ordered(rows, defaults, external) {
    var result = []
    if (Array.isArray(rows)) rows.slice(0, 256).forEach(function(key) {
      if (safeKey(key) && (defaults.indexOf(key) >= 0 || external && key.indexOf("plugin:") === 0) && result.indexOf(key) < 0) result.push(key)
    })
    defaults.forEach(function(key) {if (result.indexOf(key) < 0) result.push(key)})
    return result
  }
  var favorites = Array.isArray(data.favorites) ? data.favorites.filter(function(key,index,rows){return safeKey(key) && rows.indexOf(key)===index}).slice(0,32) : favoriteDefaults.slice()
  return {favorites:favorites, main:ordered(data.main, mainDefaults, true), quick:ordered(data.quick, quickDefaults, false),
    hidden:Array.isArray(data.hidden) ? data.hidden.filter(function(key,index,rows) {return safeKey(key) && key !== "settings" && rows.indexOf(key)===index}).slice(0, 256) : []}
}
function move(data, group, key, target) {
  var next = normalize(data)
  if (["main", "quick", "favorites"].indexOf(group)<0) return next
  var rows = next[group]
  if (!rows || rows.indexOf(key) < 0 || rows.indexOf(target) < 0) return next
  var index = rows.indexOf(target)
  rows.splice(rows.indexOf(key), 1)
  rows.splice(index, 0, key)
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
