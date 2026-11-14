import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import "T3Model.js" as T3

Column {
  id:root
  objectName:"t3Section"
  LayoutMirroring.enabled:Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit:true
  required property var bridge
  required property var strings
  property bool expanded:false
  property bool active:false
  property bool listExpanded:false
  property bool summaryMode:false
  property bool allSessions:false
  property real maximumHeight:Style.space(376)
  readonly property var summaryIds:T3.overviewRows(rows)
  readonly property var counts:T3.counts(rows)
  onExpandedChanged:if(!expanded) {listExpanded=false;viewport.contentItem.contentY=0}
  property var feedback:null
  readonly property var rows:bridge ? bridge.rows : []
  signal expandRequested()
  signal detailsRequested()
  spacing:Design.gap.small
  // Keep stable delegates and order within each status group, including drafts.
  function sync() {
    var previous=[]
    for(var n=0;n<items.count;n++) previous.push(items.get(n).sessionId)
    var ordered=rows.slice().sort(function(a,b){
      var rank=T3.statusRank(a)-T3.statusRank(b)
      var ai=previous.indexOf(a.id),bi=previous.indexOf(b.id)
      if(ai<0) ai=previous.length+rows.indexOf(a)
      if(bi<0) bi=previous.length+rows.indexOf(b)
      return rank || ai-bi
    })
    var ids=ordered.map(function(row){return row.id})
    for(var i=items.count-1;i>=0;i--) if(ids.indexOf(items.get(i).sessionId)<0) items.remove(i)
    for(var j=0;j<ids.length;j++) {
      var index=-1
      for(var k=j;k<items.count;k++) if(items.get(k).sessionId===ids[j]) {index=k;break}
      if(index<0) items.insert(j,{sessionId:ids[j],groupKey:T3.statusGroup(ordered[j]),groupStart:false})
      else if(index!==j) items.move(index,j,1)
      items.setProperty(j,"groupKey",T3.statusGroup(ordered[j]))
      items.setProperty(j,"groupStart",j===0 || T3.statusGroup(ordered[j-1])!==T3.statusGroup(ordered[j]))
    }
  }
  onRowsChanged:sync()
  Component.onCompleted:sync()
  Item {
    visible:!root.allSessions
    width:parent.width
    implicitHeight:Math.max(headingContent.implicitHeight,sectionTitle.implicitHeight)
    HoverHandler {id:headerHover}
    SectionLink {
      id:sectionTitle;objectName:"t3OpenDetails"
      anchors.fill:parent
      focusable:root.expanded && root.summaryMode;feedback:root.feedback
      hasCursor:headerHover.hovered
      title:"T3 Code";detail:root.summaryMode ? "" : Commons.I18n.formatNumber(root.rows.length)
      onClicked:root.expanded ? root.detailsRequested() : root.expandRequested()
    }
    Flow {
      id:headingContent
      objectName:"t3SummaryHeading"
      anchors.right:parent.right
      anchors.rightMargin:Design.gap.small
      width:Math.max(0,parent.width-sectionTitle.implicitWidth-Design.gap.small)
      layoutDirection:Qt.RightToLeft
      spacing:Design.gap.small
      Repeater {
        model:[{key:"attention",icon:"󰋗",role:"warning"},{key:"working",icon:"",role:"info"},{key:"finished",icon:"✓",role:"success"},{key:"failed",icon:"󰅙",role:"danger"},{key:"other",icon:"·",role:"secondaryText"}]
        FeedbackButton {
          id:badge
          required property var modelData
          readonly property int count:root.counts[modelData.key]
          readonly property color tint:Design[modelData.role]
          objectName:"t3Count-"+modelData.key
          visible:root.summaryMode && count>0
          compact:true;focusable:root.expanded;feedback:root.feedback
          horizontalPadding:Design.gap.tight
          implicitWidth:badgeContent.implicitWidth+2*horizontalPadding
          tooltipText:root.strings.t("overview.t3"+modelData.key.charAt(0).toUpperCase()+modelData.key.slice(1)).arg(Commons.I18n.formatNumber(count))
          Accessible.name:tooltipText
          onClicked:root.expanded ? root.detailsRequested() : root.expandRequested()
          RowLayout {
            id:badgeContent
            anchors.centerIn:parent
            spacing:Design.gap.micro
            T3Spinner {objectName:"t3CountSpinner";visible:badge.modelData.key==="working";active:root.active && root.visible;tint:badge.tint}
            PlainText {visible:badge.modelData.key!=="working";text:badge.modelData.icon;typeRole:"caption";color:badge.tint}
            PlainText {text:Commons.I18n.formatNumber(badge.count);typeRole:"caption";color:badge.tint}
          }
        }
      }
    }
  }
  ListModel {id:items}
  Controls.ScrollView {
    id:viewport
    objectName:"t3SessionsScroll"
    width:parent.width
    height:Math.min(cards.implicitHeight,root.summaryMode ? Style.space(144) : root.maximumHeight)
    visible:root.rows.length>0
    contentWidth:availableWidth
    clip:true
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Controls.ScrollBar.vertical.policy:Controls.ScrollBar.AlwaysOff
    Column {
      id:cards
      width:viewport.availableWidth
      spacing:Design.gap.small
      Repeater {
        model:items
        Column {
          id:groupRow
          required property string sessionId
          required property string groupKey
          required property bool groupStart
          required property int index
          width:cards.width
          spacing:Design.gap.small
          visible:root.summaryMode ? root.summaryIds.indexOf(sessionId)>=0 && (root.expanded || index===0) : root.expanded ? root.allSessions || root.listExpanded || index<4 : index===0
          PlainText {
            objectName:"t3Group-"+groupRow.sessionId
            width:parent.width
            visible:!root.summaryMode && root.expanded && groupRow.groupStart
            text:root.strings.t("t3.group."+groupRow.groupKey)
            typeRole:"caption"
            color:Design.secondaryText
          }
          T3SessionCard {
            id:card
            readonly property string sessionId:groupRow.sessionId
            readonly property int index:groupRow.index
            width:groupRow.width
            row:root.bridge.row(sessionId) || ({id:sessionId,title:"",project:"",status:"idle",requestId:"",request:null,summary:""})
            bridge:root.bridge;strings:root.strings;expanded:root.expanded;feedback:root.feedback
            compactOverview:root.summaryMode
            active:root.active && visible && groupRow.y+y+height>viewport.contentItem.contentY && groupRow.y+y<viewport.contentItem.contentY+viewport.availableHeight
            onExpandRequested:root.expandRequested()
            onOverviewDetailsRequested:root.detailsRequested()
          }
        }
      }
    }
  }
  FeedbackButton {
    objectName:"t3ExpandList"
    visible:!root.summaryMode && !root.allSessions && root.expanded && root.rows.length>4
    width:parent.width
    text:root.listExpanded ? root.strings.t("t3.collapseList") : root.strings.t("t3.expandList").arg(Commons.I18n.formatNumber(root.rows.length-4))
    focusable:root.expanded
    feedback:root.feedback
    onClicked:{if(!root.expanded) root.expandRequested();root.listExpanded=!root.listExpanded}
  }

}
