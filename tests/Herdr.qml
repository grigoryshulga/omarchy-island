import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/modules/herdr" as Herdr

ShellRoot {
  Island.HerdrState {id:state;allowed:false;snapshotCommand:["/bin/sleep","60"]}
  Commons.Translations {id:translations;directory:Qt.resolvedUrl("Island/i18n")}
  QtObject {
    id:context
    property var strings:translations
    property bool expanded:true
    property bool hovering:false
    property bool detail:false
    property bool vertical:false
    property bool showAlert:false
    property bool active:true
    property var bar:null
    property int barSize:32
    property int barHeight:32
    property var feedback:null
  }
  FloatingWindow {
    visible:true;implicitWidth:400;implicitHeight:700
    Column {
      width:parent.width
      Herdr.Overview {id:overview;width:parent.width;backend:state;presentation:context}
      Herdr.Indicator {backend:state;presentation:context}
      Herdr.Settings {width:parent.width;backend:state;presentation:context}
      Island.HerdrSessionCard {id:card;active:true;width:parent.width;strings:translations;row:({title:"Agent",source:"Remote",pane:"w1:p1",status:"blocked"})}
      Flickable {
        id:scroll;width:parent.width;height:80;contentHeight:400;clip:true
        Island.HerdrSessionCard {
          id:scrollCard;width:parent.width;y:200;active:true;strings:translations
          row:({title:"Background",source:"Remote",pane:"w1:p2",status:"working"})
        }
      }
    }
    TestCase {
      id:ui;name:"HerdrCards";when:false
      function checkRetainedCards() {
        var retained=findChild(overview,"herdrSession-a")
        verify(retained,"Missing compact card")
        context.detail=true;wait(20)
        compare(findChild(overview,"herdrSession-a"),retained,"Opening details recreated a card")
        context.detail=false;wait(20)
        var action=findChild(retained,"herdrDetails")
        action.forceActiveFocus()
        state.receive(JSON.stringify({sources:JSON.parse(JSON.stringify(state.sources))}))
        wait(20)
        compare(findChild(overview,"herdrSession-a"),retained,"Polling recreated a card")
        verify(action.activeFocus,"Polling lost keyboard focus")
      }
      function checkCards() {
        var title=findChild(card,"herdrSessionTitle"),slot=findChild(card,"herdrStatusSlot")
        var originalTitleX=title.mapToItem(card,0,0).x,originalHeight=card.implicitHeight
        for(var status of ["working","blocked","done","idle","unknown"]) {
          card.row={title:"Agent",source:"Remote",pane:"w1:p1",status:status}
          wait(20)
          compare(title.mapToItem(card,0,0).x,originalTitleX,"Status shifted the title")
          compare(card.implicitHeight,originalHeight,"Status changed card height")
          var icon=card.statusIcon
          verify(Math.abs(icon.mapToItem(card,icon.width/2,icon.height/2).y-title.mapToItem(card,0,title.height/2).y)<1,"Status lost title alignment")
          compare(findChild(card,"herdrStatusLabel").color.toString(),card.statusColor.toString())
        }
        card.width=220
        card.row={title:"A long session title that should be elided",source:"A long remote machine / session",pane:"w1:p1",status:"blocked"}
        wait(20)
        verify(title.truncated,"Narrow title did not elide")
        var source=findChild(card,"herdrSourceLabel"),label=findChild(card,"herdrStatusLabel")
        verify(source.mapToItem(card,source.width,0).x<=label.mapToItem(card,0,0).x,"Metadata overlaps the status")
        card.expanded=true;card.compactOverview=true;wait(20)
        var action=findChild(card,"herdrDetails")
        action.forceActiveFocus();keyClick(Qt.Key_Return);wait(20)
        compare(details.count,1,"Keyboard did not open session details")
        card.row={title:"Agent",source:"Remote",pane:"w1:p1",status:"working"}
        Island.Preferences.values={animationsEnabled:true};Commons.Style.reduceMotion=false
        wait(30)
        var spinner=findChild(card,"herdrSessionSpinner")
        verify(spinner.animating,"Visible work spinner is stopped")
        card.active=false;wait(20);verify(!spinner.animating,"Inactive spinner kept running")
        card.active=true;Commons.Style.reduceMotion=true;wait(20)
        verify(!spinner.animating && spinner.frame===0,"Reduced motion did not stop the spinner")
        Commons.Style.reduceMotion=false;wait(20)
        var scrollSpinner=findChild(scrollCard,"herdrSessionSpinner")
        verify(!scrollSpinner.animating,"Offscreen spinner kept running")
        scroll.contentY=180;wait(20)
        verify(scrollSpinner.animating,"Scrolling work into view did not start its spinner")
        Commons.Style.cornerRadius=0;wait(20)
        compare(card.radius,0,"Card did not respect square corners")
      }
    }
  }
  SignalSpy {id:details;target:card;signalName:"overviewDetailsRequested"}
  SignalSpy {id:activity;target:state;signalName:"activityChanged"}
  Timer {
    interval:200;running:true
    onTriggered: {
      try {
      ui.checkCards()
      state.allowed=true
      state.accepting=true
      state.receive(JSON.stringify({sources:[{id:"local/default",label:"default",status:"connected",rows:[{id:"a",title:"Agent",source:"default",pane:"w1:p1",status:"working"}]}]}))
      if(state.workingCount!==1) throw new Error("working count")
      if(state.waitingCount!==0) throw new Error("waiting count")
      if(!overview.available) throw new Error("available")
      if(activity.count!==0) throw new Error("initial alert")
      ui.checkRetainedCards()
      var changed=JSON.parse(JSON.stringify(state.sources))
      changed[0].rows[0].status="blocked"
      state.receive(JSON.stringify({sources:changed}))
      if(activity.count!==1 || state.waitingCount!==1) throw new Error("blocked alert")
      state.receive(JSON.stringify({sources:changed}))
      if(activity.count!==1) throw new Error("duplicate alert")
      state.receive(JSON.stringify({sources:[{id:"local/default",status:"unavailable",rows:[]}]}))
      state.receive(JSON.stringify({sources:changed}))
      if(activity.count!==1) throw new Error("reconnect alert")
      state.allowed=false
      if(state.rows.length!==0) throw new Error("cleanup rows")
      if(Object.keys(state.alertBaseline).length!==0) throw new Error("cleanup baseline")
      if(overview.available) throw new Error("disabled view")
      console.log("HERDR_PASS")
      } catch(e) {console.error("HERDR_FAIL",e,e.stack)}
      Qt.quit()
    }
  }
}
