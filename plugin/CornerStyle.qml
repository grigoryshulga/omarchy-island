pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "CornerGeometry.js" as Geometry

QtObject {
  id: root
  property real roundingPower: 2
  property int borderWidth: 2
  function applyPowerJson(raw) { roundingPower=Geometry.parsePower(raw,roundingPower) }
  function applyBorderWidthJson(raw) { borderWidth=Geometry.parseBorderWidth(raw,borderWidth) }
  function refresh() { query.running=true; borderQuery.running=true }
  Component.onCompleted: refresh()
  property Process query: Process {
    command:["hyprctl","-j","getoption","decoration:rounding_power"]
    stdout:StdioCollector {onStreamFinished:root.applyPowerJson(text)}
  }
  property Process borderQuery: Process {
    command:["hyprctl","-j","getoption","general:border_size"]
    stdout:StdioCollector {onStreamFinished:root.applyBorderWidthJson(text)}
  }
  property Connections events:Connections {
    target:Hyprland
    function onRawEvent(event) {if(event && String(event.name)==="configreloaded") root.refresh()}
  }
}
