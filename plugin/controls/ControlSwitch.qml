import QtQuick
import qs.Commons
import qs.Ui
import ".."

ToggleSwitch {
  id:root
  trackHeight:Style.space(16)
  cursorPad:Style.space(4)
  IndicatorGlow {
    active:(root.checked || root.hot) && root.visible
    intensity:root.checked ? 2.8 : 1.6
    accent:root.accent
    width:Style.space(38);height:width
    x:root.width/2-root.trackWidth/2+(root.checked!==root.mirrored ? root.trackWidth-root.knobInset-root.knobSize/2 : root.knobInset+root.knobSize/2)-width/2
    y:(root.height-height)/2
    Behavior on x {NumberAnimation {duration:Style.duration(120);easing.type:Easing.OutCubic}}
    z:1
  }
}
