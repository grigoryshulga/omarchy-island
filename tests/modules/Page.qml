import QtQuick
import "../.." as Island
Island.ModulePage {
  objectName:"samplePage"
  available:!!backend && backend.allowed
  implicitHeight:240
}
