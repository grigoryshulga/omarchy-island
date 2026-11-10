import QtQuick
import QtTest
import Quickshell
import Quickshell.Services.UPower
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  id:scene
  property var selected:[]
  QtObject {
    id:fakePower
    property bool present:true
    property real fraction:0.78
    property string icon:"󰂀"
    property bool onBattery:true
    property var device:({isPresent:true,percentage:0.78,state:UPowerDeviceState.Discharging,timeToEmpty:7200,timeToFull:0})
    property var states:({Charging:UPowerDeviceState.Charging,Discharging:UPowerDeviceState.Discharging,FullyCharged:UPowerDeviceState.FullyCharged,PendingCharge:UPowerDeviceState.PendingCharge})
    property real secondsRemaining:7200
    property var profiles:["performance","balanced","power-saver"]
    property string activeProfile:"balanced"
    property bool busy:false
    property string error:""
    signal profileApplied(bool success)
    function refresh(){}
    function setProfile(profile){scene.selected=scene.selected.concat([profile]);activeProfile=profile;profileApplied(true)}
  }
  Island.PowerState {
    id:backend
    active:true
    device:({isPresent:true,percentage:0.5})
    onBattery:true
    listCommand:["python3",Quickshell.env("ISLAND_POWER_HELPER"),"list"]
    setCommand:["python3",Quickshell.env("ISLAND_POWER_HELPER"),"set"]
  }
  FloatingWindow {
    visible:true;implicitWidth:480;implicitHeight:300
    Rectangle {
      anchors.fill:parent;color:Commons.Color.popups.background
      Island.BatteryOverview {id:row;anchors.top:parent.top;anchors.topMargin:20;anchors.left:parent.left;anchors.right:parent.right;anchors.margins:16;height:implicitHeight;strings:translations;active:true;power:fakePower}
    }
  }
  Commons.Translations {id:translations;directory:Qt.resolvedUrl("Island/i18n")}
  TestCase {
    id:test;when:false
    function check(ok,message){if(!ok){console.log("BATTERY_FAIL:",message);Qt.quit();throw new Error(message)}}
    function test_battery(){
      wait(120)
      check(row.visible && row.height<=Commons.Style.space(32),"battery overview is not a compact row")
      check(findChild(row,"batteryPercentage").text.indexOf("78")>=0,"battery percentage is incorrect")
      var menu=findChild(row,"batteryProfileMenu"),height=row.height
      findChild(row,"batteryProfileButton").clicked();wait(190)
      check(menu.opened,"profile menu did not open")
      mouseMove(menu.contentItem,10,10);wait(120)
      check(row.height===height && menu.height<Commons.Style.space(180),"profile menu resized the battery row or has a layout loop")
      findChild(menu.contentItem,"batteryProfile-performance").clicked();wait(120)
      check(!menu.opened && scene.selected[0]==="performance","profile selection did not apply/close menu")
      row.toggleMenu();wait(170);row.active=false;wait(100)
      check(!menu.opened,"hidden Overview retained its menu")
      fakePower.present=false;wait(20)
      check(!row.visible && row.implicitHeight===0,"desktop without a battery has a phantom block")
      tryVerify(function(){return !backend.busy && backend.profiles.length===3},2500)
      check(backend.activeProfile==="balanced","native profile list was not parsed")
      backend.setProfile("bad-profile");check(!backend.busy,"unsupported profile was accepted")
      backend.setProfile("performance")
      tryVerify(function(){return !backend.busy && backend.activeProfile==="performance"},2500)
      backend.onBattery=false;backend.setProfile("power-saver")
      tryVerify(function(){return !backend.busy && backend.error!==""},2500)
      check(backend.activeProfile==="performance","failed profile change overwrote current profile")
      backend.active=false
      console.log("BATTERY_PASS");Qt.quit()
    }
  }
  Timer {interval:200;running:true;onTriggered:test.test_battery()}
}
