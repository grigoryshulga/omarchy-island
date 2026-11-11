import QtQuick
import Quickshell
import qs.Commons as Commons

ShellRoot {
  FloatingWindow {
    id:window
    title: "Island · Design system"
    implicitWidth: 1100
    implicitHeight: Quickshell.env("ISLAND_DESIGN_CAPTURE") ? 1440 : 960
    color: "transparent"
    Gallery {id:gallery;anchors.fill:parent}
    property int captureIndex: 0
    Timer {
      id:capture
      interval:400
      running:Quickshell.env("ISLAND_DESIGN_CAPTURE")!==""
      onTriggered: {
        var themes=["dark","light","mono"]
        if(window.captureIndex>=themes.length) {console.log("DESIGN_CAPTURE_PASS");Qt.quit();return}
        gallery.setTheme(themes[window.captureIndex]);Commons.Style.cornerRadius=window.captureIndex===2 ? 0 : 12
        Commons.Style.fontBaseSize=12
        settle.start()
      }
    }
    Timer {
      id:settle;interval:350
      onTriggered:gallery.grabToImage(function(result) {
        result.saveToFile(Quickshell.env("ISLAND_DESIGN_CAPTURE")+"/"+gallery.previewTheme+".png")
        window.captureIndex++;capture.restart()
      })
    }
  }
}
