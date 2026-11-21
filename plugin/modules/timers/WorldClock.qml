import QtQuick
import Quickshell.Io
import qs.Commons
import "../.." as Island

Item {
  id: root
  required property var backend
  required property var presentation
  signal returnToTabs()
  signal closed()
  property bool failed: false
  readonly property var nativeEntry: {
    var bar = presentation.bar
    var layout = bar && bar.shell && bar.shell.barConfig ? bar.shell.barConfig.layout : null
    for (var section of Object.keys(layout || {})) {
      var entry = layout[section].find(row => row && row.id === "omarchy.elsewhen")
      if (entry) return entry
    }
    return null
  }
  readonly property var saved: backend.worldSettings || nativeEntry || ({})
  onSavedChanged: if (panel.item) panel.item.settings=saved
  QtObject {
    id: facade
    readonly property color foreground: Island.Design.text
    readonly property color barForeground: foreground
    readonly property string fontFamily: Island.Design.fontFamily
    readonly property QtObject shell: QtObject {
      function updateEntryInline(id,entry) {
        if (id === "omarchy.elsewhen") root.backend.storeWorldSettings(entry)
      }
    }
    function switchPanelFrom(item,direction) {root.returnToTabs();return true}
  }
  Process {
    id: builder
    command: root.backend.worldCommand
    running:true
    stdout: StdioCollector {id:output; waitForEnd:true}
    onExited:code=>{
      try {
        if (code!==0) throw new Error("Elsewhen adapter unavailable")
        var url=JSON.parse(output.text).url
        if (typeof url!=="string" || !url.startsWith("file:///")) throw new Error("Invalid panel URL")
        panel.setSource(url,{bar:facade,settings:root.saved})
      } catch (error) {root.failed=true}
    }
  }
  Loader {
    id:panel; objectName:"worldClockPanel"; anchors.fill:parent
    onLoaded:item.open()
    onStatusChanged:if(status===Loader.Error) root.failed=true
  }
  Connections {
    target:panel.item
    function onOpenedChanged() {
      if (panel.item && !panel.item.opened) {
        root.closed()
      }
    }
  }
  Island.PlainText {
    anchors.centerIn:parent; width:parent.width
    horizontalAlignment:Text.AlignHCenter; wrapMode:Text.Wrap
    visible:root.failed || !panel.item
    text:root.presentation.strings.t(root.failed ? "timers.worldUnavailable" : "timers.worldLoading")
  }
}
