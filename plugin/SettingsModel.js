// Settings accepted by the Island UI. Unknown shell-entry metadata is preserved.
var defaults = {
  hoverPreview: true, hoverDelay: 140, openingPage: "overview",
  panelAnimation: true, animationsEnabled: true, trackAlerts: true,
  musicVisualization: "visible", musicVisualizationStyle: "default",
  overviewEnabled: true, calendarEnabled: true, weatherEnabled: true,
  notificationStyle: "card", t3Enabled: false, t3Responses: true,
  indicatorRecording: true, indicatorRemote: true, indicatorUpdate: true,
  indicatorMicrophone: true, indicatorDnd: true, indicatorNightLight: true, indicatorStayAwake: true,
  osdVolume: true, osdBrightness: true, osdKeyboard: true, osdLayout: true,
  osdMicrophone: true, osdModes: true
}
var choices = {
  openingPage: ["overview", "controls", "last"],
  musicVisualization: ["off", "open", "visible"],
  musicVisualizationStyle: ["default"], notificationStyle: ["card", "bar"]
}
function valid(key, value) {
  if (!Object.prototype.hasOwnProperty.call(defaults, key)) return false
  if (key === "hoverDelay") return typeof value === "number" && isFinite(value) && value >= 0 && value <= 1000 && Math.floor(value) === value
  if (choices[key]) return choices[key].indexOf(value) >= 0
  return typeof value === "boolean"
}
function get(settings, key) {
  return settings && valid(key, settings[key]) ? settings[key] : defaults[key]
}
function pages(settings, weatherAvailable) {
  var result = [0]
  if (get(settings, "overviewEnabled")) result.push(1)
  if (get(settings, "calendarEnabled")) result.push(2)
  if (get(settings, "weatherEnabled") && weatherAvailable !== false) result.push(3)
  return result
}
function nextPage(pages, current, step) {
  var at = pages.indexOf(current)
  return pages[((at < 0 ? 0 : at) + step + pages.length) % pages.length]
}
function openingPage(settings, last) {
  var available = pages(settings), preferred = get(settings, "openingPage")
  var target = preferred === "last" ? last : preferred === "controls" ? 0 : 1
  return available.indexOf(target) >= 0 ? target : 0
}
function osdKey(kind) {
  return ({volume:"osdVolume",brightness:"osdBrightness",keyboard:"osdKeyboard",layout:"osdLayout",microphone:"osdMicrophone",mode:"osdModes"})[kind] || ""
}
function osdAllowed(settings, kind) { var key = osdKey(kind); return !key || get(settings, key) }
// Row labels and option labels use settings.<key> and settings.option.<value>.
var sections = [
  {id:"behavior",rows:[{key:"hoverPreview"},{key:"hoverDelay",type:"delay"},{key:"openingPage",type:"choice"},{key:"panelAnimation"},{key:"animationsEnabled"}]},
  {id:"sections",rows:[{key:"controlsEnabled",fixed:true},{key:"overviewEnabled"},{key:"calendarEnabled"},{key:"weatherEnabled"}]},
  {id:"music",rows:[{key:"trackAlerts"},{key:"musicVisualization",type:"choice"},{key:"musicVisualizationStyle",type:"choice",fixed:true}]},
  {id:"integrations",rows:[{key:"t3Enabled"},{key:"t3Responses"}]},
  {id:"indicators",rows:[{key:"indicatorDnd"},{key:"indicatorMicrophone"},{key:"indicatorRecording"},{key:"indicatorRemote"},{key:"indicatorNightLight"},{key:"indicatorStayAwake"},{key:"indicatorUpdate"}]},
  {id:"events",rows:[{key:"notificationStyle",type:"choice"},{key:"osdVolume"},{key:"osdBrightness"},{key:"osdKeyboard"},{key:"osdLayout"},{key:"osdMicrophone"},{key:"osdModes"}]}
]
if (typeof module !== "undefined") module.exports = {defaults:defaults,valid:valid,get:get,pages:pages,nextPage:nextPage,openingPage:openingPage,osdAllowed:osdAllowed}
