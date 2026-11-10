import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "PowerModel.js" as Model

Item {
  id:root
  property bool active:false
  property var device:UPower.displayDevice
  property bool onBattery:UPower.onBattery
  readonly property bool present:!!device && device.isPresent
  readonly property real fraction:Model.batteryFraction(device)
  readonly property string icon:Model.batteryIcon(device,onBattery,states)
  readonly property var states:({Charging:UPowerDeviceState.Charging,Discharging:UPowerDeviceState.Discharging,FullyCharged:UPowerDeviceState.FullyCharged,PendingCharge:UPowerDeviceState.PendingCharge})
  readonly property real secondsRemaining:device && device.state!==UPowerDeviceState.FullyCharged && !Model.chargeThresholdActive(device,onBattery,states) ? Number(onBattery ? device.timeToEmpty : device.timeToFull) || 0 : 0
  property var profiles:[]
  property string activeProfile:""
  property string error:""
  property bool refreshPending:false
  readonly property bool busy:profileAction.running || profileRead.running
  property var listCommand:["omarchy-powerprofiles-list","--active-state"]
  property var setCommand:["omarchy-powerprofiles-set"]
  signal profileApplied(bool success)
  function refresh() {
    if(!active || !present || profileAction.running) return
    if(profileRead.running) {refreshPending=true;return}
    refreshPending=false;profileRead.running=true
  }
  function updateProfiles(raw) {
    var parsed=Model.parseProfiles(String(raw).slice(0,4096),0)
    var available=parsed.profiles.filter(function(name){return ["performance","balanced","power-saver"].indexOf(name)>=0})
    profiles=available.filter(function(name,index){return available.indexOf(name)===index})
    activeProfile=profiles.indexOf(parsed.activeProfile)>=0 ? parsed.activeProfile : ""
  }
  function setProfile(profile) {
    if(!active || !present || busy || profiles.indexOf(profile)<0) return
    error=""
    profileAction.command=setCommand.concat([onBattery ? "battery" : "ac",profile])
    profileAction.running=true
  }
  onActiveChanged:refresh()
  onPresentChanged:refresh()
  onOnBatteryChanged:Qt.callLater(refresh)
  Connections {target:PowerProfiles;function onProfileChanged(){root.refresh()}}
  Timer {interval:15000;repeat:true;running:root.active && root.present;onTriggered:root.refresh()}
  Process {
    id:profileRead
    command:root.listCommand
    stdout:StdioCollector {waitForEnd:true;onStreamFinished:root.updateProfiles(text)}
    onExited:code=>{
      if(code!==0) {root.profiles=[];root.activeProfile=""}
      if(root.refreshPending) Qt.callLater(root.refresh)
    }
  }
  Process {
    id:profileAction
    onExited:code=>{
      root.error=code===0 ? "" : "profile"
      root.profileApplied(code===0)
      Qt.callLater(root.refresh)
    }
  }
  Timer {
    interval:8000;running:profileRead.running || profileAction.running
    onTriggered:{
      if(profileRead.running) {profileRead.running=false;root.profiles=[]}
      if(profileAction.running) {profileAction.running=false;root.error="profile";root.profileApplied(false)}
    }
  }
}
