import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons

Column {
  id:root
  objectName:"t3Section"
  LayoutMirroring.enabled:Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit:true
  required property var bridge
  required property var strings
  property bool expanded:false
  property bool active:false
  property var feedback:null
  readonly property var rows:bridge ? bridge.rows : []
  signal expandRequested()
  spacing:Design.gap.small
  // Keep surviving cards in place. New events must not move a focused form.
  function sync() {
    var ids=rows.map(function(row){return row.id})
    for(var i=items.count-1;i>=0;i--) if(ids.indexOf(items.get(i).sessionId)<0) items.remove(i)
    for(var j=0;j<ids.length;j++) {
      var found=false
      for(var k=0;k<items.count;k++) if(items.get(k).sessionId===ids[j]) {found=true;break}
      if(!found) items.append({sessionId:ids[j]})
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
    height:Math.min(cards.implicitHeight,Style.space(root.expanded ? 280 : 132))
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
          visible:root.expanded || index<2
          onExpandRequested:root.expandRequested()
        }
      }
    }
  }
}
