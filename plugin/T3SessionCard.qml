import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T3Model.js" as T3

Rectangle {
  id:root
  required property var row
  required property var bridge
  required property var strings
  property bool expanded:false
  property bool active:true
  property var feedback:null
  property bool detailsOpen:false
  readonly property bool islandSpotlightSurface:true
  readonly property var request:row ? row.request : null
  readonly property string requestKey:request ? request.id+":"+request.revision : ""
  readonly property string questionSchema:request && request.canRespond ? JSON.stringify(request.questions) : "[]"
  readonly property string response:request ? bridge.response(request.id) : ""
  readonly property bool blocked:["sending","sent","uncertain"].indexOf(response)>=0
  readonly property bool editable:expanded && bridge.connected && bridge.canRespond && bridge.responsesEnabled && !blocked
  property real now:Date.now()/1000
  onRequestKeyChanged:detailsOpen=false
  signal expandRequested()
  function answers() {
    var result={}
    for(var i=0;i<questions.count;i++) {var q=questions.itemAt(i);if(q.answer.length) result[q.question.id]=q.answer}
    return result
  }
  function valid() {
    if(!questions.count) return false
    var answered=false
    for(var i=0;i<questions.count;i++) {var q=questions.itemAt(i);if(!q || !q.valid) return false;if(q.answer.length) answered=true}
    return answered
  }
  objectName:"t3Session-"+(row ? row.id : "")
  color:Style.normalFillFor(Commons.Color.foreground,Commons.Color.accent)
  border.width:Math.max(1,Style.space(1))
  border.color:row && row.requestId ? Commons.Color.accent : Style.hoverFillFor(Commons.Color.foreground,Commons.Color.accent)
  radius:Style.cornerRadius
  implicitHeight:body.implicitHeight+Style.space(20)
  Timer {interval:1000;repeat:true;running:root.active && root.visible && T3.busy(root.row);onTriggered:root.now=Date.now()/1000}
  ColumnLayout {
    id:body
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Style.space(10)
    spacing:Style.space(8)
    RowLayout {
      Layout.fillWidth:true
      PlainText {Layout.fillWidth:true;text:"T3 Code"+(root.row.project ? " · "+root.row.project : "");font.pixelSize:Style.font.caption;color:Commons.Color.muted;elide:Text.ElideRight}
      PlainText {text:T3.duration(root.row,root.now,Commons.I18n.formatNumber);font.pixelSize:Style.font.caption;color:Commons.Color.muted}
    }
    PlainText {Layout.fillWidth:true;text:root.row.title;wrapMode:Text.Wrap;font.pixelSize:Style.font.body}
    RowLayout {
      Layout.fillWidth:true
      PlainText {text:root.row.requestId ? "󰋗" : T3.busy(root.row) ? "⠿" : root.row.status==="completed" ? "✓" : "·";color:Commons.Color.accent}
      PlainText {
        Layout.fillWidth:true;wrapMode:Text.Wrap;font.pixelSize:Style.font.bodySmall
        text:root.strings.t(!root.bridge.connected ? "t3.disconnected" : root.row.requestId ? (root.row.requestKind==="user_input" ? "t3.needsAnswer" : "t3.needsAction") : "t3.status."+root.row.status)
        color:root.row.requestId ? Commons.Color.accent : Commons.Color.muted
      }
    }
    ColumnLayout {
      Layout.fillWidth:true
      visible:root.expanded && !!root.request && root.request.canRespond
      enabled:root.editable
      spacing:Style.space(12)
      Repeater {
        id:questions
        // Stable serialized schema preserves editors across unrelated status updates.
        model:JSON.parse(root.questionSchema)
        T3Question {required property var modelData;Layout.fillWidth:true;question:modelData;requestKey:root.requestKey;strings:root.strings;feedback:root.feedback}
      }
      FeedbackButton {
        objectName:"t3Submit"
        text:root.strings.t("t3.send")
        focusable:true;bordered:true;feedback:root.feedback
        enabled:root.editable && root.valid()
        onClicked:root.bridge.submit(root.row.id,root.request,root.answers())
      }
    }
    PlainText {
      Layout.fillWidth:true;wrapMode:Text.Wrap;font.pixelSize:Style.font.caption;color:Commons.Color.muted
      visible:root.expanded && !!root.row.requestId && (!root.request || !root.request.canRespond || !root.bridge.canRespond || root.response!=="")
      text:root.strings.t(root.response ? "t3.response."+root.response : !root.bridge.connected ? "t3.response.offline" : root.request && root.request.canRespond && !root.bridge.canRespond ? "t3.readOnly" : "t3.continueInT3")
    }
    PlainText {
      Layout.fillWidth:true;visible:root.expanded && root.detailsOpen
      text:root.request && !root.request.canRespond ? [root.request.prompt,root.request.reason].filter(function(v){return !!v}).join("\n\n") : root.row.summary
      wrapMode:Text.Wrap;font.pixelSize:Style.font.bodySmall
    }
    RowLayout {
      Layout.fillWidth:true
      FeedbackButton {
        objectName:"t3Details"
        text:root.strings.t(root.expanded ? root.detailsOpen ? "t3.hideDetails" : "t3.details" : "t3.expand")
        focusable:root.expanded;feedback:root.feedback
        onClicked:root.expanded ? root.detailsOpen=!root.detailsOpen : root.expandRequested()
      }
      Item {Layout.fillWidth:true}
      FeedbackButton {objectName:"t3Open";text:root.strings.t("t3.open");focusable:root.expanded;feedback:root.feedback;onClicked:root.bridge.openThread(root.row.id)}
    }
  }
}
