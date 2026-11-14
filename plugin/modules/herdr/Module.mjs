export default {
  id:"herdr", title:"Herdr", state:"HerdrState.qml",
  order:{overview:21,indicator:11,settings:11}, indicatorIcon:"󰆍",
  overview:"modules/herdr/Overview.qml", indicator:"modules/herdr/Indicator.qml",
  defaults:{herdrEnabled:false,herdrRemote:false},
  groups:[{id:"herdr",moduleId:"herdr",view:"modules/herdr/Settings.qml",rows:[{key:"herdrEnabled"},{key:"herdrRemote",dependsOn:"herdrEnabled"}]}]
};
