import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
  id:board
  required property var editor
  required property Flickable viewport
  property string dragged:""
  property string targetSide:""
  property string beforeId:""
  property real markerY:0
  property point pointer:Qt.point(0,0)
  property point localPointer
  implicitHeight:columns.implicitHeight
  function cancel() {dragged="";targetSide="";beforeId=""}
  function focusElement(id) {
    for (var i=0;i<2;i++) {
      var card=lanes.itemAt(i).cardFor(id)
      if (card) {card.forceActiveFocus(Qt.TabFocusReason);return}
    }
  }
  function update(point) {
    pointer=point
    var p=mapFromItem(viewport,point.x,point.y)
    localPointer=p
    targetSide=""
    if (p.x<0 || p.x>width || p.y<0 || p.y>height || point.y<0 || point.y>viewport.height) return
    var left=lanes.itemAt(0),right=lanes.itemAt(1)
    var lane=Math.abs(p.x-left.x-left.width/2)<=Math.abs(p.x-right.x-right.width/2) ? left : right
    targetSide=lane.side
    beforeId=""
    markerY=lane.list.y
    for (var i=0;i<lane.cards.count;i++) {
      var tile=lane.cards.itemAt(i)
      if (tile.row.id===dragged) continue
      var y=tile.mapToItem(board,0,0).y
      if (p.y<y+tile.height/2) {beforeId=tile.row.id;markerY=y;break}
      markerY=y+tile.height+lane.list.spacing
    }
  }
  function finish() {
    var id=dragged,side=targetSide,before=beforeId
    cancel()
    if (id && side) editor.reorder(id,side,before)
  }
  onVisibleChanged:if(!visible) cancel()
  Timer {
    interval:30;repeat:true;running:board.visible && board.dragged!==""
    onTriggered:{
      var edge=Style.space(34),y=board.pointer.y
      var step=y>=0 && y<edge ? -Style.space(12) : y<=board.viewport.height && y>board.viewport.height-edge ? Style.space(12) : 0
      if(step) {
        board.viewport.contentY=Math.max(0,Math.min(Math.max(0,board.viewport.contentHeight-board.viewport.height),board.viewport.contentY+step))
        board.update(board.pointer)
      }
    }
  }
  RowLayout {
    id:columns;width:parent.width;spacing:Design.gap.small
    layoutDirection:Qt.LeftToRight
    Repeater {
      id:lanes
      model:["left","right"]
      Rectangle {
        id:lane
        required property string modelData
        readonly property string side:modelData
        property alias cards:cards
        property alias list:list
        function cardFor(id) {
          for(var i=0;i<cards.count;i++) if(cards.itemAt(i).row.id===id) return cards.itemAt(i)
          return null
        }
        objectName:"clockLane-"+side
        Layout.preferredWidth:(board.width-columns.spacing)/2;Layout.minimumWidth:0;Layout.fillHeight:true
        implicitHeight:list.y+Math.max(Style.space(44),list.implicitHeight)+Design.gap.small
        color:Design.surface;radius:Design.cardRadius
        border.width:board.targetSide===side ? Style.space(1) : 0;border.color:Design.accent
        PlainText {
          id:heading;x:Design.gap.small;y:x;width:parent.width-2*x
          typeRole:"label";wrapMode:Text.Wrap
          text:board.editor.strings.t("clock."+ (board.editor.vertical ? (lane.side==="left" ? "above" : "below") : lane.side))
        }
        Column {
          id:list;x:Design.gap.small;y:heading.y+heading.height+Design.gap.small
          width:parent.width-2*x;spacing:Design.gap.small
          Repeater {
            id:cards
            model:board.editor.elements.filter(row=>row.side===lane.side)
            FeedbackButton {
              id:tile
              required property var modelData
              readonly property var row:modelData
              objectName:"clockTile-"+row.id
              width:list.width;height:Math.max(Style.space(44),caption.implicitHeight+2*Design.gap.small)
              leftAlign:true;focusable:true;variant:"soft";selected:board.editor.selectedId===row.id
              Accessible.name:board.editor.elementTitle(row)
              iconText:"⠿"
              PlainText {
                id:caption
                anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter
                anchors.leftMargin:tile.horizontalPadding+tile.iconSize+Design.gap.small
                anchors.rightMargin:tile.horizontalPadding
                text:tile.Accessible.name;typeRole:"label";wrapMode:Text.Wrap
                maximumLineCount:3;elide:Text.ElideRight
                color:tile.selected ? Design.selectedText : Design.text
              }
              horizontalPadding:Design.gap.small
              opacity:board.dragged===row.id ? 0.4 : 1
              onClicked:board.editor.selectedId=row.id
              onActiveFocusChanged:if(activeFocus) {board.editor.selectedId=row.id;board.editor.revealFocus(tile)}
              MouseArea {
                anchors.fill:parent;preventStealing:true;hoverEnabled:true
                cursorShape:pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property bool moving:false
                onPressed:mouse=>{
                  moving=false;tile.forceActiveFocus(Qt.MouseFocusReason)
                  start=mapToItem(board.viewport,mouse.x,mouse.y)
                }
                onPositionChanged:mouse=>{
                  if(!pressed) return
                  var point=mapToItem(board.viewport,mouse.x,mouse.y)
                  if(!moving && Math.hypot(point.x-start.x,point.y-start.y)>=Qt.styleHints.startDragDistance) {
                    board.dragged=tile.row.id;moving=true
                  }
                  if(board.dragged===tile.row.id) board.update(point)
                }
                onReleased:mouse=>{
                  if(board.dragged===tile.row.id) {board.update(mapToItem(board.viewport,mouse.x,mouse.y));board.finish()}
                  else if(!moving) tile.clicked()
                }
                onCanceled:board.cancel()
                Component.onDestruction:if(board && board.dragged===tile.row.id) board.cancel()
              }
            }
          }
        }
        Rectangle {
          visible:board.targetSide===lane.side
          x:list.x;y:board.markerY-Design.gap.small/2;width:list.width;height:Math.max(2,Style.space(2));color:Design.accent
        }
      }
    }
  }
  FeedbackButton {
    z:2
    visible:board.dragged!==""
    x:Math.max(0,Math.min(board.width-width,board.localPointer.x-width/2))
    y:board.localPointer.y-height/2
    width:(board.width-columns.spacing)/2;height:Math.max(implicitHeight,Style.space(44))
    text:board.editor.selectedRow ? board.editor.elementTitle(board.editor.selectedRow) : ""
    variant:"soft";bordered:true;iconText:"⠿";enabled:false;opacity:1;Accessible.ignored:true
  }
}
