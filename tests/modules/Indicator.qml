import QtQuick
import "../.." as Island
Island.ModuleView {
  // The host suppresses a disabled backend even if a view has content.
  available:!!backend
  implicitWidth:20;implicitHeight:20
  tooltip:"Sample"
}
