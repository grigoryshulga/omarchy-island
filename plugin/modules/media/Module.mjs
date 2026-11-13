export default {
  id:"media",titleKey:"media.title",state:"MediaState.qml",order:{overview:-20,settings:0},
  defaults:{trackAlerts:true,musicVisualization:"visible",musicVisualizationStyle:"default"},
  choices:{musicVisualization:["off","open","visible"],musicVisualizationStyle:["default"]},
  groups:[{id:"music",rows:[{key:"trackAlerts"},{key:"musicVisualization",type:"choice"}]}],
  overview:"modules/media/Overview.qml"
};
