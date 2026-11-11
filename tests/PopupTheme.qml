import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  Item {id:anchor;width:20;height:20}
  Island.IslandPopup {
    id:popup
    anchorItem:anchor
    bar:QtObject {property int barSize:26;property string position:"top"}
  }
  TestCase {
    id:test;when:false
    function checkTheme() {
      var card=findChild(popup,"islandPopupCard")
      for(var alpha of [0.63,1]) {
        Commons.Color.popups.background=Qt.rgba(0.1,0.15,0.2,alpha)
        for(var standalone of [false,true]) {
          popup.bareCardShown=standalone
          compare(card.color,Commons.Color.popups.background)
          verify(Math.abs(card.color.a-alpha)<0.01,"Popup discarded theme alpha")
          compare(popup.borderSpec,Island.Design.popupBorder)
          if(standalone) compare(popup.padding,0,"Border restored an outer container")
        }
      }
      console.log("POPUP_THEME_PASS")
    }
  }
  Timer {interval:400;running:true;onTriggered:{try {test.checkTheme()} catch(error) {console.log("POPUP_THEME_FAIL",error.stack)} Qt.quit()}}
}
