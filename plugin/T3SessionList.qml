import QtQuick
import qs.Commons
import qs.Commons as Commons

Column {
  id:root
  LayoutMirroring.enabled:Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit:true
  required property var bridge
  required property var strings
  property bool expanded:false
  property bool active:false
  property var feedback:null
  readonly property var rows:bridge ? bridge.rows : []
  signal expandRequested()
  spacing:Style.space(8)
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
  PlainText {text:root.strings.t("t3.sessions");font.pixelSize:Style.font.caption;color:Commons.Color.muted}
  PlainText {
    width:parent.width;wrapMode:Text.Wrap;font.pixelSize:Style.font.caption;color:Commons.Color.muted
    visible:!!root.bridge && (!root.bridge.connected || root.rows.length===0)
    text:root.strings.t(root.bridge && root.bridge.connected ? "t3.empty" : "t3.connection."+(root.bridge ? root.bridge.status : "offline"))
  }
  ListModel {id:items}
  Repeater {
    model:items
    T3SessionCard {
      required property string sessionId
      required property int index
      width:root.width
      row:root.bridge.row(sessionId) || ({id:sessionId,title:"",project:"",status:"idle",requestId:"",request:null,summary:""})
      bridge:root.bridge;strings:root.strings;expanded:root.expanded;active:root.active;feedback:root.feedback
      visible:root.expanded || index<2
      onExpandRequested:root.expandRequested()
    }
  }
}
