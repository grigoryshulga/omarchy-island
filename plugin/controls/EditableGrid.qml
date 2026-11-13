import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import ".." as Island
import "Layout.js" as Model

ColumnLayout {
  id:root
  required property var host
  readonly property var backend:host.layoutState
  readonly property var layout:host.controlLayout
  readonly property var placements:Model.tiles(layout)
  property string selectedKey:"audio"
  property string dragKey:""
  property string dropKey:""
  readonly property real rowHeight:Math.max(Island.Design.controlHeight,Style.space(52))
  spacing:Island.Design.gap.small
  function focusTile(key) {
    Qt.callLater(function(){for(var i=0;i<tiles.count;i++) if(tiles.itemAt(i).modelData.key===key) {tiles.itemAt(i).tile.forceActiveFocus();break}})
  }
  function resize(key,w,h) {if(backend) backend.resize(key,w,h);focusTile(key)}
  function move(key,delta) {
    var rows=layout.order,at=rows.indexOf(key),target=at+delta
    if(target>=0 && target<rows.length && backend) backend.move("order",key,rows[target])
    focusTile(key)
  }
  function finishDrag() {
    var key=dragKey,target=dropKey
    dragKey="";dropKey=""
    if(target && key!==target && backend) backend.move("order",key,target)
    focusTile(key)
  }
  onVisibleChanged:if(!visible) {dragKey="";dropKey=""}
  Island.PlainText {Layout.fillWidth:true;visible:root.host.editing;text:root.host.strings.t("controls.editHint");wrapMode:Text.Wrap;typeRole:"caption"}
  Item {
    id:grid
    objectName:"controlMainGrid"
    Layout.fillWidth:true
    implicitHeight:root.placements.reduce(function(height,p){return Math.max(height,(p.row+p.height)*(root.rowHeight+Island.Design.gap.small)-Island.Design.gap.small)},0)
    readonly property real unit:(width-Island.Design.gap.small*3)/4
    Repeater {
      id:tiles
      model:root.placements
      Item {
        id:entry
        required property var modelData
        property alias tile:tile
        readonly property bool quick:Model.quickDefaults.indexOf(modelData.key)>=0
        readonly property bool editing:root.host.editing
        x:(Commons.I18n.rightToLeft ? 4-modelData.column-modelData.width : modelData.column)*(grid.unit+Island.Design.gap.small)
        y:modelData.row*(root.rowHeight+Island.Design.gap.small)
        width:modelData.width*grid.unit+(modelData.width-1)*Island.Design.gap.small
        height:modelData.height*root.rowHeight+(modelData.height-1)*Island.Design.gap.small
        Island.ControlTile {
          id:tile
          objectName:entry.quick ? "control"+modelData.key.charAt(0).toUpperCase()+modelData.key.slice(1) : "controlOpen-"+modelData.key
          anchors.fill:parent
          effectsActive:root.host.active && !root.host.section
          compact:entry.quick
          iconOnly:entry.modelData.width===1
          title:root.host.controlTitle(entry.modelData.key)
          glyph:({audio:"󰕾",bluetooth:"󰂯",network:"󰤨",tailscale:"󰖂",monitors:"󰍺",settings:"󰒓",microphone:"󰍭",dnd:"󰂛",nightLight:"󰔎",stayAwake:"",recording:"󰻂",remote:"󰢹"})[entry.modelData.key] || "󰒓"
          drillDown:!entry.quick && !entry.editing
          showLed:entry.quick || !!root.host.controlState && root.host.controlState.available(entry.modelData.key)
          selected:showLed && root.host.enabledState(entry.modelData.key)
          enabled:entry.editing || (entry.modelData.key!=="remote" && (entry.modelData.key!=="microphone" || !!root.host.microphone))
          glyphColor:entry.modelData.key==="recording" && selected ? Island.Design.danger : selected ? Island.Design.accent : Island.Design.text
          feedback:root.host.externalFeedback
          tooltipText:entry.editing ? title+" · "+root.host.strings.t("controls.editHint") : title+(showLed ? " · "+root.host.modeState(selected) : "")
          onClicked: {
            if(entry.editing) {root.selectedKey=entry.modelData.key;return}
            if(entry.quick) root.host.toggleMode(entry.modelData.key)
            else root.host.openSection(entry.modelData.key)
          }
          onRightClicked: {
            if(entry.editing) return
            if(entry.quick) root.host.toggleMode(entry.modelData.key)
            else if(root.host.controlState) root.host.controlState.toggle(entry.modelData.key)
          }
          onActiveFocusChanged:if(activeFocus) root.selectedKey=entry.modelData.key
          Keys.onPressed:event=>{
            if(!entry.editing) {event.accepted=false;return}
            var p=entry.modelData
            if(event.modifiers & Qt.ShiftModifier) {
              if(event.key===Qt.Key_Left) root.resize(p.key,p.width-1,p.height)
              else if(event.key===Qt.Key_Right) root.resize(p.key,p.width+1,p.height)
              else if(event.key===Qt.Key_Up) root.resize(p.key,p.width,p.height-1)
              else if(event.key===Qt.Key_Down) root.resize(p.key,p.width,p.height+1)
              else {event.accepted=false;return}
            } else if(event.modifiers & Qt.ControlModifier && (event.key===Qt.Key_Left || event.key===Qt.Key_Right)) root.move(p.key,event.key===Qt.Key_Left ? -1 : 1)
            else {event.accepted=false;return}
            event.accepted=true
          }
        }
        Rectangle {anchors.fill:parent;visible:entry.editing;color:"transparent";radius:Island.Design.controlRadius;border.width:1;border.color:root.dropKey===entry.modelData.key || root.selectedKey===entry.modelData.key ? Island.Design.accent : Island.Design.fieldBorder}
        MouseArea {
          id:grip
          objectName:"controlDrag-"+entry.modelData.key
          visible:entry.editing
          anchors.left:parent.left;anchors.top:parent.top
          width:parent.width; height:Math.min(Style.space(14),parent.height/3)
          preventStealing:true;cursorShape:pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          Island.PlainText {anchors.centerIn:parent;text:"⠿";typeRole:"caption";color:Island.Design.secondaryText}
          onPressed:{root.selectedKey=entry.modelData.key;root.dragKey=entry.modelData.key;tile.forceActiveFocus()}
          onPositionChanged:mouse=>{
            if(!pressed) return
            var point=mapToItem(grid,mouse.x,mouse.y);root.dropKey=""
            for(var i=0;i<tiles.count;i++) {var candidate=tiles.itemAt(i);if(point.x>=candidate.x && point.x<candidate.x+candidate.width && point.y>=candidate.y && point.y<candidate.y+candidate.height) {root.dropKey=candidate.modelData.key;break}}
          }
          onReleased:root.finishDrag()
          onCanceled:{root.dragKey="";root.dropKey=""}
        }
        MouseArea {
          objectName:"controlResize-"+entry.modelData.key
          visible:entry.editing
          anchors.right:parent.right;anchors.bottom:parent.bottom
          width:Style.space(24);height:width;preventStealing:true;cursorShape:Qt.SizeFDiagCursor
          property point start
          property int startWidth
          property int startHeight
          Island.PlainText {anchors.centerIn:parent;text:"◢";typeRole:"caption";color:Island.Design.accent}
          onPressed:mouse=>{start=mapToItem(grid,mouse.x,mouse.y);startWidth=entry.modelData.width;startHeight=entry.modelData.height;root.selectedKey=entry.modelData.key}
          onReleased:mouse=>{var end=mapToItem(grid,mouse.x,mouse.y);root.resize(entry.modelData.key,startWidth+Math.round((end.x-start.x)/(grid.unit+Island.Design.gap.small)),startHeight+Math.round((end.y-start.y)/(root.rowHeight+Island.Design.gap.small)))}
        }
      }
    }
  }
  ColumnLayout {
    visible:root.host.editing
    Layout.fillWidth:true
    RowLayout {
      Layout.fillWidth:true
      Island.PlainText {Layout.fillWidth:true;text:root.host.controlTitle(root.selectedKey);elide:Text.ElideRight}
      Island.FeedbackButton {objectName:"controlFavoriteToggle";iconText:root.layout.favorites.indexOf(root.selectedKey)>=0 ? "★" : "☆";tooltipText:root.host.strings.t("controls.favorite");focusable:true;feedback:root.host.externalFeedback;onClicked:root.backend.favorite(root.selectedKey)}
      Island.FeedbackButton {objectName:"controlHide";iconText:"−";tooltipText:root.host.strings.t("overview.hide");enabled:root.selectedKey!=="settings";focusable:true;feedback:root.host.externalFeedback;onClicked:{root.backend.toggle(root.selectedKey);root.selectedKey="settings";root.focusTile("settings")}}
      Island.FeedbackButton {objectName:"controlMoveUp";iconText:"←";tooltipText:root.host.strings.t("controls.moveUp");focusable:true;feedback:root.host.externalFeedback;onClicked:root.move(root.selectedKey,-1)}
      Island.FeedbackButton {objectName:"controlMoveDown";iconText:"→";tooltipText:root.host.strings.t("controls.moveDown");focusable:true;feedback:root.host.externalFeedback;onClicked:root.move(root.selectedKey,1)}
    }
    RowLayout {
      Layout.fillWidth:true
      Island.DesignDropdown {
        objectName:"controlWidth";Layout.fillWidth:true;showLabel:false
        value:String((root.layout.sizes[root.selectedKey] || {width:2}).width)
        options:[{value:"1",label:"¼"},{value:"2",label:"½"},{value:"3",label:"¾"},{value:"4",label:root.host.strings.t("controls.fullRow")}]
        Accessible.name:root.host.strings.t("controls.tileWidth")
        onChanged:value=>root.resize(root.selectedKey,Number(value),(root.layout.sizes[root.selectedKey] || {height:1}).height)
      }
      Island.DesignDropdown {
        objectName:"controlHeight";Layout.fillWidth:true;showLabel:false
        value:String((root.layout.sizes[root.selectedKey] || {height:1}).height)
        options:[1,2,3,4].map(function(n){return {value:String(n),label:root.host.strings.t("controls.tileHeight")+": "+Commons.I18n.formatNumber(n)}})
        Accessible.name:root.host.strings.t("controls.tileHeight")
        onChanged:value=>root.resize(root.selectedKey,(root.layout.sizes[root.selectedKey] || {width:2}).width,Number(value))
      }
      Island.FeedbackButton {objectName:"controlLayoutReset";iconText:"󰑓";tooltipText:root.host.strings.t("controls.resetLayout");focusable:true;feedback:root.host.externalFeedback;onClicked:root.backend.reset()}
    }
  }
}
