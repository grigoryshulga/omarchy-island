import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "T3Model.js" as T3

ContainerSurface {
  id:root
  required property var row
  required property var bridge
  required property var strings
  property bool expanded:false
  property bool active:true
  property var feedback:null
  property bool detailsOpen:false
  property bool compactToast:false
  property bool compactOverview:false
  readonly property var statusIcon:working ? workingIcon : stateIcon
  readonly property bool islandSpotlightSurface:true
  readonly property var request:row ? row.request : null
  readonly property bool needsInput:!!row.requestId
  readonly property bool working:T3.busy(row) && !needsInput
  readonly property string requestKey:request ? request.id+":"+request.revision : ""
  readonly property string questionSchema:request && request.canRespond ? JSON.stringify(request.questions) : "[]"
  readonly property string response:request ? bridge.response(request.id) : ""
  readonly property bool blocked:["sending","sent","uncertain"].indexOf(response)>=0
  readonly property bool editable:expanded && !!bridge && bridge.connected && bridge.canRespond && bridge.responsesEnabled && !blocked
  readonly property color statusColor:!bridge || !bridge.connected ? Design.secondaryText : Design[T3.statusRole(row)]
  readonly property string statusText:strings.t(!bridge || !bridge.connected ? "t3.disconnected" : needsInput ? (row.requestKind==="user_input" ? "t3.needsAnswer" : "t3.needsAction") : "t3.status."+row.status)
  readonly property string detailText:request && !request.canRespond ? [request.prompt,request.reason].filter(function(v){return !!v}).join("\n\n") : row.summary
  property real now:Date.now()/1000
  onRequestKeyChanged:detailsOpen=false
  signal expandRequested()
  signal overviewDetailsRequested()
  function openDetails() {
    if(compactOverview && expanded) overviewDetailsRequested()
    else if(expanded) detailsOpen=!detailsOpen
    else expandRequested()
  }
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
  color:Design.surface
  border.width:0
  radius:Design.cardRadius
  implicitHeight:body.implicitHeight+2*Design.cardPadding
  Timer {interval:1000;repeat:true;running:root.active && root.visible && T3.busy(root.row);onTriggered:root.now=Date.now()/1000}
  FeedbackButton {
    id:detailsSurface
    objectName:"t3Details"
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    height:header.height+2*Design.cardPadding
    visible:root.compactOverview || !root.expanded || root.detailText!==""
    tooltipText:root.strings.t(root.expanded ? root.detailsOpen ? "t3.hideDetails" : "t3.details" : "t3.expand")
    Accessible.name:root.row.title+" · "+tooltipText
    focusable:root.expanded;feedback:root.feedback
    radius:root.radius;borderSpec:Border.none()
    color:hot ? Design.hover : "transparent"
    onClicked:root.openDetails()
    Rectangle {
      objectName:"threadFocusUnderline"
      x:Design.cardPadding;y:parent.height-Design.gap.small
      width:Math.min(Style.space(48),parent.width-2*Design.cardPadding)
      height:Math.max(1,Style.space(1));color:Design.focusRing;visible:detailsSurface.activeFocus
    }
  }
  ColumnLayout {
    id:body
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Design.cardPadding
    spacing:Design.gap.medium
    RowLayout {
      id:header
      Layout.fillWidth:true
      spacing:Design.gap.medium
      Item {
        id:statusSlot
        implicitWidth:Math.max(Style.space(20),Style.font.iconLarge)
        implicitHeight:titleRow.height
        Layout.minimumWidth:implicitWidth;Layout.maximumWidth:implicitWidth
        Layout.alignment:Qt.AlignTop
        T3Spinner {id:workingIcon;objectName:"t3SessionSpinner";anchors.centerIn:parent;visible:root.working;active:root.active && root.bridge.connected;tint:root.statusColor}
        PlainText {
          id:stateIcon
          anchors.fill:parent;visible:!root.working
          text:root.needsInput ? "󰋗" : root.row.status==="failed" ? "󰅙" : root.row.status==="completed" ? "✓" : "·"
          font.pixelSize:Style.font.iconLarge
          Accessible.name:root.statusText
          color:root.statusColor
          horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
        }
      }
      ColumnLayout {
        Layout.fillWidth:true;Layout.minimumWidth:0
        spacing:Design.gap.tight
        RowLayout {
          id:titleRow
          Layout.minimumHeight:root.compactOverview ? Design.controlHeight : 0
          Layout.fillWidth:true;spacing:Design.gap.small
          FeedbackButton {
            id:titleLink
            objectName:"t3Open"
            Layout.fillWidth:true;Layout.minimumWidth:0
            borderSpec:Border.none()
            text:"";tooltipText:root.strings.t("t3.open");Accessible.name:root.row.title
            implicitHeight:titleLabel.implicitHeight+Style.space(4)
            horizontalPadding:0;verticalPadding:Design.gap.micro
            focusable:root.expanded;feedback:root.feedback;onClicked:root.bridge.openThread(root.row.id)
            Rectangle {
              objectName:"threadTitleFocusUnderline"
              anchors.left:parent.left;anchors.bottom:parent.bottom
              width:Math.min(titleLabel.paintedWidth,titleLabel.width);height:Math.max(1,Style.space(1))
              color:Design.focusRing;visible:titleLink.activeFocus
            }
            PlainText {
              id:titleLabel
              objectName:"t3SessionTitle"
              anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter
              text:root.row.title;typeRole:"body";font.weight:Font.DemiBold;elide:Text.ElideRight
            }
          }
          PlainText {visible:root.compactOverview && root.needsInput;text:root.statusText;typeRole:"caption";color:root.statusColor;Layout.maximumWidth:root.width*0.3;elide:Text.ElideRight}
          PlainText {text:T3.duration(root.row,root.now,Commons.I18n.formatNumber);typeRole:"caption";color:Design.secondaryText}

        }
        RowLayout {
          visible:!root.compactOverview
          Layout.fillWidth:true;spacing:Design.gap.medium
          ProjectIcon {objectName:"t3ProjectIcon";visible:!!root.row.project;icon:root.row.projectIcon || null;Layout.alignment:Qt.AlignVCenter}
          PlainText {Layout.fillWidth:true;Layout.minimumWidth:0;text:root.row.project;typeRole:"caption";color:Design.secondaryText;elide:Text.ElideRight}
          PlainText {objectName:"t3StatusLabel";visible:!root.needsInput || root.compactToast;Layout.maximumWidth:Math.max(Style.space(80),(root.width-Style.space(48))*0.65);text:root.statusText;typeRole:"caption";color:root.statusColor;horizontalAlignment:Text.AlignRight;elide:Text.ElideRight}
        }
      }
    }
    ColumnLayout {
      Layout.fillWidth:true
      visible:root.expanded && !root.compactOverview && !!root.request && root.request.canRespond
      enabled:root.editable
      spacing:Design.gap.medium
      Repeater {
        id:questions
        // Stable serialized schema preserves editors across unrelated status updates.
        model:JSON.parse(root.questionSchema)
        T3Question {
          required property var modelData
          required property int index
          Layout.fillWidth:true;question:modelData;requestKey:root.requestKey;strings:root.strings;feedback:root.feedback
          showSubmit:index===questions.count-1
          submitEnabled:root.editable && root.valid()
          submitting:root.response==="sending"
          onSubmitRequested:root.bridge.submit(root.row.id,root.request,root.answers())
        }
      }
    }
    PlainText {
      Layout.fillWidth:true;wrapMode:Text.Wrap;typeRole:"caption";color:Design.secondaryText
      visible:root.expanded && !root.compactOverview && root.needsInput && (!root.request || !root.request.canRespond || !root.bridge.canRespond || (root.response!=="" && root.response!=="sending"))
      text:root.strings.t(root.response ? "t3.response."+root.response : (!root.bridge || !root.bridge.connected) ? "t3.response.offline" : root.request && root.request.canRespond && !root.bridge.canRespond ? "t3.readOnly" : "t3.continueInT3")
    }
    PlainText {
      Layout.fillWidth:true;visible:root.expanded && !root.compactOverview && root.detailsOpen
      text:root.detailText;wrapMode:Text.Wrap;typeRole:"caption"
    }
  }
}
