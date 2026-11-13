import QtQuick

// A view is per popup/monitor; its backend is shared by the shell.
Item {
  property bool navigationHidden:false
  property bool ownsKeys:false
  function back(){return false}
  property var backend:null
  property var presentation:null
  property var toastIcon:null
  property bool interactionHovered:false
  signal closeRequested()
  property bool available:false
  property string tooltip:""
  signal expandRequested()
  signal detailsRequested()
  signal settingRequested(string key,var value)
}
