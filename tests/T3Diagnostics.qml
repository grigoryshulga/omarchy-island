import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  QtObject {
    id:backend
    property bool allowed:true
    property string status:"offline"
    property string reason:"cli_version"
    property string stage:"cli"
    property string serverVersion:"0.1.9-nightly.20261111.4515"
    property string cliVersion:"0.1.10-nightly.20261113.4630"
    property string cliSource:"path"
    property string cliPath:"/home/example/.local/share/t3 code runtimes/versions/0.1.10-nightly.20261113.4630/bin/t3"
    property double lastConnectedAt:1794560000000
    property int reconnects:0
    function restart(){reconnects++;status="connecting";reason=""}
  }
  Island.T3State {id:state;allowed:false}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("Island/i18n")}
  FloatingWindow {
    id:window
    visible:true;implicitWidth:400;implicitHeight:360
    Island.SettingsView {
      id:settings;anchors.fill:parent;category:3
      strings:strings;settings:({t3Enabled:true,t3Responses:true})
      modules:({t3:backend})
    }
    TestCase {
      id:test;when:false
      function run() {
        try {
          var text=findChild(settings,"t3ConnectionReason"),button=findChild(settings,"t3Reconnect")
          verify(text && text.visible,"Offline diagnostic must be accessible in module settings")
          compare(text.text,strings.t("t3.diagnostic.cli_version"))
          verify(findChild(settings,"t3ConnectionVersions").text.indexOf(backend.cliVersion)>=0)
          verify(findChild(settings,"t3ConnectionCli").text.indexOf(backend.cliPath)>=0)
          verify(findChild(settings,"t3ConnectionTime").text.indexOf("%1")<0)
          compare(findChild(settings,"t3ConnectionStage").text,strings.t("t3.stage").arg(strings.t("t3.stage.cli")))
          window.implicitWidth=280;wait(100)
          var cliText=findChild(settings,"t3ConnectionCli")
          verify(cliText.lineCount>1 && !cliText.truncated,"Narrow settings must preserve the full CLI path")
          button.forceActiveFocus();wait(30)
          var viewport=findChild(settings,"settingsViewport"),at=button.mapToItem(viewport,0,0)
          verify(at.y>=0 && at.y+button.height<=viewport.height+1,"Focused reconnect button must scroll into view")
          keyClick(Qt.Key_Return)
          compare(backend.reconnects,1)
          verify(!button.enabled,"Repeated reconnects must be disabled while connecting")
          verify(!text.visible,"Retry clears stale error")
          backend.status="connected";wait(30)
          verify(button.enabled)
          compare(findChild(settings,"t3ConnectionStatus").text,strings.t("t3.connection.connected"))
          backend.allowed=false;wait(30)
          verify(!button.enabled)
          compare(findChild(settings,"t3ConnectionStatus").text,strings.t("t3.connection.disabled"))
          backend.allowed=true;backend.status="offline";backend.reason="runtime";backend.stage="runtime"
          backend.cliPath="";backend.serverVersion="";wait(30)
          verify(!findChild(settings,"t3ConnectionVersions").visible)
          verify(!findChild(settings,"t3ConnectionCli").visible)
          verify(findChild(settings,"t3ConnectionTime").visible,"Last success survives failed reconnects")
          var event={type:"connection",status:"offline",reason:"cli_version",stage:"cli",serverVersion:"1.0.0",cliVersion:"2.0.0",cliPath:"/cli",cliSource:"path",lastConnectedAt:1234}
          state.receive(JSON.stringify(event))
          compare(state.reason,event.reason);compare(state.stage,event.stage)
          compare(state.serverVersion,event.serverVersion);compare(state.cliVersion,event.cliVersion)
          compare(state.cliPath,event.cliPath);compare(state.cliSource,event.cliSource)
          compare(state.lastConnectedAt,1234)
          state.receive('{"type":"connection","status":"connecting","lastConnectedAt":0}')
          compare(state.reason,"");compare(state.lastConnectedAt,1234)
          console.log("T3_DIAGNOSTICS_PASS")
        } catch(error) {console.log("T3_DIAGNOSTICS_FAIL",error.stack)}
        Qt.quit()
      }
    }
    Timer {interval:400;running:true;onTriggered:test.run()}
    Timer {interval:8000;running:true;onTriggered:{console.log("T3_DIAGNOSTICS_TIMEOUT");Qt.quit()}}
  }
}
