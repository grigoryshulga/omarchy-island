export default {
  order:{overview:20,indicator:10,settings:10},
  id: "t3", title: "T3 Code", state: "T3State.qml",
  overview: "modules/t3/Overview.qml", indicator: "modules/t3/Indicator.qml",
  defaults: {t3Enabled:false, t3Responses:true},
  groups: [{id:"t3",moduleId:"t3",view:"modules/t3/Settings.qml",rows:[{key:"t3Enabled"},{key:"t3Responses",dependsOn:"t3Enabled"}]}]
};
