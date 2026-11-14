export default {
  id:"media",titleKey:"media.title",state:"MediaState.qml",order:{overview:-20,settings:0},
  defaults:{trackAlerts:true,musicVisualization:"visible",musicVisualizationStyle:"default",musicVisualizationBackground:"artwork"},
  choices:{musicVisualization:["off","open","visible"],musicVisualizationStyle:["default","ripple","flow","embers","constellations","echo"],musicVisualizationBackground:["artwork","aurora","tide","plasma"]},
  groups:[{id:"music",rows:[{key:"trackAlerts"},{key:"musicVisualization",type:"choice"},{key:"musicVisualizationStyle",type:"choice"},{key:"musicVisualizationBackground",type:"choice"}]}],
  overviewSizes:["minimal", "compact", "large"],
  overview:"modules/media/Overview.qml"
};
