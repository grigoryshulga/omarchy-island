import QtQuick
import qs.Commons
import "OverviewModel.mjs" as Overview

Item {
  id:root
  required property var entries
  required property Item content
  required property Item viewport
  property bool editing:false
  property string dragKey:""
  property string beforeKey:""
  property point pointer:Qt.point(0,0)
  property real startY:0
  property real offsetY:0
  property real markerY:0
  readonly property bool dragging:dragKey!==""
  signal moved(string key,string beforeKey)
  clip:true
  function cancel(){dragKey="";beforeKey="";offsetY=0}
  onEditingChanged:if(!editing) cancel()
  onVisibleChanged:if(!visible) cancel()
  function geometry() {
    var rows=[]
    for(var i=0;i<entries.count;i++) {var row=entries.itemAt(i);if(row) rows.push({id:row.entryKey,y:row.y,height:row.height})}
    return rows
  }
  function begin(key,point) {
    if(!editing) return
    dragKey=key;startY=viewport.mapToItem(content,point.x,point.y).y
    update(point)
  }
  function update(point) {
    if(!dragging) return
    pointer=point
    var y=viewport.mapToItem(content,point.x,point.y).y,rows=geometry()
    offsetY=y-startY
    beforeKey=Overview.dropBefore(rows,dragKey,y)
    var target=rows.find(function(row){return row.id===root.beforeKey})
    markerY=target ? target.y-content.spacing/2 : rows.length ? rows[rows.length-1].y+rows[rows.length-1].height+content.spacing/2 : 0
  }
  function finish() {
    if(!dragging) return
    var key=dragKey,before=beforeKey,inside=pointer.x>=0 && pointer.x<=viewport.width && pointer.y>=0 && pointer.y<=viewport.height
    cancel()
    if(inside) moved(key,before)
  }
  Timer {
    interval:30;repeat:true;running:root.visible && root.editing && root.dragging
    onTriggered:{
      var edge=Style.space(36),step=root.pointer.y<edge ? -Style.space(12) : root.pointer.y>root.viewport.height-edge ? Style.space(12) : 0
      if(step) {
        root.viewport.contentY=Math.max(0,Math.min(Math.max(0,root.viewport.contentHeight-root.viewport.height),root.viewport.contentY+step))
      }
      root.update(root.pointer)
    }
  }
  Rectangle {
    objectName:"overviewDropMarker"
    visible:root.dragging
    x:root.content.mapToItem(root,0,0).x
    y:root.content.mapToItem(root,0,root.markerY).y-height/2
    width:root.content.width;height:Math.max(2,Style.space(3))
    radius:Math.min(Design.controlRadius,height/2)
    color:Design.accent
  }
}
