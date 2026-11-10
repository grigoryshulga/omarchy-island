import QtQuick
import QtQuick.Layouts
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  Island.Service {id:service}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    visible:true
    implicitWidth:500;implicitHeight:600
    Island.IslandContent {id:content;anchors.fill:parent;service:service;strings:strings;expanded:true}
    Timer {interval:500;running:true;onTriggered:{try {test.test_lifecycle()} catch(error) {console.log("DOWNLOADS_SERVICE_FAIL",error.stack);Qt.quit()}}}
    Timer {interval:17000;running:true;onTriggered:{console.log("DOWNLOADS_SERVICE_TIMEOUT");Qt.quit()}}
    TestCase {
      id:test
      name:"Downloads"
      when:false
      function send(value) {service.downloadEvent(JSON.stringify(value))}
      function test_lifecycle() {
        tryCompare(service,"loaded",true)
        service.indicators.consumers=[content]
        var path=service.downloadsDir+"/nested/file $ & <name>.zip"
        send({event:"active",files:[{path:path+".part",bytes:1048576}]})
        compare(service.activeDownloads,1)
        compare(service.downloads.length,1)
        compare(service.downloads[0].filename,"file $ & <name>.zip")
        compare(service.entries.length,0)
        compare(service.indicators.osdKind,"download")
        service.indicators.showOsd(JSON.stringify({icon:"volume",value:50,duration:200}))
        wait(300)
        compare(service.indicators.osdKind,"download")
        var category=findChild(content,"islandDownloads")
        tryCompare(category,"visible",true)
        var card=findChild(content,"download-"+service.downloads[0].key)
        verify(card!==null)
        verify(card.implicitHeight<100,"No empty notification footer")
        var progress=findChild(card,"downloadProgress")
        verify(progress.visible)
        verify(progress.width>0 && progress.height>0)
        wait(100)
        var firstPhase=progress.phase
        wait(260)
        if(!Commons.Style.reduceMotion) verify(firstPhase!==progress.phase,"Braille activity must animate")
        send({event:"active",files:[{path:path+".part",bytes:2097152}]})
        wait(50)
        compare(findChild(content,"download-"+service.downloads[0].key),card,"Byte updates preserve delegate and focus")
        compare(service.downloads[0].downloadedBytes,2097152)
        // Cancellation removes the active card without a completion toast.
        send({event:"active",files:[]})
        compare(service.downloads.length,0)
        send({event:"complete",path:path,bytes:3145728})
        compare(service.entries.length,0)
        compare(service.history.length,0)
        compare(service.latest.downloadPath,path)
        compare(service.downloads.length,1)
        wait(50)
        card=findChild(content,"download-"+service.downloads[0].key)
        verify(card!==null)
        verify(card.implicitHeight<90)
        verify(!findChild(card,"downloadProgress").visible)
        service.activate(service.downloads[0])
        compare(service.downloads.length,0)
        send({event:"complete",path:"/tmp/outside",bytes:1})
        compare(service.downloads.length,0)
        service.setDoNotDisturb(true)
        send({event:"complete",path:path,bytes:3145728})
        compare(service.latest,null)
        compare(service.downloads.length,1)
        var expired={downloadPath:path,ts:Date.now()/1000-1801,key:"expired",filename:"expired",downloadedBytes:0,active:false,summary:"expired"}
        service.downloads=[expired]
        tryCompare(service,"downloads",[],2000)
        send({event:"complete",path:path,bytes:3145728})
        service.save()
        wait(400)
        verify(!service.indicators.downloading)
        console.log("DOWNLOADS_SERVICE_PASS")
        Qt.quit()
      }
    }
  }
}
