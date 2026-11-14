export default {
  id:"codex", title:"Codex", state:"CodexState.qml",
  order:{overview:21,indicator:11,settings:11}, indicatorIcon:"󰚩", indicatorDefault:false,
  overview:"modules/codex/Overview.qml", indicator:"modules/t3/Indicator.qml",
  defaults:{codexEnabled:false,codexResponses:true},
  groups:[{id:"codex",moduleId:"codex",view:"modules/codex/Settings.qml",rows:[{key:"codexEnabled"},{key:"codexResponses",dependsOn:"codexEnabled"}]}]
};
