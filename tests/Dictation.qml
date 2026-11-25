import QtQuick
import QtTest
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  QtObject {
    id:fake
    property bool showing:false
    property bool recording:true
    property int sessionId:0
    property string screenName:""
    property int elapsed:65
    property var history:Array(48).fill(0)
  }
  QtObject {id:bar;property string position:"top";property int barSize:40}
  FloatingWindow {
    visible:true;implicitWidth:640;implicitHeight:60
    Item {id:anchor;anchors.centerIn:parent;width:360;height:30}
  }
  Loader {
    id:loader
    property bool retaining:false
    function release() {if(item && !item.open && item.shown===0) retaining=false}
    active:fake.showing || retaining
    onLoaded:retaining=true
    Component.onCompleted:setSource(Qt.resolvedUrl("Island/DictationOsd.qml"),{dictation:fake,anchorItem:anchor,bar:bar})
  }
  Connections {
    target:loader.item
    function onShownChanged() {Qt.callLater(loader.release)}
    function onOpenChanged() {Qt.callLater(loader.release)}
  }
  Island.DictationState {id:backend;active:false;runtimeDir:"/tmp/island-dictation-absent"}
  TestCase {
    id:test
    name:"Dictation"
    when:false
    function capture(item,name) {
      var saved=false
      verify(item.grabToImage(function(shot){
        saved=shot.saveToFile(Quickshell.env("ISLAND_DICTATION_CAPTURE")+"/"+name+".png")
      }))
      tryVerify(function(){return saved})
    }
    function checkIconCenter(icon,card) {
      verify(Math.abs(icon.paintedCenterX-icon.width/2)<0.5,"Dictation glyph is off center in its slot")
      verify(Math.abs(icon.y+icon.paintedCenterY-card.height/2)<=0.5,"Dictation glyph is off the card's center line")
    }
    function test_flow() {
      compare(loader.item,null)
      fake.showing=true
      tryCompare(loader,"status",Loader.Ready)
      var hud=loader.item
      var card=findChild(hud,"islandDictationOsd"),surface=findChild(hud,"islandDictationSurface")
      verify(card!==null)
      var field=findChild(hud,"islandDictationField")
      tryVerify(function(){return card.opacity>0 && card.opacity<1},500,"The OSD should animate in")
      verify(field.reveal>0 && field.reveal<1)
      verify(card.scale<1)
      var enteringBounds=Qt.rect(card.x,card.y,card.width,card.height)
      tryCompare(card,"opacity",1)
      compare(field.reveal,1)
      compare(Qt.rect(card.x,card.y,card.width,card.height),enteringBounds)
      compare(surface.WlrLayershell.keyboardFocus,WlrKeyboardFocus.None)
      compare(card.width,Commons.Style.space(256))
      verify(card.height<=Commons.Style.space(42))
      compare(card.y,bar.barSize+Commons.Style.gapsOut)
      compare(card.x,Math.round(hud.anchorPosition.x+anchor.width/2-card.width/2))
      anchor.anchors.horizontalCenterOffset=70
      wait(50)
      compare(card.x,Math.round(hud.anchorPosition.x+anchor.width/2-card.width/2))
      compare(backend.mode,"idle")
      var time=findChild(hud,"islandDictationTime")
      var icon=findChild(hud,"islandDictationIcon"), recordingIcon=icon.text
      var recordingStatus=icon.Accessible.name
      var iconSlot=Qt.rect(icon.x,icon.y,icon.width,icon.height)
      var fieldX=field.x, timeX=time.x
      checkIconCenter(icon,card)
      verify(recordingStatus.length>0)
      verify(icon.x+icon.width<=field.x && field.x+field.width<=time.x)
      verify(field.width>=card.width*0.6,"The ribbon should occupy the space between the icon and timer")
      tryCompare(time,"text","1:05")
      var fieldWidth=field.width
      compare(field.software,!Quickshell.env("ISLAND_TEST_GPU"))
      compare(field.moving,true)
      compare(field.flowing,false)
      capture(field,"quiet")
      wait(120)
      capture(field,"quiet-next")
      fake.history=Array(42).fill(0).concat([0.35,0.72,0.9,0.92,0.78,0.56])
      tryVerify(function(){return field.energy>0.8},300,"Voice should increase the wave's height")
      compare(field.flowing,true)
      capture(field,"recording-first")
      wait(160)
      capture(field,"recording-next")
      fake.history=Array(48).fill(0)
      tryCompare(field,"energy",0)
      compare(field.flowing,false)
      capture(field,"settled")
      fake.recording=false
      tryCompare(field,"processing",true)
      tryCompare(field,"morph",1)
      verify(icon.text!==recordingIcon)
      verify(icon.Accessible.name.length>0 && icon.Accessible.name!==recordingStatus)
      compare(Qt.rect(icon.x,icon.y,icon.width,icon.height),iconSlot)
      checkIconCenter(icon,card)
      compare(field.x,fieldX)
      compare(time.x,timeX)
      compare(field.width,fieldWidth)
      capture(field,"processing")
      wait(240)
      capture(field,"processing-next")
      var leavingBounds=Qt.rect(card.x,card.y,card.width,card.height)
      var processingIcon=icon.text
      fake.elapsed=0
      fake.showing=false
      tryVerify(function(){return card.opacity>0 && card.opacity<1},500,"The OSD should animate out")
      verify(field.reveal>0 && field.reveal<1)
      compare(Qt.rect(card.x,card.y,card.width,card.height),leavingBounds)
      compare(icon.text,processingIcon)
      compare(time.text,"1:05")
      tryCompare(loader,"item",null)
      fake.recording=true
      fake.elapsed=65
      fake.showing=true
      tryCompare(loader,"status",Loader.Ready)
      hud=loader.item
      card=findChild(hud,"islandDictationOsd")
      surface=findChild(hud,"islandDictationSurface")
      tryCompare(hud,"shown",1)
      mouseClick(card,card.width/2,card.height/2,Qt.RightButton)
      compare(findChild(hud,"islandDictationField").active,false)
      compare(findChild(hud,"islandDictationField").moving,false)
      tryCompare(surface,"visible",false)
      verify(fake.showing && fake.recording,"Hiding the popup interrupted the dictation")
      fake.recording=false
      wait(250)
      verify(!surface.visible,"Transcribing reopened the dismissed popup")
      field=findChild(hud,"islandDictationField")
      Commons.Style.reduceMotion=true
      fake.recording=true
      fake.sessionId++
      tryCompare(surface,"visible",true)
      tryCompare(card,"opacity",1)
      tryCompare(field,"morph",0)
      compare(field.phase,0)
      capture(field,"reduced-first")
      fake.history=Array(48).fill(0.95)
      wait(170)
      capture(field,"reduced-next")
      fake.recording=false
      tryCompare(field,"processing",true)
      compare(field.morph,1)
      capture(field,"reduced-processing")
      wait(170)
      capture(field,"reduced-processing-next")
      fake.showing=false
      compare(hud.shown,0)
      tryCompare(loader,"item",null)
      console.log("DICTATION_PASS")
      Qt.quit()
    }
  }
  Timer {interval:100;running:true;onTriggered:{try {test.test_flow()} catch(error) {console.log("DICTATION_FAIL",error,error.stack);Qt.quit()}}}
  Timer {interval:7000;running:true;onTriggered:{console.log("DICTATION_FAIL timeout");Qt.quit()}}
}
