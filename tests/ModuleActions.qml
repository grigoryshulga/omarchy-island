import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "Island" as Island
import "Island/ModuleCatalog.mjs" as Catalog

ShellRoot {
  ModuleHost {id:host;registry:registry}
  Island.ModuleRegistry {
    id:registry
    definitions:[Catalog.definition("downloads"),Catalog.definition("calendar")]
    stateProperties:({downloads:{allowed:false,
      stateDir:Quickshell.env("ISLAND_MODULE_STORAGE"),
      downloadsDir:Quickshell.env("ISLAND_MODULE_STORAGE")+"/downloads",
      watcherCommand:["python3",Quickshell.env("ISLAND_MODULE_HELPER")],
      clock:function(){return host.now},execute:function(argv){host.execute(argv)}},
      calendar:{allowed:false,clock:function(){return host.now/1000},
        helperCommand:["python3","-c","raise SystemExit('disabled calendar started')"],
        reminderCommand:["python3","-c","import json; print(json.dumps({'reminders': []}))"]}})
  }
  FileView {
    id:log;path:Quickshell.env("ISLAND_MODULE_STORAGE")+"/watcher.jsonl"
    watchChanges:true;printErrors:false
    onFileChanged:reload()
  }
  TestCase {
    id:test;when:false
    function events(kind){return log.text().split("\n").filter(function(line){return line && JSON.parse(line).event===kind}).length}
    function run() {
      tryVerify(function(){return !!registry.backends.downloads})
      var backend=registry.backends.downloads,path=backend.downloadsDir+"/example $ file.zip"
      backend.downloadEvent(JSON.stringify({event:"complete",path:path,bytes:10}))
      compare(backend.downloads.length,0,"Disabled backend consumed a watcher event")
      verify(!backend.openDownload({downloadPath:path}));compare(host.actions.length,0)
      backend.allowed=true
      tryCompare(backend,"restored",true)
      tryCompare(backend,"activeDownloads",1,3000)
      tryVerify(function(){return events("start")===1},3000)
      backend.downloadEvent(JSON.stringify({event:"active",files:[]}))
      backend.downloadEvent("malformed")
      backend.downloadEvent(JSON.stringify({event:"complete",path:"/outside/file",bytes:10}))
      compare(backend.downloads.length,0)
      backend.downloadEvent(JSON.stringify({event:"complete",path:path,bytes:10}))
      compare(backend.downloads.length,1)
      verify(Math.abs(backend.downloads[0].ts-host.now/1000)<0.01,"Injected clock was ignored")
      verify(!backend.openDownload({downloadPath:"/outside/file"}));compare(host.actions.length,0)
      backend.openDownload(backend.downloads[0])
      compare(host.actions.length,1);compare(host.actions[0][0],"xdg-open")
      compare(host.actions[0][1],backend.downloadsDir)
      backend.allowed=false
      tryVerify(function(){return events("stop")===1},3000)
      compare(backend.activeDownloads,0)
      backend.allowed=true
      tryCompare(backend,"activeDownloads",1,3000)
      tryVerify(function(){return events("start")===2},3000)
      backend.allowed=false
      tryVerify(function(){return events("stop")===2},3000)
      compare(events("start"),2,"Re-enable duplicated the watcher")
      var calendar=registry.backends.calendar
      verify(!calendar.allowed && !calendar.reminders.allowed && !calendar.calendars.allowed)
      calendar.reminders.now=0
      calendar.allowed=true
      tryCompare(calendar.reminders,"now",host.now/1000)
      calendar.allowed=false
      var stoppedTime=calendar.reminders.now
      host.now+=5000;wait(1100)
      compare(calendar.reminders.now,stoppedTime,"Disabled reminder clock kept running")
      calendar.allowed=true
      tryCompare(calendar.reminders,"now",host.now/1000)
      compare(calendar.reminders.error,"")
      calendar.allowed=false
      console.log("MODULE_ACTIONS_PASS");Qt.quit()
    }
  }
  Timer {running:true;interval:100;onTriggered:{try{test.run()}catch(error){console.log("MODULES_FAIL",error.stack);Qt.quit()}}}
  Timer {running:true;interval:10000;onTriggered:{console.log("MODULES_TIMEOUT");Qt.quit()}}
}
