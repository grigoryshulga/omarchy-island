import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "KeyboardLayoutModel.js" as Model

Item {
  id:root
  property bool active:false
  property bool observeSystem:true
  property string currentLanguage:""
  property int revision:0
  signal switched(string language)
  function seed(raw,requestRevision) {
    if(requestRevision!==revision) return
    try {
      var devices=JSON.parse(raw).keyboards
      if(!Array.isArray(devices)) return
      var typed=devices.filter(function(k){return k && Model.isTypedKeyboard(k.name)})
      var selected=Model.selectKeyboard(typed,"")
      if(selected && selected.active_keymap) currentLanguage=Model.languageName(selected.active_keymap,{})
    } catch(e) {}
  }
  function handleEvent(event) {
    if(!active) return
    var layout=Model.eventLayout(event)
    if(!layout) return
    revision++
    var language=Model.languageName(layout.description,{})
    if(language===currentLanguage) return
    currentLanguage=language
    switched(language)
  }
  onActiveChanged:if(active && observeSystem && !query.running) {
    query.requestRevision=revision
    query.running=true
  }
  Connections {target:Hyprland;function onRawEvent(event){if(root.observeSystem) root.handleEvent(event)}}
  Process {
    id:query
    property int requestRevision:0
    command:["hyprctl","-j","devices"]
    stdout:StdioCollector {waitForEnd:true;onStreamFinished:root.seed(text,query.requestRevision)}
  }
  Timer {interval:5000;running:query.running;onTriggered:query.running=false}
}
