import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PowerModel.js" as Model

Item {
  id:root
  required property var strings
  property var externalFeedback:null
  property bool active:false
  property var power:localPower
  signal expandRequested()
  readonly property bool present:power && power.present
  readonly property string mode:power && power.device ? Model.modeLabel(power.device,power.onBattery,power.states,Commons.I18n.t) : ""
  readonly property string remaining:{
    var minutes=power ? Math.round(power.secondsRemaining/60) : 0
    if(minutes<=0) return ""
    return minutes>=60 ? strings.t("battery.hoursMinutes").arg(Commons.I18n.formatNumber(Math.floor(minutes/60))).arg(Commons.I18n.formatNumber(minutes%60)) : strings.t("battery.minutes").arg(Commons.I18n.formatNumber(minutes))
  }
  visible:present
  implicitHeight:present ? content.implicitHeight : 0
  PowerState {id:localPower;active:root.active && root.power===localPower}
  function profileLabel(profile) {return Model.profileLabel(profile,Commons.I18n.t)}
  function focusProfile() {
    if(!profileMenu.opened || !power || power.busy || !choices.count) return
    choices.itemAt(Math.max(0,power.profiles.indexOf(power.activeProfile))).forceActiveFocus()
  }
  function toggleMenu() {
    if(profileMenu.opened) {profileMenu.close();return}
    if(!power || !power.profiles.length) return
    expandRequested()
    power.refresh()
    Qt.callLater(function(){if(root.active && root.present) profileMenu.open()})
  }
  onActiveChanged:if(!active) profileMenu.close()
  onVisibleChanged:if(!visible) profileMenu.close()
  ColumnLayout {
    id:content
    width:parent.width
    spacing:Design.gap.small
    RowLayout {
      Layout.fillWidth:true
      Layout.preferredHeight:Style.space(30)
      spacing:Design.gap.small
      PlainText {
        text:root.power ? root.power.icon : ""
        font.pixelSize:Style.font.icon
        color:chargeGauge.accent
      }
      PlainText {
        objectName:"batteryPercentage"
        text:root.power ? Commons.I18n.formatNumber(Math.round(root.power.fraction*100))+"%" : ""
        typeRole:"caption"
        font.bold:true
      }
      PlainText {
        Layout.fillWidth:true
        text:root.remaining && root.width>Style.space(430) ? root.mode+" · "+root.remaining : root.mode
        elide:Text.ElideRight
        typeRole:"caption"
        color:Design.secondaryText
      }
      ActionButton {
        id:profileButton
        objectName:"batteryProfileButton"
        feedback:root.externalFeedback
        visible:root.power && root.power.profiles.length>0
        enabled:!root.power.busy
        text:root.power && root.power.activeProfile ? root.profileLabel(root.power.activeProfile) : root.strings.t("battery.profile")
        iconText:root.power ? Model.profileIcon(root.power.activeProfile) : ""
        tooltipText:root.strings.t("battery.profile")
        horizontalPadding:Design.gap.small;verticalPadding:Design.gap.micro
        onClicked:root.toggleMenu()
      }
    }
    BatteryGauge {
      id:chargeGauge
      Layout.fillWidth:true
      fraction:root.power ? root.power.fraction : 0
      active:root.active
      charging:!!(root.power && root.power.device && root.power.device.state===root.power.states.Charging && !Model.chargeThresholdActive(root.power.device,root.power.onBattery,root.power.states))
    }
  }
  Controls.Popup {
    id:profileMenu
    objectName:"batteryProfileMenu"
    parent:profileButton
    x:Commons.I18n.rightToLeft ? 0 : profileButton.width-width
    y:profileButton.height+Style.space(5)
    width:Style.space(190)
    padding:Design.gap.small
    focus:true
    closePolicy:Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    enter:Transition {NumberAnimation {property:"opacity";from:0;to:1;duration:Preferences.duration(160)}}
    exit:Transition {NumberAnimation {property:"opacity";to:0;duration:Preferences.duration(100)}}
    background:BorderSurface {color:Design.canvas;borderSpec:Border.surfaceSpec("popups","border",Commons.Color.popups.border,Math.max(1,Style.space(2)));radius:Design.cardRadius}
    onOpened:{root.power.refresh();Qt.callLater(root.focusProfile)}
    onClosed:if(root.active) profileButton.forceActiveFocus()
    contentItem:Item {
      id:menuContent
      implicitHeight:menuColumn.implicitHeight
      Column {
        id:menuColumn
        width:parent.width
        spacing:Design.gap.tight
      Repeater {
        id:choices
        model:root.power ? root.power.profiles : []
        ActionButton {
          required property string modelData
          required property int index
          objectName:"batteryProfile-"+modelData
          width:menuContent.width
          text:root.profileLabel(modelData)
          iconText:Model.profileIcon(modelData)
          selected:root.power && root.power.activeProfile===modelData
          enabled:root.power && !root.power.busy
          leftAlign:true
          feedback:menuFeedback
          background:"transparent"
          onClicked:root.power.setProfile(modelData)
          Keys.onPressed:event=>{
            var text=String(event.text || "").toLowerCase()
            if(text==="j" || text==="о") {choices.itemAt((index+1)%choices.count).forceActiveFocus();event.accepted=true}
            else if(text==="k" || text==="л") {choices.itemAt((index+choices.count-1)%choices.count).forceActiveFocus();event.accepted=true}
            else event.accepted=false
          }
          Keys.onDownPressed:choices.itemAt((index+1)%choices.count).forceActiveFocus()
          Keys.onUpPressed:choices.itemAt((index+choices.count-1)%choices.count).forceActiveFocus()
        }
      }
      PlainText {width:parent.width;visible:root.power && root.power.error!=="";text:root.strings.t("battery.profileFailed");color:Design.danger;typeRole:"caption";wrapMode:Text.Wrap}
      }
      BrailleSpotlight {id:menuGlow;surfaceRoot:menuContent;anchors.fill:parent;active:menuHover.hovered;pointer:menuHover.point.position;spotRadius:Style.space(55);intensity:1.8;z:10}
      HoverHandler {id:menuHover}
      BrailleFeedback {id:menuFeedback;surface:menuContent;effect:menuGlow;hover:menuHover}
    }
  }
  Connections {
    target:root.power
    function onProfileApplied(success) {if(success) profileMenu.close()}
    function onBusyChanged() {if(root.power && !root.power.busy) Qt.callLater(root.focusProfile)}
    function onProfilesChanged() {if(!root.power || !root.power.profiles.length) profileMenu.close()}
  }
}
