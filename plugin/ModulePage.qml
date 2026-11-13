import QtQuick
ModuleView {
  property real stableHeight:implicitHeight
  function enter(){}
  function cancelEditing(){}
  function focusPrimary(){return false}
  function handleKey(event){return false}
}
