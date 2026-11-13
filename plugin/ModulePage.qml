import QtQuick
ModuleView {
  property bool navigationHidden:false
  property bool ownsKeys:false
  property real stableHeight:implicitHeight
  function back(){return false}
  function enter(){}
  function cancelEditing(){}
  function focusPrimary(){return false}
  function handleKey(event){return false}
}
