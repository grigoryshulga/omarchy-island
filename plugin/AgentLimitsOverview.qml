import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import "AgentLimitsModel.js" as Model

Column {
  id:root
  objectName:"agentLimitsSection"
  required property var backend
  required property var strings
  property bool expanded:false
  property bool centerOpen:false
  property var feedback:null
  property var rows:backend ? backend.summary : []
  signal settingRequested(string key,var value)
  signal expandRequested()
  spacing:Design.gap.small
  LayoutMirroring.enabled:Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit:true
  onExpandedChanged:if(!expanded) centerOpen=false
  onVisibleChanged:if(visible) sync(true)
  // Existing delegates keep their place and keyboard focus during refreshes.
  function sync(reorder) {
    var ids=rows.map(function(r){return r.id})
    for(var i=items.count-1;i>=0;i--) if(ids.indexOf(items.get(i).windowId)<0) items.remove(i)
    ids.forEach(function(id){for(var j=0;j<items.count;j++) if(items.get(j).windowId===id) return;items.append({windowId:id})})
    if(reorder) ids.forEach(function(id,at){for(var j=at;j<items.count;j++) if(items.get(j).windowId===id) {if(j!==at) items.move(j,at,1);break}})
  }
  onRowsChanged:sync()
  Component.onCompleted:sync()
  function pin(id) {settingRequested("agentLimitsPins",Model.toggle(backend.pins,id))}
  RowLayout {
    width:parent.width
    SectionHeading {Layout.fillWidth:true;title:root.strings.t("limits.title")}
    FeedbackButton {
      objectName:"limitsExpand"
      iconText:(root.centerOpen !== Commons.I18n.rightToLeft) ? "󰁍" : "󰁔"
      iconSize:Style.font.iconLarge
      tooltipText:root.strings.t(root.centerOpen ? "calendar.back" : "limits.all")
      implicitWidth:Design.compactControlHeight
      implicitHeight:Design.compactControlHeight
      horizontalPadding:0;verticalPadding:0
      compact:true;focusable:root.expanded;feedback:root.feedback
      onClicked:{if(!root.expanded) root.expandRequested();else {root.centerOpen=!root.centerOpen;if(!root.centerOpen) root.sync(true)}}
    }
  }
  ListModel {id:items}
  Controls.ScrollView {
    id:viewport
    visible:!root.centerOpen && root.rows.length>0
    width:parent.width;height:Math.min(cards.implicitHeight,Style.space(root.expanded ? 220 : 130))
    clip:true;contentWidth:availableWidth
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    Column {
      id:cards;width:viewport.availableWidth;spacing:Design.gap.small
      Repeater {
        model:items
        AgentLimitRow {
          required property string windowId
          width:cards.width
          row:root.rows.find(function(r){return r.id===windowId}) || ({id:windowId,name:"",label:"",remaining:null})
          strings:root.strings;feedback:root.feedback
          pinned:root.backend.pins.indexOf(windowId)>=0;interactive:root.expanded
          now:root.backend.now
          onPinRequested:id=>root.pin(id)
        }
      }
    }
  }
  PlainText {
    visible:!root.centerOpen && !root.rows.length
    width:parent.width;typeRole:"caption";color:Design.secondaryText;wrapMode:Text.Wrap
    text:root.strings.t(root.backend && root.backend.error ? "limits.error" : root.backend && root.backend.busy ? "limits.loading" : "limits.quiet")
  }
  AgentLimitsCenter {
    width:parent.width
    visible:root.centerOpen && root.expanded
    backend:root.backend;strings:root.strings;feedback:root.feedback
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
  }
}
