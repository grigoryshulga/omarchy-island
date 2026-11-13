import QtQuick
import "../.." as Island
Item {
  property bool allowed:Island.Preferences.get("sampleEnabled")
  property int ticks:0
  Timer {interval:20;repeat:true;running:parent.allowed;onTriggered:parent.ticks++}
}
