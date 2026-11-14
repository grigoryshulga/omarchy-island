import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/AgentUsageModel.js" as Usage

ShellRoot {
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  QtObject {
    id:backend
    property double now:new Date(2026,10,14,12).getTime()
    property var cache:({providers:[{id:"codex",name:"Codex",total:{tokens:1200000},days:[{date:"2026-11-14",tokens:1000000,cost:1,requests:25,priced:true},{date:"2026-11-13",tokens:200000,cost:0.2,requests:5,priced:true}],modelDays:{"2026-11-14":[{name:"example",tokens:1000000,cost:1,priced:true}]}}]})
  }
  FloatingWindow {
    id:window;visible:true;implicitWidth:500;implicitHeight:600;color:Island.Design.opaqueCanvas
    Island.AgentUsage {id:usage;width:parent.width;availableHeight:600;backend:backend;strings:strings}
    TestCase {
      id:test;when:false
      function run() {
        compare(usage.report.total.tokens,1200000)
        var bucket=findChild(usage,"usageBucket-2026-11-14")
        bucket.forceActiveFocus();keyClick(Qt.Key_Return);wait(30)
        compare(usage.report.total.tokens,1000000)
        verify(bucket.activeFocus && findChild(usage,"usageBucket-2026-11-14")===bucket,"selection recreated chart controls")
        compare(usage.report.models[0].totals.tokens,1000000)
        backend.cache=JSON.parse(JSON.stringify(backend.cache));wait(20)
        verify(bucket.activeFocus && findChild(usage,"usageBucket-2026-11-14")===bucket,"refresh recreated chart controls")
        usage.metric="cost";wait(20)
        compare(usage.selectedPeriod,"2026-11-14")
        compare(usage.report.total.cost,1)
        usage.providerId="codex";usage.range="month";wait(30)
        compare(usage.selectedPeriod,"")
        compare(usage.providerId,"codex")
        usage.width=360;Commons.Style.fontBaseSize=18;wait(20)
        verify(usage.height<=usage.availableHeight+1,"usage content exceeds fixed viewport")
        var scroll=findChild(usage,"agentUsageScroll")
        scroll.contentItem.contentY=60;wait(20)
        verify(scroll.y>0,"filters scroll with content")
        if(Quickshell.env("ISLAND_USAGE_CAPTURE")) grabImage(window.contentItem).save(Quickshell.env("ISLAND_USAGE_CAPTURE"))
        console.log("USAGE_PASS");Qt.quit()
      }
    }
    Timer {interval:150;running:true;onTriggered:{try{test.run()}catch(e){console.log("USAGE_FAIL",e,e.stack);Qt.quit()}}}
  }
}
