pragma Singleton
import QtQuick
import Quickshell.Io
import qs.Commons as Commons
import "ThemePaletteModel.js" as Model

QtObject {
  id:root
  property var values:({})
  property FileView file:FileView {
    path:Commons.Color.currentThemePath+"/colors.toml"
    watchChanges:true
    printErrors:false
    onLoaded:root.values=Model.parse(text())
    onFileChanged:reload()
    onLoadFailed:root.values=({})
  }
  // Runtime themes arrive through native IPC; re-read the supplemental roles
  // after that update as well as watching ordinary file edits.
  property Timer refresh:Timer {interval:50;onTriggered:root.file.reload()}
  property Connections theme:Connections {
    target:Commons.Color
    function onShellValuesChanged(){root.refresh.restart()}
    function onAccentChanged(){root.refresh.restart()}
    function onBackgroundChanged(){root.refresh.restart()}
  }
}
