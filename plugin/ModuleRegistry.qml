import QtQuick
import "ModuleCatalog.mjs" as Catalog

Item {
  id:root
  property var host:null
  property var definitions:Catalog.definitions
  // Initial properties are supplied before collectors can start.
  property var stateProperties:({})
  readonly property string error: {
    var messages=[]
    Object.keys(backends).forEach(function(id){var backend=backends[id];if(backend && backend.error) messages.push(backend.error)})
    return messages.filter(function(message,index){return messages.indexOf(message)===index}).join("; ")
  }
  readonly property var backends: {
    var result={}
    for(var i=0;i<states.count;i++) {
      var loader=states.itemAt(i)
      if(loader && loader.item) result[loader.modelData.id]=loader.item
    }
    return result
  }
  Repeater {
    id:states
    model:root.definitions.filter(function(entry){return !!entry.state})
    Loader {
      required property var modelData
      Component.onCompleted:setSource(Qt.resolvedUrl(modelData.state),Object.assign({},modelData.usesHost ? {host:root.host} : {},root.stateProperties[modelData.id] || {}))
    }
  }
}
