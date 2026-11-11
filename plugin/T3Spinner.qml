import QtQuick
import qs.Commons

Item {
  id:root
  property bool active:true
  property color tint:Design.accent
  readonly property bool animating:active && visible && !Preferences.reduceMotion
  readonly property string frames:"⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  property int frame:0
  implicitWidth:Style.space(16)
  implicitHeight:implicitWidth
  onAnimatingChanged:if(!animating) frame=0
  Text {
    objectName:"t3SpinnerGlyph"
    anchors.fill:parent
    text:root.frames[root.frame]
    textFormat:Text.PlainText
    color:root.tint
    font.family:Design.fontFamily
    font.pixelSize:Math.min(root.width,root.height)
    horizontalAlignment:Text.AlignHCenter
    verticalAlignment:Text.AlignVCenter
  }
  Timer {
    interval:Design.spinnerDuration/root.frames.length
    running:root.animating;repeat:true
    onTriggered:root.frame=(root.frame+1)%root.frames.length
  }
}
