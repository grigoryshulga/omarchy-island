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
      check(row.visible && row.height<=Commons.Style.space(50),"battery overview is not a compact block")
      check(findChild(row,"batteryPercentage").text.indexOf("78")>=0,"battery percentage is incorrect")
      var gauge=findChild(row,"batteryGauge")
      check(gauge && findChild(gauge,"batteryBrailleProgress"),"braille gauge is missing")
      check(Math.abs(findChild(gauge,"batteryBrailleProgress").amount-0.78)<0.001,"gauge lost charge precision")
      fakePower.fraction=0.20;wait(20)
      check(gauge.accent.toString()===Island.Design.accent.toString(),"20 percent should keep the theme accent")
      fakePower.fraction=0.199;wait(20)
      check(gauge.accent.toString()===Island.Design.danger.toString(),"charge below 20 percent lost the danger role")
      fakePower.onBattery=false;wait(20)
      check(gauge.accent.toString()===gauge.lowChargeColor.toString(),"low charge lost its warning on AC")
      fakePower.onBattery=true
      fakePower.fraction=0;wait(20)
      check(findChild(gauge,"batteryBrailleProgress").amount===0,"empty battery shows charge")
      fakePower.fraction=1;wait(20)
      check(findChild(gauge,"batteryBrailleProgress").amount===1,"full battery has an empty last segment")
      fakePower.fraction=0.78
      fakePower.onBattery=false
      fakePower.device={isPresent:true,percentage:0.78,state:UPowerDeviceState.Charging,changeRate:10,timeToFull:3600}
      wait(30)
      check(gauge.charging,"charging state was not reflected in gauge")
      var reducedMotion=Commons.Style.reduceMotion
      Commons.Style.reduceMotion=true;wait(20)
      check(!gauge.animating && gauge.pulse===1,"reduced motion retained charging animation")
      Commons.Style.reduceMotion=reducedMotion
      row.active=false;wait(20)
      check(!gauge.animating && gauge.pulse===1,"hidden gauge retained charging animation")
      row.active=true
      fakePower.device={isPresent:true,percentage:0.78,state:UPowerDeviceState.PendingCharge}
      wait(20)
      check(!gauge.charging && !gauge.animating,"charge threshold animates as charging")
      fakePower.onBattery=true
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
      var firstScreen={},secondScreen={}
      backend.watch(firstScreen,true);backend.watch(secondScreen,true)
      check(backend.active && backend.consumers.length===2,"battery did not share two visible consumers")
      backend.watch(firstScreen,true)
      check(backend.consumers.length===2,"repeated visibility duplicated a consumer")
      backend.watch(firstScreen,false)
      check(backend.active,"closing one monitor stopped another monitor's battery")
      backend.allowed=false
      check(!backend.active && !backend.busy,"disabled battery retained external work")
      backend.allowed=true
      check(backend.active,"enabled battery did not restore its visible consumer")
      backend.watch(secondScreen,false)
      check(!backend.active && !backend.busy && backend.consumers.length===0,"last monitor did not release the battery")
      console.log("BATTERY_PASS");Qt.quit()
    }
  }
  Timer {interval:200;running:true;onTriggered:test.test_battery()}
}
