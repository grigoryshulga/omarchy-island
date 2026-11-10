import QtQuick
import qs.Ui

Button {
  id: root
  property var feedback: null
  Connections {
    target: root
    function onClicked() { if(root.feedback) root.feedback.pulseFrom(root) }
  }
}
