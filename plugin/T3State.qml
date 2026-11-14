import QtQuick
import qs.Commons
import "Security.js" as Security

AgentSessionState {
  bridgeCommand:["python3",String(Qt.resolvedUrl("bin/t3-bridge")).replace(/^file:\/\//,"")]
  allowed:Preferences.get("t3Enabled")
  responsesEnabled:Preferences.get("t3Responses")
  function openThread(id) {
    if(!allowed) return
    var url=Security.t3ThreadUrl(environmentId,id)
    if(url && row(id)) openUrl(url)
  }
}
