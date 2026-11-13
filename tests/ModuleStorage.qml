import QtQuick
import QtTest
import Quickshell
import "Island" as Island
import "Island/ModuleCatalog.mjs" as Catalog

ShellRoot {
  id:scene
  readonly property string moduleId:Quickshell.env("ISLAND_STORAGE_MODULE")
  ModuleHost {id:host;registry:registry}
  Island.ModuleRegistry {
    id:registry;host:host
    definitions:[Catalog.definition(scene.moduleId)]
    stateProperties:{
      var props={allowed:false,stateDir:Quickshell.env("ISLAND_MODULE_STORAGE"),clock:function(){return host.now}}
      if(scene.moduleId==="downloads") {
        props.downloadsDir=Quickshell.env("ISLAND_MODULE_STORAGE")+"/downloads"
        props.watcherCommand=["python3","-c","import time; time.sleep(30)"]
      }
      var result={};result[scene.moduleId]=props;return result
    }
  }
  TestCase {
    id:test;when:false
    function run(){
      tryVerify(function(){return !!registry.backends[scene.moduleId]})
      compare(Object.keys(registry.backends).length,1,"Another module was needed to restore state")
      var backend=registry.backends[scene.moduleId],downloads=scene.moduleId==="downloads"
      wait(80)
      verify(!(downloads ? backend.restored : backend.loaded),"Disabled module loaded storage")
      var failure=Quickshell.env("ISLAND_STORAGE_FAILURE"),command=backend.storageCommand
      if(failure) {
        backend.storageCommand=failure==="missing" ? ["/nonexistent/island-state-helper"] : ["python3","-c",failure==="timeout" ? "import time; time.sleep(30)" : "raise SystemExit(1)"]
        backend.allowed=true
        tryCompare(backend,"error","state",6500)
        verify(!(downloads ? backend.restored : backend.loaded),"Failed storage initialization marked state loaded")
        backend.allowed=false
        backend.storageCommand=command
      }
      backend.allowed=true
      tryCompare(backend,downloads ? "restored" : "loaded",true)
      compare((downloads ? backend.downloads : backend.history).length,Number(Quickshell.env("ISLAND_STORAGE_COUNT")))
      if(failure) compare(backend.error,"","Storage did not recover after re-enabling")
      if(!downloads && Quickshell.env("ISLAND_STORAGE_DND")==="1") {
        verify(backend.doNotDisturb)
        compare(backend.mutedSources[0],"Muted sender")
      }
      if(Quickshell.env("ISLAND_STORAGE_CLEAR")==="1") {
        if(downloads) backend.downloads.slice().forEach(function(row){backend.remove(row.key)})
        else backend.clearHistory()
      }
      backend.save()
      tryVerify(function(){return findChild(backend,"moduleStorage").settled},3000)
      backend.allowed=false
      console.log("MODULE_STORAGE_PASS");Qt.quit()
    }
  }
  Timer {interval:100;running:true;onTriggered:{try{test.run()}catch(error){console.log("MODULES_FAIL",error.stack);Qt.quit()}}}
}
