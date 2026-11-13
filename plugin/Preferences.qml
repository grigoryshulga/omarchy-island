pragma Singleton
import QtQuick
import qs.Commons
import "SettingsModel.mjs" as Settings

QtObject {
  id: root
  property var values: ({})
  property var visualizers: []
  readonly property bool reduceMotion: Style.reduceMotion || !get("animationsEnabled")
  function get(key) { return Settings.get(values,key) }
  function duration(ms) { return reduceMotion ? 0 : Style.duration(ms) }
  function panelDuration(ms) { return get("panelAnimation") ? duration(ms) : 0 }
  function watchVisualizer(item, active) {
    var remaining=visualizers.filter(function(v){return v!==item})
    if(active) remaining.push(item)
    visualizers=remaining
  }
  function visualizationAllowed(panel) {
    return get("musicVisualization")!=="off" && (!panel || (get("panelAnimation") && get("musicVisualization")==="visible"))
  }
}
