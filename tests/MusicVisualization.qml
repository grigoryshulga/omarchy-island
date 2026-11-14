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
    property real visualPhase: 1
    property real audioLevel: 0.5
    property real audioBass: 0.4
    property real audioTreble: 0.3
    property var player: ({trackArtUrl: ""})
    property var visualImpulses: ({times:[0.2,-10,-10,-10],strengths:[0.8,0,0,0]})
  }
  FloatingWindow {
    visible: true
    implicitWidth: 320; implicitHeight: 200
    Island.ArtworkBackground { id: popup; anchors.fill:parent; service:service }
    Island.ArtworkBackground { id: bar; width:240; height:26; service:service; monochrome:true; horizontalFade:true }
  }
  TestCase {
    id: test
    when: false
    function check(ok, message) { if(!ok) throw new Error(message) }
    function shader(item) {
      for(var child of item.children) if("fragmentShader" in child) return child
      throw new Error("Missing artwork shader")
    }
    function run() {
      try {
        Commons.Style.reduceMotion=false
        wait(220)
        var effect=shader(popup),barEffect=shader(bar)
        var styles=["default","ripple","flow","embers","constellations","echo"]
        var backgrounds=["artwork","aurora","tide","plasma"]
        for(var i=0;i<styles.length;i++) for(var j=0;j<backgrounds.length;j++) {
          Island.Preferences.values=({musicVisualizationStyle:styles[i],musicVisualizationBackground:backgrounds[j]})
          check(popup.visualizationStyle===i && bar.visualizationStyle===i,"style did not reach both views")
          check(effect.style===i && barEffect.style===i,"shader style was not updated")
          check(effect.backgroundStyle===j && barEffect.backgroundStyle===j,"background did not reach both shaders")
          check(barEffect.monochrome===(j===0 ? 1 : 0),"system gradients lost their colors in the bar")
          Commons.Style.reduceMotion=true
          check(!popup.sampling && !bar.sampling,"reduced motion kept audio consumers")
          check(effect.phase===0 && effect.level===0 && effect.bass===0 && effect.treble===0,"reduced motion retained changing shader inputs")
          check(effect.impulseStrengths.x===0,"reduced motion retained attack history")
          Commons.Style.reduceMotion=false
        }
        check(Math.abs(effect.impulseTimes.x-0.2)<0.00001 && Math.abs(effect.impulseStrengths.x-0.8)<0.00001,"shared attack history did not reach shader")
        Island.Preferences.values=({musicVisualization:"open"})
        wait(220)
        check(popup.sampling && !bar.sampling,"popup-only mode sampled the bar")
        popup.visible=false
        check(Island.Preferences.visualizers.length===0,"hidden visualizations retained audio consumers")
        popup.visible=true
        Island.Preferences.values=({animationsEnabled:false})
        check(Island.Preferences.visualizers.length===0 && effect.phase===0,"animation switch retained continuous effects")
        Island.Preferences.values=({musicVisualization:"off"})
        wait(220)
        check(!popup.active && !bar.active && Island.Preferences.visualizers.length===0,"off mode retained visualization work")
        console.log("MUSIC_VISUALIZATION_PASS")
      } catch(error) { console.log("MUSIC_VISUALIZATION_FAIL",String(error)) }
      Qt.quit()
    }
  }
  Timer { interval:100; running:true; onTriggered:test.run() }
}
