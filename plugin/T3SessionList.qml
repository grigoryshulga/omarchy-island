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
  onExpandedChanged:if(!expanded) {listExpanded=false;viewport.contentItem.contentY=0}
  property var feedback:null
  readonly property var rows:bridge ? bridge.rows : []
  signal expandRequested()
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
      if(index<0) items.insert(j,{sessionId:ids[j]})
      else if(index!==j) items.move(index,j,1)
    }
  }
  onRowsChanged:sync()
  Component.onCompleted:sync()
  SectionHeading {width:parent.width;title:"T3 Code";detail:Commons.I18n.formatNumber(root.rows.length)}
  ListModel {id:items}
  Controls.ScrollView {
    id:viewport
    objectName:"t3SessionsScroll"
    width:parent.width
    height:Math.min(cards.implicitHeight,Style.space(root.expanded ? 376 : 352))
    visible:root.rows.length>0
    contentWidth:availableWidth
    clip:true
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Column {
      id:cards
      width:viewport.availableWidth
      spacing:Design.gap.small
      Repeater {
        model:items
        T3SessionCard {
          id:card
          required property string sessionId
          required property int index
          width:cards.width
          row:root.bridge.row(sessionId) || ({id:sessionId,title:"",project:"",status:"idle",requestId:"",request:null,summary:""})
          bridge:root.bridge;strings:root.strings;expanded:root.expanded;feedback:root.feedback
          active:root.active && visible && y+height>viewport.contentItem.contentY && y<viewport.contentItem.contentY+viewport.availableHeight
          visible:root.expanded ? root.listExpanded || index<4 : index===0
          onExpandRequested:root.expandRequested()
        }
      }
    }
  }
  FeedbackButton {
    objectName:"t3ExpandList"
    visible:root.expanded && root.rows.length>4
    width:parent.width
    text:root.listExpanded ? root.strings.t("t3.collapseList") : root.strings.t("t3.expandList").arg(Commons.I18n.formatNumber(root.rows.length-4))
    focusable:root.expanded
    feedback:root.feedback
    onClicked:{if(!root.expanded) root.expandRequested();root.listExpanded=!root.listExpanded}
  }

}
