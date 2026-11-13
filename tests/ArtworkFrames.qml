import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  QtObject {
    id: service
    property bool hasMedia: true
    property bool playing: true
    property real visualPhase: 0
    property real audioLevel: 0
    property real audioBass: 0
    property real audioTreble: 0
    property var player: null
  }
  FloatingWindow {
    visible: true
    color: "black"
    implicitWidth: 320; implicitHeight: 200
    Island.ArtworkBackground { id: artwork; anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;height:160; service: service }
    Island.BrailleGauge {id:gauge;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:24;value:0.2}
    Island.BrailleProgress {id:progressProbe;width:300;height:12;accent:"white";value:0.25;visible:false}
    Island.BrailleClap {id:clap;anchors.centerIn:parent;width:220;height:150;visible:false;active:false}
    Item {
      id:spotScene
      anchors.fill:parent
      visible:false
      Rectangle {id:spotCard;x:40;y:30;width:220;height:130;radius:18;color:"black";property bool islandSpotlightSurface:true
        Island.ActionButton {id:spotButton;x:100;y:25;width:70;height:40;visible:false}
      }
      Rectangle {id:neighborCard;x:270;y:30;width:45;height:130;radius:12;color:"black";visible:false;property bool islandSpotlightSurface:true}
      Island.BrailleSpotlight {id:spot;anchors.fill:parent;surfaceRoot:spotScene;active:spotScene.visible;pointer:Qt.point(90,80);accent:"white"}
    }
    Item {
      id:dissolveProbe
      visible:false
      width:320;height:30;y:125
      property real dissolveAmount:0
      property bool effectEnabled:true
      layer.enabled:true
      layer.effect:effectEnabled ? dissolveComponent : null
      Component {id:dissolveComponent;Island.BrailleDissolve {amount:dissolveProbe.dissolveAmount}}
      Island.PlainText {anchors.centerIn:parent;text:"Tuesday 19:47";font.pixelSize:16;color:"white"}
    }
  }
  TestCase {
    id: test
    when: false
    function check(ok,message) {
      if(!ok) {console.log("ARTWORK_FRAMES_FAIL:",message);Qt.quit();throw new Error(message)}
    }
    function test_frames() {
      Commons.Style.reduceMotion=false
      wait(120)
      var first=grabImage(artwork)
      check(first.width>0 && first.height>0,"no GPU frame")
      service.visualPhase=0.75
      wait(120)
      var second=grabImage(artwork)
      var ambientChanged=!first.equals(second)
      service.audioLevel=0.4;service.visualPhase=0
      wait(100)
      var reactive=grabImage(artwork)
      service.visualPhase=0.75
      wait(100)
      check(!reactive.equals(grabImage(artwork)),"shared phase or GPU layer does not update")
      check(ambientChanged,"artwork is frozen when audio levels are zero")
      Commons.Style.reduceMotion=true
      wait(80)
      var still=grabImage(artwork)
      service.visualPhase=1.5
      wait(80)
      check(still.equals(grabImage(artwork)),"artwork ignores reduced motion")
      Commons.Style.reduceMotion=false
      var fullCover=grabImage(artwork)
      artwork.reveal=0.5;wait(320)
      var partialCover=grabImage(artwork),surviving=0,removed=0
      for(var y=0;y<fullCover.height;y++) for(var x=0;x<fullCover.width;x++) {
        var full=fullCover.red(x,y)+fullCover.green(x,y)+fullCover.blue(x,y)
        var partial=partialCover.red(x,y)+partialCover.green(x,y)+partialCover.blue(x,y)
        if(full>15) {if(partial>full*0.9) surviving++;if(partial<full*0.05) removed++}
      }
      check(surviving>10 && removed>10,"album art faded uniformly instead of dissolving dot by dot")
      artwork.reveal=0;wait(320)
      var absent=grabImage(artwork),remaining=0
      for(var y=0;y<absent.height;y++) for(var x=0;x<absent.width;x++) remaining+=absent.red(x,y)+absent.green(x,y)+absent.blue(x,y)
      check(remaining===0,"album art dissolve left visible dots")
      artwork.reveal=1;wait(320)
      check(fullCover.equals(grabImage(artwork)),"album art did not reassemble the same field")
      console.log("ARTWORK_DITHER_PASS")
      var field=findChild(gauge,"brailleGaugeField")
      var thin=grabImage(gauge)
      gauge.value=0.9;wait(80)
      var thick=grabImage(gauge),a=0,b=0
      // Both values fill this region: increased ink here proves that dots
      // become thicker, rather than merely lighting more columns.
      for(var y=Math.ceil(field.y);y<field.y+field.height;y++) for(var x=Math.ceil(field.x);x<field.x+field.width*0.15;x++) {a+=thin.red(x,y)+thin.green(x,y)+thin.blue(x,y);b+=thick.red(x,y)+thick.green(x,y)+thick.blue(x,y)}
      check(b>a*1.2,"gauge dots did not become thicker: "+a+" -> "+b+", amount="+field.amount)
      artwork.visible=false;gauge.visible=false;dissolveProbe.visible=true;wait(60)
      var crisp=grabImage(dissolveProbe)
      dissolveProbe.dissolveAmount=1;wait(60)
      check(!crisp.equals(grabImage(dissolveProbe)),"OSD dissolve did not pixelate the live text")
      dissolveProbe.dissolveAmount=0;wait(60)
      check(crisp.equals(grabImage(dissolveProbe)),"OSD dissolve did not restore the original text")
      dissolveProbe.effectEnabled=false;wait(60)
      check(crisp.equals(grabImage(dissolveProbe)),"releasing the dissolve shader changed the settled text")
      console.log("DISSOLVE_FRAMES_PASS")
      console.log("GAUGE_FRAMES_PASS")
      dissolveProbe.visible=false;clap.visible=true
      Commons.Style.reduceMotion=false
      clap.phase=0;wait(60)
      var openHands=grabImage(clap)
      clap.phase=0.25;wait(60)
      check(!openHands.equals(grabImage(clap)),"clapping hands did not move")
      Commons.Style.reduceMotion=true;wait(60)
      var stillHands=grabImage(clap)
      clap.phase=0.6;wait(60)
      check(stillHands.equals(grabImage(clap)),"clapping hands ignore reduced motion")
      Commons.Style.reduceMotion=false
      clap.active=true;wait(120)
      check(clap.phase!==0.6,"clapping animation did not start")
      clap.active=false;wait(60)
      var pausedPhase=clap.phase;wait(100)
      check(clap.phase===pausedPhase,"hidden overview kept clapping")
      console.log("CLAP_FRAMES_PASS")
      clap.visible=false;spotScene.visible=true
      Commons.Style.reduceMotion=true;wait(80)
      check(spot.hoveredSurface===spotCard,"cursor did not pick the card")
      spot.pointer=Qt.point(44,80);wait(80)
      var edgeFrame=grabImage(spotScene),inside=0
      for(var y=0;y<edgeFrame.height;y++) for(var x=0;x<edgeFrame.width;x++) {
        var ink=edgeFrame.red(x,y)+edgeFrame.green(x,y)+edgeFrame.blue(x,y)
        if(x<40 || x>=260 || y<30 || y>=160) check(ink===0,"spotlight leaked outside the card")
        else inside+=ink
      }
      check(inside>100,"scoped GPU spotlight is empty")
      check(edgeFrame.red(40,30)===0,"spotlight leaked through a rounded corner")
      spotButton.visible=true
      spot.pointer=Qt.point(170,80);wait(60)
      check(spot.hoveredSurface===spotButton,"nested qs.Ui button did not override the card")
      check(spot.focusRect.x===140 && spot.focusRect.y===55 && spot.focusRect.z===70,"nested button bounds were mapped incorrectly")
      var buttonFrame=grabImage(spot),peak=0
      for(var y=0;y<buttonFrame.height;y++) for(var x=0;x<buttonFrame.width;x++) {
        var light=buttonFrame.red(x,y)
        if(x<140 || x>=210 || y<55 || y>=95) check(light===0,"intense spotlight leaked outside the button")
        if(Math.abs(x-170)<10 && Math.abs(y-80)<10) peak=Math.max(peak,light)
      }
      check(peak>180,"focused button spotlight is too faint: "+peak)
      spotButton.visible=false
      spot.pointer=Qt.point(44,80)
      spotCard.radius=0;wait(60)
      check(spot.focusRadius===0,"square corners were not respected")
      Commons.Style.reduceMotion=false
      spot.pointer=Qt.point(180,80);wait(80)
      check(spot.trailSamples.length>0,"trail did not retain pointer positions")
      wait(240)
      var wakeFrame=grabImage(spot),wakeLight=0
      // This patch is behind the pointer and outside the main spotlight.
      for(var y=65;y<95;y++) for(var x=45;x<95;x++) wakeLight+=wakeFrame.red(x,y)
      check(wakeLight>1200,"cursor left no visible fading trail: "+wakeLight)
      wait(550)
      var fadedWake=grabImage(spot),fadedLight=0
      for(var y=65;y<95;y++) for(var x=45;x<95;x++) fadedLight+=fadedWake.red(x,y)
      check(fadedLight<wakeLight*0.15,"cursor trail did not fade away")
      check(!findChild(spot,"spotlightTrailClock").running,"settled cursor kept the path timer running")
      // The real pointer path triggers a two-sided split at the right rim.
      spot.pointer=Qt.point(254,80);wait(200)
      check(spot.edgeProgress<0.8,"approaching the rim did not scatter pixels")
      var burstFrame=grabImage(spot)
      spot.clearEdge();wait(20)
      var plainEdge=grabImage(spot),upperScatter=0,lowerScatter=0
      for(var y=40;y<125;y++) for(var x=250;x<260;x++) {
        var added=burstFrame.red(x,y)-plainEdge.red(x,y)
        if(added>60) {if(y<80) upperScatter++;else lowerScatter++}
      }
      check(upperScatter>2 && lowerScatter>2,"edge pixels did not split in both directions")
      for(var y=0;y<burstFrame.height;y++) for(var x=260;x<burstFrame.width;x++)
        check(burstFrame.red(x,y)===0,"scattered pixels escaped the card")
      spot.pointer=Qt.point(180,80);wait(65)
      spot.pointer=Qt.point(254,80);wait(70)
      check(spot.edgeProgress<1,"second collision did not restart the burst")
      Commons.Style.reduceMotion=true
      check(spot.edgeProgress===1 && spot.edgeEnabled===0,"reduced motion kept the edge scatter")
      spot.pointer=Qt.point(100,80);wait(30)
      check(spot.trailSamples.length===0,"reduced motion kept the trail")
      var staticSpot=grabImage(spotScene);wait(100)
      check(staticSpot.equals(grabImage(spotScene)),"reduced-motion spotlight kept moving")
      neighborCard.visible=true
      spot.pointer=Qt.point(254,80);wait(60)
      check(spot.nearbySurfaces.length===1,"adjacent card was not selected for rim glow")
      var neighborFrame=grabImage(spot),nearLight=0,farLight=0
      for(var y=65;y<95;y++) {
        for(var x=271;x<278;x++) nearLight+=neighborFrame.red(x,y)
        for(var x=305;x<312;x++) farLight+=neighborFrame.red(x,y)
        for(var x=260;x<270;x++) check(neighborFrame.red(x,y)===0,"neighbor glow filled the gap")
      }
      check(nearLight>800 && nearLight>farLight*3,"adjacent facing rim did not catch the cursor light")
      check(neighborFrame.red(270,30)===0,"neighbor glow leaked through rounded corners")
      wait(60)
      check(neighborFrame.equals(grabImage(spot)),"neighbor glow moved under reduced motion")
      neighborCard.radius=0;wait(30)
      check(spot.neighborRadii.x===0,"neighbor ignored square theme corners")
      neighborCard.visible=false;wait(30)
      check(spot.nearbySurfaces.length===0,"hidden neighbor retained glow")
      spotScene.visible=false;wait(30)
      var stoppedPhase=spot.phase;wait(60)
      check(spot.phase===stoppedPhase,"hidden spotlight kept animating")
      console.log("SPOTLIGHT_FRAMES_PASS")
      progressProbe.visible=true;wait(60)
      var quarter=grabImage(progressProbe),leftInk=0,rightInk=0
      for(var y=0;y<quarter.height;y++) {
        for(var x=0;x<60;x++) leftInk+=quarter.red(x,y)
        for(var x=240;x<300;x++) rightInk+=quarter.red(x,y)
      }
      check(leftInk>rightInk*3 && rightInk>0,"shared progress lost filled/empty dots")
      progressProbe.value=0.75;wait(40)
      check(!quarter.equals(grabImage(progressProbe)),"shared progress did not update")
      progressProbe.value=0.25;progressProbe.mirrored=true;wait(40)
      var mirrored=grabImage(progressProbe),mirroredLeft=0,mirroredRight=0
      for(var y=0;y<mirrored.height;y++) {
        for(var x=0;x<60;x++) mirroredLeft+=mirrored.red(x,y)
        for(var x=240;x<300;x++) mirroredRight+=mirrored.red(x,y)
      }
      check(mirroredRight>mirroredLeft*3,"shared progress did not mirror")
      wait(60);check(mirrored.equals(grabImage(progressProbe)),"static progress kept animating")
      console.log("BRAILLE_PROGRESS_FRAMES_PASS")
      console.log("ARTWORK_FRAMES_PASS")
      Qt.quit()
    }
  }
  Timer {interval:400;running:true;onTriggered:test.test_frames()}
}
