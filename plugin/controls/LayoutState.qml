import QtQuick
import Quickshell
import ".." as Island
import "Layout.js" as Model

Item {
  id:root
  property bool allowed:true
  property var layout:Model.normalize({})
  property string stateDir:Quickshell.env("HOME")+"/.local/state/omarchy/island"
  readonly property bool ready:storage.ready
  readonly property string error:storage.error
  function commit(value) {if(!ready) return;layout=Model.normalize(value);storage.save({version:1,layout:layout})}
  function favorite(key){commit(Model.favorite(layout,key))}
  function toggle(key){commit(Model.toggle(layout,key))}
  function move(group,key,target){commit(Model.move(layout,group,key,target))}
  function add(key){var next=Model.normalize(layout);if(next.main.indexOf(key)<0) next.main.push(key);next.hidden=next.hidden.filter(function(value){return value!==key});commit(next)}
  function reset(){commit({})}
  Island.ModuleStorage {
    id:storage;enabled:root.allowed
    path:root.stateDir+"/controls.json"
    legacyPath:root.stateDir+"/controls-no-legacy.json"
    onLoaded:(text,status)=>{root.layout=Model.normalize(JSON.parse(text).layout);storage.save({version:1,layout:root.layout})}
  }
}
