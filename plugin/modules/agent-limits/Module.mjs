function validPins(value) {
  // QML shell settings can expose a QVariantList rather than a JS Array.
  try {value=JSON.parse(JSON.stringify(value))} catch(e) {return false}
  return Array.isArray(value) && value.length<=100 && value.every(function(id){
    if(typeof id!=="string" || id.length>180) return false
    try {var pair=JSON.parse(id);return Array.isArray(pair) && pair.length===2 && /^[a-z0-9-]{1,40}$/.test(pair[0]) && typeof pair[1]==="string" && pair[1].length>0 && pair[1].length<=80} catch(e){return false}
  }) && new Set(value).size===value.length
}
export default {
  order:{overview:10,indicator:20,settings:20},
  id: "agentLimits", titleKey: "limits.title", state: "AgentLimitsState.qml",
  overview: "modules/agent-limits/Overview.qml", indicator: "modules/agent-limits/Indicator.qml",
  overviewSizes: ["compact", "standard"],
  defaults: {agentLimitsEnabled:false, agentLimitsPins:[], agentLimitsMode:"combined",
    agentLimitsIndicator:"off", agentLimitsWarning:20, agentLimitsCritical:5},
  choices: {agentLimitsMode:["combined","auto","pinned"],agentLimitsIndicator:["off","warning","always"]},
  validators: {
    agentLimitsPins: validPins,
    agentLimitsWarning: percent,
    agentLimitsCritical: percent
  },
  groups: [{id:"limits",rows:[{key:"agentLimitsEnabled"},{key:"agentLimitsMode",type:"choice"},{key:"agentLimitsIndicator",type:"choice"},{key:"agentLimitsWarning",type:"percent"},{key:"agentLimitsCritical",type:"percent"}]}]
};
function percent(value) {return typeof value === "number" && isFinite(value) && Math.floor(value)===value && value>=0 && value<=100}
