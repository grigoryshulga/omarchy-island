.pragma library

function mediaPlayer(p, allowed) {
  if (!p) return false
  if (!allowed || allowed.length === 0) return true
  var identity = String(p.identity || "") + " " + String(p.desktopEntry || "") + " " + String(p.dbusName || "")
  return allowed.some(function(name) {
    return identity.toLowerCase().indexOf(String(name).toLowerCase()) >= 0
  })
}
// Keep an explicit selection; otherwise prefer playback, then paused media.
function selectMediaPlayer(players, preferred, stoppedState) {
  return players.find(function(p) { return p.dbusName === preferred })
    || players.find(function(p) { return p.isPlaying })
    || players.find(function(p) { return hasMedia(p, stoppedState) })
    || players[0] || null
}
function time(seconds) {
  var s = Math.max(0, Math.floor(Number(seconds) || 0))
  return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
}
function plain(s) {
  return String(s || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
}
function source(row) { return String(row.source || row.app || "Unknown") }
// Reconcile identity separately from row data: JS array Repeater models destroy
// every delegate even when only the body of one notification changed.
function syncKeys(model, keys) {
  for (var at=model.count-1; at>=0; --at)
    if (keys.indexOf(model.get(at).entryKey)<0) model.remove(at)
  for (var i=0; i<keys.length; ++i) {
    var found=-1
    for (var j=i; j<model.count; ++j)
      if (model.get(j).entryKey===keys[i]) {found=j;break}
    if (found<0) model.insert(i,{entryKey:keys[i]})
    else if (found!==i) model.move(found,i,1)
  }
}
function notificationKey(row) { return JSON.stringify([source(row), String(row.summary || "")]) }
function collect(live, history) {
  var seen = {}, out = []
  live.concat(history).forEach(function(row) {
    if (!row || !row.key || seen[row.key]) return
    seen[row.key] = true
    out.push(row)
  })
  return out.sort(function(a,b) { return b.ts - a.ts }).slice(0,100)
}

// Spend the preview's three-message budget before grouping. Each source still
// reports everything behind its visible messages, including folded history.
function previewGroups(rows, limit) {
  var groups = [], total = {}, bySource = {}
  rows.forEach(function(row) { var key = source(row); total[key] = (total[key] || 0) + 1 })
  rows.slice(0,limit).forEach(function(row,index) {
    var key = source(row)
    if (!bySource[key]) { bySource[key] = {source:key, rows:[], positions:[], total:total[key]}; groups.push(bySource[key]) }
    bySource[key].rows.push(row)
    bySource[key].positions.push(index)
  })
  return groups
}

// A paused track remains controllable; a stopped/empty player has no panel.
function hasMedia(player, stoppedState) {
  return !!player && player.playbackState !== stoppedState
    && (String(player.trackTitle || "").trim() !== "" || String(player.trackArtist || "").trim() !== "")
}

// Presentation only: originals remain independent so sender recalls and
// replacements remove/update exactly one message, including in history.
function coalesceNotifications(rows) {
  var groups = [], byHeader = Object.create(null)
  rows.forEach(function(row) {
    var key = notificationKey(row)
    if (!byHeader[key]) { byHeader[key] = []; groups.push(byHeader[key]) }
    byHeader[key].push(row)
  })
  return groups.map(function(members) {
    if (members.length === 1) return members[0]
    var ordered = members.slice().sort(function(a,b) { return b.ts-a.ts })
    var row = Object.assign({}, ordered[0])
    row.members = ordered
    row.body = ordered.slice().reverse().map(function(r) { return plain(r.body) }).filter(function(body) { return body !== "" }).join("\n")
    return row
  })
}

// Equivalent sender actions share one button. Keep each original target so
// "Mark as read" acknowledges all messages represented by the card.
function notificationActions(row, resolve) {
  var actions = [], byAction = Object.create(null)
  ;(row.members || [row]).forEach(function(member) {
    resolve(member).forEach(function(action) {
      var key = JSON.stringify([action.id, action.text])
      if (!byAction[key]) {
        byAction[key] = {id:action.id, text:action.text, targets:[]}
        actions.push(byAction[key])
      }
      byAction[key].targets.push(member)
    })
  })
  return actions
}
