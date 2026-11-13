import {definitions,ordered,pages as registeredPages} from "./ModuleCatalog.mjs";
const validators = {};

// Settings accepted by the Island UI. Unknown shell-entry metadata is preserved.
var defaults = {
  hoverPreview: true, hoverDelay: 140, openingPage: "overview",
  panelAnimation: true, animationsEnabled: true,
  indicatorRecording: true, indicatorRemote: true, indicatorUpdate: true,
  indicatorMicrophone: true, indicatorDnd: true, indicatorNightLight: true, indicatorStayAwake: true,
  osdVolume: true, osdBrightness: true, osdKeyboard: true, osdLayout: true,
  osdMicrophone: true, osdModes: true
}
var choices = {
  openingPage: ["overview", "last"],
}
function valid(key, value) {
  if (!Object.prototype.hasOwnProperty.call(defaults, key)) return false
  if (validators[key]) return validators[key](value)
  if (key === "hoverDelay") return typeof value === "number" && isFinite(value) && value >= 0 && value <= 1000 && Math.floor(value) === value
  if (choices[key]) return choices[key].indexOf(value) >= 0
  return typeof value === "boolean"
}
function get(settings, key) {
  return settings && valid(key, settings[key]) ? settings[key] : defaults[key]
}
function pages(settings, availability) {
  if(availability===false) availability={weather:false}
  return registeredPages().filter(function(entry) {
    return (!entry.enabledSetting || get(settings,entry.enabledSetting)) && (!availability || availability[entry.id]!==false)
  }).map(function(entry){return entry.pageIndex})
}
function nextPage(pages, current, step) {
  var at = pages.indexOf(current)
  return pages[((at < 0 ? 0 : at) + step + pages.length) % pages.length]
}
function openingPage(settings, last) {
  var available = pages(settings), preferred = get(settings, "openingPage")
  var target = preferred === "last" ? last : 1
  return available.indexOf(target) >= 0 ? target : 1
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
    {id:"pages",rows:registeredPages().map(function(entry){return {key:entry.enabledSetting || entry.id+"Enabled",fixed:!entry.enabledSetting}})},
    {id:"indicators",description:true,rows:[{key:"indicatorDnd"},{key:"indicatorMicrophone"},{key:"indicatorRecording"},{key:"indicatorRemote"},{key:"indicatorNightLight"},{key:"indicatorStayAwake"},{key:"indicatorUpdate"}]}
  ]},
  {id:"alerts",groups:[
    {id:"events",description:true,rows:[{key:"osdVolume"},{key:"osdBrightness"},{key:"osdKeyboard"},{key:"osdLayout"},{key:"osdMicrophone"},{key:"osdModes"}]}
  ]},
  {id:"modules",groups:[

  ]}
]
for (const entry of definitions) {
  for (const key of Object.keys(entry.defaults || {})) {
    if (Object.prototype.hasOwnProperty.call(defaults,key)) throw new Error("Duplicate setting: "+key);
    defaults[key]=entry.defaults[key];
  }
  Object.assign(choices,entry.choices || {});
  Object.assign(validators,entry.validators || {});
}
// Each integration contributes to an existing category without host-specific rows.
sections.forEach(function(section) {
  var contributions=[];
  ordered("settings").forEach(function(entry) {
    if((entry.settingsSection || "modules")===section.id)
      (entry.groups || []).forEach(function(group){contributions.push(group)});
  });
  section.groups=contributions.concat(section.groups);
});
export {defaults,choices,valid,get,pages,nextPage,openingPage,osdAllowed,sections};
