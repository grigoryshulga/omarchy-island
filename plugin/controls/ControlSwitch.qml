import QtQuick
import qs.Commons
import qs.Ui
import ".."
import "ControlFocus.js" as Focus

ToggleSwitch {
  id:root
  property bool effectsActive:true
  opacity:enabled ? 1 : Design.disabledOpacity
  onInteractiveChanged:Focus.sync(root,interactive)
  Component.onCompleted:Focus.sync(root,interactive)
  Keys.onSpacePressed:if(interactive && !busy) toggled()
  Keys.onReturnPressed:if(interactive && !busy) toggled()
  Keys.onEnterPressed:if(interactive && !busy) toggled()
  objectName:"controlPowerSwitch"
  foreground:Design.text
  accent:Design.accent
  trackHeight:Style.space(20)
  cursorPad:Design.gap.small
  cursorRing:false
  implicitWidth:trackWidth+2*Design.gap.small
  implicitHeight:Design.controlHeight
  Accessible.role:Accessible.CheckBox
  Accessible.checked:checked
  Rectangle {
    anchors.fill:parent
    visible:root.interactive && (root.activeFocus || root.hasCursor)
    color:"transparent";radius:Design.controlRadius
    border.width:2;border.color:Design.focusRing
  }
  // Native switch owns input and keyboard semantics. An opaque theme-aware
  // face keeps its indicator legible even with low-contrast state overrides.
  Rectangle {
    anchors.centerIn:parent
    width:root.trackWidth;height:root.trackHeight
    radius:root.rounded ? height/2 : 0
    color:root.checked ? Design.selection : Design.raised
    border.width:1;border.color:Design.fieldBorder
    Rectangle {
      width:root.knobSize;height:width
      y:root.knobInset
      x:root.checked!==root.mirrored ? root.trackWidth-root.knobInset-width : root.knobInset
      radius:root.rounded ? width/2 : 0
      color:root.checked ? Design.accent : Design.secondaryText
      Behavior on x {NumberAnimation {duration:Design.feedbackDuration;easing.type:Easing.OutCubic}}
    }
  }
  IndicatorGlow {
    active:root.effectsActive && (root.checked || root.hot) && root.visible
    intensity:root.checked ? 2.8 : 1.6
    accent:root.accent
    width:Style.space(38);height:width
    x:root.width/2-root.trackWidth/2+(root.checked!==root.mirrored ? root.trackWidth-root.knobInset-root.knobSize/2 : root.knobInset+root.knobSize/2)-width/2
    y:(root.height-height)/2
    Behavior on x {NumberAnimation {duration:Preferences.duration(120);easing.type:Easing.OutCubic}}
    z:1
  }
}
