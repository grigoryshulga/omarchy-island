pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "CornerGeometry.js" as Geometry

QtObject {
  id: root
  property real roundingPower: 2
  function applyPowerJson(raw) { roundingPower=Geometry.parsePower(raw,roundingPower) }
  Component.onCompleted: query.running=true
  property Process query: Process {
    command:["hyprctl","-j","getoption","decoration:rounding_power"]
    stdout:StdioCollector {onStreamFinished:root.applyPowerJson(text)}
  }
  property Connections events:Connections {
    target:Hyprland
    function onRawEvent(event) {if(event && String(event.name)==="configreloaded") root.query.running=true}
  }
}
