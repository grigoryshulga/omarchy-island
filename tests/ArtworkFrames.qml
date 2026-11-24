import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/modules/timers" as Timers

ShellRoot {
  QtObject {
    id: service
    property bool hasMedia: true
    property bool playing: true
    property real visualPhase: 0
    property real audioLevel: 0
    property real audioBass: 0
    property real audioTreble: 0
    property var visualImpulses: ({times:[0.05,-10,-10,-10],strengths:[0.8,0,0,0]})
    property var player: null
  }
  FloatingWindow {
    visible: true
    color: "black"
    implicitWidth: 320; implicitHeight: 200
    Timers.BrailleTimeField {
      id: timeField
      width: 300; height: implicitHeight; z: 1; visible: false
      mode: "timer"; live: visible; onBreak: false; seconds: 0; fraction: 0
    }
    Island.ArtworkBackground { id: artwork; anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;height:160; service: service }
    Island.BrailleGauge {id:gauge;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;height:24;value:0.2}
    Island.BrailleProgress {id:progressProbe;width:300;height:12;accent:"white";value:0.25;visible:false}
    Island.BrailleClap {id:clap;anchors.centerIn:parent;width:220;height:150;visible:false;active:false}
    Item {
      id:spotScene
      anchors.fill:parent
      visible:false
      property int clicks: 0
      Rectangle {id:spotCard;x:40;y:30;width:220;height:130;radius:18;color:"black";property bool islandSpotlightSurface:true
        Island.ActionButton {
          id:spotButton
          x:100;y:25;width:70;height:40;visible:false
          color:"transparent";focusOnClick:false
          onClicked:spotScene.clicks++
        }
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
    function captureSpotlight(image,name) {
      const folder=Quickshell.env("ISLAND_SPOTLIGHT_CAPTURES")
      if(folder) image.save(folder+"/"+name+".png")
    }
    function test_spotlight() {
      spotScene.visible=true
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
      spot.bloomStrength=0
      wait(40)
      var bareDots=grabImage(spotScene)
      spot.bloomStrength=0.16
      wait(40)
      var glowingDots=grabImage(spotScene),bloomPixels=0
      for(var y=0;y<glowingDots.height;y++) for(var x=0;x<glowingDots.width;x++) {
        var glow=glowingDots.red(x,y)-bareDots.red(x,y)
        if(glow>0) {
          check(x>=140 && x<210 && y>=55 && y<95 && glow<=50,"dot bloom escaped the button or washed out its dots")
          bloomPixels++
        }
      }
      check(bloomPixels>10,"dot bloom is missing from the rendered spotlight")
      captureSpotlight(bareDots,"before-bloom")
      captureSpotlight(glowingDots,"hover-bloom")
      Commons.Style.reduceMotion=false
      spot.pointer=Qt.point(129,75);wait(70)
      spot.pointer=Qt.point(160,75);wait(55)
      check(spot.edgeProgress<1 && spot.edgeImpact.z===-1,"entering the button did not scatter at its leading rim")
      captureSpotlight(grabImage(spotScene),"boundary-entry")
      spot.pointer=Qt.point(175,75);wait(600)
      var restingSpot=grabImage(spot),restingCenter=0,restingRim=0,heldCenter=0,heldRim=0
      mousePress(spotButton,35,20,Qt.LeftButton)
      wait(210)
      check(spot.holdAmount>0.93,"left press did not reach the spotlight")
      var heldSpot=grabImage(spot)
      for(var y=59;y<91;y++) for(var x=145;x<205;x++) {
        var distance=Math.hypot(x-175,y-75)
        if(distance<8) {restingCenter+=restingSpot.red(x,y);heldCenter+=heldSpot.red(x,y)}
        if(distance>23) {restingRim+=restingSpot.red(x,y);heldRim+=heldSpot.red(x,y)}
      }
      captureSpotlight(restingSpot,"resting-spot")
      captureSpotlight(heldSpot,"held-spot")
      check(heldCenter>restingCenter && heldRim<restingRim*0.65,
        "holding the button did not concentrate the spotlight: center "+restingCenter+" → "+heldCenter+", rim "+restingRim+" → "+heldRim)
      check(spotScene.clicks===0,"holding activated the button before release")
      mouseRelease(spotButton,35,20,Qt.LeftButton)
      wait(150)
      check(spot.holdAmount===0,"spotlight did not settle after release")
      check(spotScene.clicks===1,"release did not deliver one button click: "+spotScene.clicks)
      mousePress(spotButton,35,20,Qt.RightButton);wait(160)
      check(spot.holdAmount===0,"right button entered the held state")
      mouseRelease(spotButton,35,20,Qt.RightButton)
      mousePress(spotButton,35,20,Qt.LeftButton)
      wait(110)
      check(spot.holdAmount>0.7,"second press did not re-enter the held state")
      mouseMove(spotButton,-20,20,30,Qt.LeftButton)
      wait(150)
      check(spot.holdAmount===0,"dragging did not release the held spotlight")
      mouseRelease(spotButton,-20,20,Qt.LeftButton)
      check(spotScene.clicks===1,"dragging out of the button produced a click")
      spot.active=false;wait(160)
      spot.pulse(Qt.point(170,77));wait(45)
      check(spot.scattering,"click feedback did not start")
      var clickFrame=grabImage(spot),clickLight=0
      for(var y=0;y<clickFrame.height;y++) for(var x=0;x<clickFrame.width;x++) {
        var light=clickFrame.red(x,y)
        if(x<140 || x>=210 || y<55 || y>=95) check(light===0,"click scatter escaped its original button")
        else clickLight+=light
      }
      check(clickLight>300,"the click scatter produced no visible ink")
      captureSpotlight(clickFrame,"click")
      spot.clearBurst()
      spot.pulse(Qt.point(113,94))
      wait(95)
      var scatteredSpot=grabImage(spot),quadrants=[0,0,0,0]
      for(var y=48;y<141;y++) for(var x=67;x<160;x++) {
        var dx=x-113,dy=y-94
        if(Math.abs(dx)>5 && Math.abs(dy)>5 && Math.hypot(dx,dy)>16 && scatteredSpot.red(x,y)>100)
          quadrants[(dx>0 ? 1 : 0)+(dy>0 ? 2 : 0)]++
      }
      check(quadrants.every(function(count){return count>=2}),"click particles did not spread in all directions: "+quadrants)
      captureSpotlight(scatteredSpot,"scattered-spot")
      Commons.Style.reduceMotion=true
      check(!spot.scattering,"reduced motion did not stop the current click scatter")
      spot.active=Qt.binding(function(){return spotScene.visible})
      mousePress(spotButton,35,20,Qt.LeftButton);wait(180)
      check(spot.holdAmount===0,"reduced motion allowed the held spotlight to animate")
      mouseRelease(spotButton,35,20,Qt.LeftButton)
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
      var styleFrames=[]
      for(var style of ["default","ripple","flow","embers","constellations","echo"]) {
        Island.Preferences.values=({musicVisualizationStyle:style})
        service.visualPhase=0.4;service.audioLevel=0.4;service.audioBass=0.5;service.audioTreble=0.3
        wait(60)
        var frame=grabImage(artwork)
        for(var previous of styleFrames) check(!frame.equals(previous),"styles render identically: "+style)
        styleFrames.push(frame)
        service.visualPhase=1.2;wait(60)
        check(!frame.equals(grabImage(artwork)),"style does not animate: "+style)
        Commons.Style.reduceMotion=true;wait(60)
        var reduced=grabImage(artwork)
        service.visualPhase=2.1;service.audioLevel=0.9;service.audioBass=0.9;service.audioTreble=0.9
        wait(60)
        check(reduced.equals(grabImage(artwork)),"style moves with reduced motion: "+style)
        Commons.Style.reduceMotion=false
      }
      Island.Preferences.values=({musicVisualizationStyle:"bayer"})
      wait(80)
      service.audioLevel=0;service.audioBass=0;wait(60)
      var printFrame=grabImage(artwork)
      var inkPixels=0, emptyPixels=0
      for(var y=0;y<printFrame.height;y++) for(var x=0;x<printFrame.width;x++) {
        if(printFrame.red(x,y)+printFrame.green(x,y)+printFrame.blue(x,y)>6) inkPixels++
        else emptyPixels++
      }
      check(inkPixels>100 && emptyPixels>100,"halftone has no readable pattern")
      service.visualPhase=5;wait(60)
      var quietPrint=grabImage(artwork)
      check(!printFrame.equals(quietPrint),"silent print has no drift")
      service.audioBass=0.9;wait(60)
      check(!quietPrint.equals(grabImage(artwork)),"print ignored the bass")
      Commons.Style.reduceMotion=true;wait(60)
      var stillPrint=grabImage(artwork)
      service.visualPhase=7;service.audioBass=0;wait(60)
      check(stillPrint.equals(grabImage(artwork)) && !artwork.sampling,"reduced-motion print kept moving or sampling")
      Commons.Style.reduceMotion=false
      service.player = {trackArtUrl: Qt.resolvedUrl("duotone.svg")}
      function warmth(frame,position) {
        var red=0,blue=0
        var left=Math.floor(frame.width*position)
        for (var y=4;y<20;y++) for (var x=left;x<left+20;x++) {
          red+=frame.red(x,y); blue+=frame.blue(x,y)
        }
        return (red-blue)/Math.max(1,red+blue)
      }
      for (var compact of [false,true]) {
        artwork.monochrome=compact; artwork.horizontalFade=compact
        artwork.height=compact ? 26 : 160
        wait(160)
        var coverFrame=grabImage(artwork)
        check(warmth(coverFrame,0.32)-warmth(coverFrame,0.64)>0.05,
              "print lost local cover colors in "+(compact ? "bar" : "popup"))
      }
      artwork.monochrome=false; artwork.horizontalFade=false; artwork.height=160
      service.player = {trackArtUrl: Qt.resolvedUrl("contrast.svg")}
      var previousPrint = printFrame
      for (var inkStyle of ["printTones","asciiInk","engraving"]) {
        Island.Preferences.values=({musicVisualizationStyle:inkStyle})
        wait(120)
        var inkFrame=grabImage(artwork)
        check(!inkFrame.equals(previousPrint),"missing printed style: "+inkStyle)
        service.visualPhase+=1;wait(60)
        check(inkFrame.equals(grabImage(artwork)),"printed style moved: "+inkStyle)
        previousPrint=inkFrame
      }
      service.player = null
      Island.Preferences.values=({musicVisualizationStyle:"echo"})
      service.audioLevel=0;service.audioBass=0;service.audioTreble=0
      service.visualPhase=0.6;wait(60)
      var echoTail=grabImage(artwork)
      service.visualImpulses=({times:[-10,-10,-10,-10],strengths:[0,0,0,0]});wait(60)
      var emptyEcho=grabImage(artwork)
      check(!echoTail.equals(emptyEcho),"echo loses its memory in silence")
      service.visualImpulses=({times:[0.05,-10,-10,-10],strengths:[0.8,0,0,0]})
      service.visualPhase=30;wait(60)
      check(emptyEcho.equals(grabImage(artwork)),"old echo does not fade away")
      artwork.visible=false;wait(40)
      check(Island.Preferences.visualizers.length===0,"hidden artwork keeps audio sampling registered")
      artwork.visible=true
      Island.Preferences.values=({})
      console.log("MUSIC_STYLES_FRAMES_PASS")
      Island.ThemePalette.values=({blue:"#327ad5",green:"#5ab97a",yellow:"#dcba60"})
      var backgroundFrames=[]
      for(var background of ["aurora","tide","plasma"]) {
        for(var style of ["default","ripple","flow","embers","constellations","echo"]) {
          Island.Preferences.values=({musicVisualizationStyle:style,musicVisualizationBackground:background})
          service.visualPhase=0.6;wait(50)
          var colored=grabImage(artwork)
          service.visualPhase=2.0;wait(50)
          check(!colored.equals(grabImage(artwork)),"gradient does not move: "+background+"/"+style)
          if(style==="default") {
            for(var previous of backgroundFrames) check(!colored.equals(previous),"gradient backgrounds render identically")
            backgroundFrames.push(colored)
          }
          Commons.Style.reduceMotion=true;wait(40)
          var staticGradient=grabImage(artwork)
          service.visualPhase=3.5;wait(40)
          check(staticGradient.equals(grabImage(artwork)),"gradient ignores reduced motion")
          Commons.Style.reduceMotion=false
        }
      }
      Island.Preferences.values=({musicVisualizationBackground:"plasma"})
      service.visualPhase=1;wait(50)
      var originalPalette=grabImage(artwork),oldAccent=Commons.Color.accent
      Commons.Color.accent="#d0ff20";wait(50)
      check(!originalPalette.equals(grabImage(artwork)),"gradient does not follow live system colors")
      Commons.Color.accent=oldAccent
      Island.Preferences.values=({})
      console.log("MUSIC_BACKGROUNDS_FRAMES_PASS")
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
      clap.visible=false
      test_spotlight()
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
      progressProbe.mirrored=false;progressProbe.value=0
      progressProbe.accent="#ff0000";progressProbe.trackColor="#808080";wait(40)
      var emptyTrack=grabImage(progressProbe),trackInk=0
      for(var y=0;y<emptyTrack.height;y++) for(var x=0;x<emptyTrack.width;x++) {
        trackInk+=emptyTrack.red(x,y)
        check(Math.abs(emptyTrack.red(x,y)-emptyTrack.green(x,y))<=1 && Math.abs(emptyTrack.green(x,y)-emptyTrack.blue(x,y))<=1,"empty track is tinted by progress color")
      }
      check(trackInk>0,"zero progress hides the full-length gray track")
      progressProbe.value=0.5;wait(40)
      var halfTrack=grabImage(progressProbe),redFill=0,grayFill=0
      for(var y=0;y<halfTrack.height;y++) for(var x=0;x<halfTrack.width;x++) {
        if(x<halfTrack.width*0.45) {redFill+=halfTrack.red(x,y);grayFill+=halfTrack.green(x,y)}
        if(x>halfTrack.width*0.55) check(halfTrack.red(x,y)===emptyTrack.red(x,y) && halfTrack.green(x,y)===emptyTrack.green(x,y),"progress changed the unfilled track")
      }
      check(redFill>grayFill*3,"colored fill does not stand out from the gray track")
      console.log("BRAILLE_PROGRESS_FRAMES_PASS")
      artwork.visible=false; progressProbe.visible=false
      timeField.width=301; timeField.visible=true
      timeField.fraction=1; wait(80)
      var grid=grabImage(timeField), xs=[], ys=[]
      for (var y=0; y<grid.height; y++) {
        for (var x=0; x<grid.width; x++) {
          if (grid.red(x,y)!==grid.red(0,0) || grid.green(x,y)!==grid.green(0,0) || grid.blue(x,y)!==grid.blue(0,0)) {
            xs[x]=true; ys[y]=true
          }
        }
      }
      function dotStarts(axis) {
        var starts=[]
        for (var i=0;i<axis.length;i++) if (axis[i] && !axis[i-1]) starts.push(i)
        return starts
      }
      var columns=dotStarts(xs), rows=dotStarts(ys)
      check(columns.length>4 && rows.length===8,"dot grid has missing rows or columns")
      var pitch=columns[1]-columns[0]
      for (var axis of [columns,rows])
        for (var i=1;i<axis.length;i++) check(axis[i]-axis[i-1]===pitch,"uneven dot spacing")

      for (var mode of ["timer","pomodoro","stopwatch"]) {
        timeField.mode=mode; timeField.seconds=1; timeField.fraction=0.25; wait(80)
        var early=grabImage(timeField)
        timeField.seconds=2; wait(80)
        var late=grabImage(timeField)
        check(!early.equals(late),mode+" dots did not move")
        wait(80)
        check(late.equals(grabImage(timeField)),mode+" dots moved with a frozen clock")
        if (mode==="timer") timeField.fraction=0.9
        if (mode==="pomodoro") timeField.onBreak=true
        wait(80)
        if (mode!=="stopwatch") check(!late.equals(grabImage(timeField)),mode+" dots ignored the countdown or break")
      }
      console.log("ARTWORK_FRAMES_PASS")
      Qt.quit()
    }
  }
  Timer {
    interval:400
    running:true
    onTriggered:{
      if(Quickshell.env("ISLAND_SPOTLIGHT_ONLY")==="1") {
        artwork.visible=false;gauge.visible=false
        test.test_spotlight()
        Qt.quit()
      } else test.test_frames()
    }
  }
}
