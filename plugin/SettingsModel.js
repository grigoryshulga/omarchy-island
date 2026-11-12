// Agent Limits pin identities are validated before persisting shell settings.
// Settings accepted by the Island UI. Unknown shell-entry metadata is preserved.
var defaults = {
  hoverPreview: true, hoverDelay: 140, openingPage: "overview",
  panelAnimation: true, animationsEnabled: true, trackAlerts: true,
  musicVisualization: "visible", musicVisualizationStyle: "default",
  overviewEnabled: true, calendarEnabled: true, weatherEnabled: true,
  agentLimitsEnabled: false, agentLimitsPins: [], agentLimitsMode: "combined",
  agentLimitsIndicator: "off", agentLimitsWarning: 20, agentLimitsCritical: 5,
  notificationStyle: "card", t3Enabled: false, t3Responses: true,
  indicatorRecording: true, indicatorRemote: true, indicatorUpdate: true,
  indicatorMicrophone: true, indicatorDnd: true, indicatorNightLight: true, indicatorStayAwake: true,
  osdVolume: true, osdBrightness: true, osdKeyboard: true, osdLayout: true,
  osdMicrophone: true, osdModes: true
}
var choices = {
  agentLimitsMode: ["combined", "auto", "pinned"],
  agentLimitsIndicator: ["off", "warning", "always"],
  openingPage: ["overview", "controls", "last"],
  musicVisualization: ["off", "open", "visible"],
  musicVisualizationStyle: ["default"], notificationStyle: ["card", "bar"]
}
function validPins(value) {
  // QML shell settings can expose a QVariantList rather than a JS Array.
  try {value=JSON.parse(JSON.stringify(value))} catch(e) {return false}
  return Array.isArray(value) && value.length<=100 && value.every(function(id){
    if(typeof id!=="string" || id.length>180) return false
    try {var pair=JSON.parse(id);return Array.isArray(pair) && pair.length===2 && /^[a-z0-9-]{1,40}$/.test(pair[0]) && typeof pair[1]==="string" && pair[1].length>0 && pair[1].length<=80} catch(e){return false}
  }) && new Set(value).size===value.length
}
function valid(key, value) {
  if (!Object.prototype.hasOwnProperty.call(defaults, key)) return false
  if (key === "agentLimitsPins") return validPins(value)
  if (key === "agentLimitsWarning" || key === "agentLimitsCritical") return typeof value === "number" && isFinite(value) && Math.floor(value)===value && value>=0 && value<=100
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
  {id:"general",groups:[
    {id:"opening",rows:[{key:"hoverPreview"},{key:"hoverDelay",type:"delay",dependsOn:"hoverPreview"},{key:"openingPage",type:"choice"}]},
    {id:"animations",rows:[{key:"panelAnimation"},{key:"animationsEnabled"}]}
  ]},
  {id:"panel",groups:[
    {id:"pages",rows:[{key:"controlsEnabled",fixed:true},{key:"overviewEnabled"},{key:"calendarEnabled"},{key:"weatherEnabled"}]},
    {id:"indicators",description:true,rows:[{key:"indicatorDnd"},{key:"indicatorMicrophone"},{key:"indicatorRecording"},{key:"indicatorRemote"},{key:"indicatorNightLight"},{key:"indicatorStayAwake"},{key:"indicatorUpdate"}]}
  ]},
  {id:"alerts",groups:[
    {id:"notifications",rows:[{key:"notificationStyle",type:"choice"}]},
    {id:"events",description:true,rows:[{key:"osdVolume"},{key:"osdBrightness"},{key:"osdKeyboard"},{key:"osdLayout"},{key:"osdMicrophone"},{key:"osdModes"}]}
  ]},
  {id:"modules",groups:[
    {id:"music",rows:[{key:"trackAlerts"},{key:"musicVisualization",type:"choice"}]},
    {id:"t3",rows:[{key:"t3Enabled"},{key:"t3Responses",dependsOn:"t3Enabled"}]},
    {id:"limits",rows:[{key:"agentLimitsEnabled"},{key:"agentLimitsMode",type:"choice"},{key:"agentLimitsIndicator",type:"choice"},{key:"agentLimitsWarning",type:"percent"},{key:"agentLimitsCritical",type:"percent"}]}
  ]}
]
if (typeof module !== "undefined") module.exports = {defaults:defaults,valid:valid,get:get,pages:pages,nextPage:nextPage,openingPage:openingPage,osdAllowed:osdAllowed,sections:sections}
