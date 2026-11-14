import QtQuick
import QtQuick.Controls as Controls
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
  property string editKey:""
  property string editKind:"name"
  property string menuKey:""
  property point menuPoint
  readonly property real gridGap:Island.Design.gap.small
  function beginEdit(key,kind) {
    menu.close();selectedKey=key;editKind=kind;editKey=key
    Qt.callLater(function(){
      for(var i=0;i<tiles.count;i++) if(tiles.itemAt(i).modelData.key===key) {
        var field=tiles.itemAt(i).editor
        field.text=kind==="icon" ? (root.layout.labels[key] || {}).icon || "" : root.host.controlTitle(key)
        field.forceActiveFocus();field.selectAll();break
      }
    })
  }
  function saveEdit(text) {
    var key=editKey,kind=editKind
    if(!key) return
    editKey=""
    if(Model.sectionKey(key)) backend.section(key,text,(layout.sections[key] || {}).gap || 0)
    else backend.label(key,kind==="name" ? text : (layout.labels[key] || {}).title || "",kind==="icon" ? text : (layout.labels[key] || {}).icon || "")
    focusTile(key)
  }
  function dismissEditor() {
    if(editKey) {var key=editKey;editKey="";focusTile(key);return true}
    if(menu.opened) {menu.close();return true}
    return false
  }
  function showMenu(key,item) {
    selectedKey=key;menuKey=key
    menuPoint=item.mapToItem(root,0,item.height)
    menu.open()
  }
  function addSection(before) {
    var old=layout.order.slice()
    backend.addSection(before,host.strings.t("controls.section"))
    var added=backend.layout.order.filter(function(key){return old.indexOf(key)<0})
    if(added.length) beginEdit(added[0],"name")
  }
  function setGap(value) {
    backend.section(menuKey,(layout.sections[menuKey] || {}).title || "",value)
  }
  property string selectedKey:"audio"
  property string dragKey:""
  property string dropKey:""
  property point dragPoint
  property string resizeKey:""
  property int previewWidth:2
  property int previewHeight:1
  readonly property var resizePlacement:resizeKey ? Model.tiles(Model.resize(layout,resizeKey,previewWidth,previewHeight)).filter(function(p){return p.key===root.resizeKey})[0] : null
  readonly property bool selectedSection:Model.sectionKey(selectedKey)
  function cancelGesture() {dragKey="";dropKey="";resizeKey=""}
  Connections {
    target:root.host
    function onEditingChanged(){root.cancelGesture();root.editKey="";menu.close()}
  }
  readonly property real rowHeight:Math.max(Island.Design.controlHeight,Style.space(52))
  spacing:root.gridGap
  function focusFirst() {
    selectedKey=placements.length ? placements[0].key : ""
    focusTile(selectedKey)
  }
  function focusTile(key) {
    if(!host.editing && Model.sectionKey(key)) {
      var next=layout.order.slice(layout.order.indexOf(key)+1).filter(function(k){return !Model.sectionKey(k) && root.layout.hidden.indexOf(k)<0})
      key=next.length ? next[0] : ""
    }
    if(!key) {host.forceActiveFocus();return}
    Qt.callLater(function(){for(var i=0;i<tiles.count;i++) if(tiles.itemAt(i).modelData.key===key) {tiles.itemAt(i).tile.forceActiveFocus();break}})
  }
  function resize(key,w,h) {if(backend) backend.resize(key,w,h);focusTile(key)}
  function move(key,delta) {
    var rows=layout.order,at=rows.indexOf(key),target=at+delta
    if(target>=0 && target<rows.length && backend) backend.move("order",key,rows[target])
    focusTile(key)
  }
  function updateDrop(point) {
    dropKey=""
    var distance=Infinity
    for(var i=0;i<tiles.count;i++) {
      var candidate=tiles.itemAt(i)
      var d=Math.pow(point.x-candidate.x-candidate.width/2,2)+Math.pow(point.y-candidate.y-candidate.height/2,2)
      if(d<distance) {distance=d;dropKey=candidate.modelData.key}
    }
  }
  // The popup owns scrolling; only scroll that ancestor during a pointer drag.
  Timer {
    interval:40;repeat:true;running:root.visible && root.dragKey!==""
    onTriggered:{
      var viewport=root.parent
      while(viewport && !("contentY" in viewport && "contentHeight" in viewport)) viewport=viewport.parent
      if(!viewport) return
      var point=grid.mapToItem(viewport,root.dragPoint.x,root.dragPoint.y)
      var edge=Style.space(32),step=point.y<edge ? -Style.space(12) : point.y>viewport.height-edge ? Style.space(12) : 0
      var previous=viewport.contentY
      viewport.contentY=Math.max(0,Math.min(Math.max(0,viewport.contentHeight-viewport.height),previous+step))
      if(viewport.contentY!==previous) {
        root.dragPoint=Qt.point(root.dragPoint.x,root.dragPoint.y+viewport.contentY-previous)
        root.updateDrop(root.dragPoint)
      }
    }
  }
  function finishDrag() {
    var key=dragKey,target=dropKey
    dragKey="";dropKey=""
    if(target && key!==target && backend) backend.move("order",key,target)
    focusTile(key)
  }
  onVisibleChanged:if(!visible) cancelGesture()
  Item {
    id:grid
    objectName:"controlMainGrid"
    Layout.fillWidth:true
    implicitHeight:root.placements.reduce(function(height,p){return Math.max(height,(p.row+p.height)*(root.rowHeight+root.gridGap)-root.gridGap)},0)
    readonly property real unit:(width-root.gridGap*3)/4
    Repeater {
      model:root.host.editing ? Math.ceil(grid.implicitHeight/(root.rowHeight+root.gridGap))*4 : 0
      Item {
        id:cell
        required property int index
        x:(index%4)*(grid.unit+root.gridGap)
        y:Math.floor(index/4)*(root.rowHeight+root.gridGap)
        width:grid.unit;height:root.rowHeight
        visible:!root.placements.some(function(p){return p.section && p.row===Math.floor(cell.index/4)})
        // Quiet registration points show the snap grid without boxing in empty space.
        Repeater {
          model:4
          Rectangle {
            required property int index
            width:Math.max(1,Style.space(2));height:width;radius:width/2
            x:index%2 ? cell.width-width : 0
            y:index<2 ? 0 : cell.height-height
            color:Island.Design.secondaryText;opacity:0.35
          }
        }
      }
    }
    Repeater {
      id:tiles
      model:root.placements
      Item {
        id:entry
        required property var modelData
        property alias tile:tile
        property alias editor:inlineEditor
        readonly property bool quick:Model.quickDefaults.indexOf(modelData.key)>=0
        readonly property bool editing:root.host.editing
        x:(Commons.I18n.rightToLeft ? 4-modelData.column-modelData.width : modelData.column)*(grid.unit+root.gridGap)
        y:modelData.row*(root.rowHeight+root.gridGap)
        width:modelData.width*grid.unit+(modelData.width-1)*root.gridGap
        height:modelData.height*root.rowHeight+(modelData.height-1)*root.gridGap
        Island.ControlTile {
          id:tile
          objectName:entry.quick ? "control"+modelData.key.charAt(0).toUpperCase()+modelData.key.slice(1) : "controlOpen-"+modelData.key
          anchors.fill:parent
          visible:!entry.modelData.section || entry.editing
          effectsActive:root.host.active && !root.host.section
          background:entry.modelData.section ? "transparent" : Island.Design.surface
          compact:entry.quick
          iconOnly:entry.modelData.width===1
          title:root.host.controlTitle(entry.modelData.key)
          glyph:entry.modelData.section ? "" : (root.layout.labels[entry.modelData.key] || {}).icon || ({audio:"󰕾",bluetooth:"󰂯",network:"󰤨",tailscale:"󰖂",monitors:"󰍺",microphone:"󰍭",dnd:"󰂛",nightLight:"󰔎",stayAwake:"",recording:"󰻂",remote:"󰢹"})[entry.modelData.key] || "󰒓"
          drillDown:!entry.quick && !entry.editing
          showLed:entry.quick || !!root.host.controlState && root.host.controlState.available(entry.modelData.key)
          selected:showLed && root.host.enabledState(entry.modelData.key)
          enabled:entry.editing || (entry.modelData.key!=="remote" && (entry.modelData.key!=="microphone" || !!root.host.microphone))
          glyphColor:entry.modelData.key==="recording" && selected ? Island.Design.danger : selected ? Island.Design.accent : Island.Design.text
          feedback:root.host.externalFeedback
          tooltipText:entry.editing ? title+" · "+root.host.strings.t("controls.editHint") : title+(showLed ? " · "+root.host.modeState(selected) : "")
          onClicked: {
            if(entry.editing) {root.showMenu(entry.modelData.key,entry);return}
            if(entry.modelData.section) return
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
            if(event.key===Qt.Key_F2) {root.beginEdit(p.key,"name");event.accepted=true;return}
            if(event.key===Qt.Key_Menu) {root.showMenu(p.key,entry);event.accepted=true;return}
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
        Island.PlainText {
          anchors.fill:parent;verticalAlignment:Text.AlignVCenter
          visible:!!entry.modelData.section && !entry.editing
          text:root.host.controlTitle(entry.modelData.key);typeRole:"section";elide:Text.ElideRight
        }
        Rectangle {anchors.fill:parent;visible:entry.editing;color:"transparent";radius:Island.Design.controlRadius;border.width:1;border.color:root.dropKey===entry.modelData.key || root.selectedKey===entry.modelData.key ? Island.Design.accent : "transparent"}
        MouseArea {
          id:grip
          objectName:"controlDrag-"+entry.modelData.key
          visible:entry.editing
          anchors.fill:parent
          hoverEnabled:true;acceptedButtons:Qt.LeftButton | Qt.RightButton
          preventStealing:true;cursorShape:pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          onPressed:{moved=false;tile.forceActiveFocus();root.selectedKey=entry.modelData.key;origin=mapToItem(grid,mouseX,mouseY)}
          property point origin
          onPositionChanged:mouse=>{
            if(!pressed || pressedButtons!==Qt.LeftButton) return
            var current=mapToItem(grid,mouse.x,mouse.y)
            if(!root.dragKey && Math.abs(current.x-origin.x)+Math.abs(current.y-origin.y)<Style.space(8)) return
            root.dragKey=entry.modelData.key;root.dragPoint=current
            root.updateDrop(current)
          }
          property bool moved:false
          onClicked:mouse=>{
            if(moved) {moved=false;return}
            if(mouse.button===Qt.RightButton) {root.showMenu(entry.modelData.key,entry);return}
            var iconHit=Commons.I18n.rightToLeft ? mouse.x>width-Style.space(44) : mouse.x<Style.space(44)
            if(iconHit && !entry.modelData.section) root.beginEdit(entry.modelData.key,"icon")
          }
          onDoubleClicked:mouse=>{if(mouse.button===Qt.LeftButton) root.beginEdit(entry.modelData.key,"name")}
          onReleased:{moved=root.dragKey!=="";if(moved) root.finishDrag()}
          onCanceled:{root.dragKey="";root.dropKey=""}
        }
        MouseArea {
          objectName:"controlResize-"+entry.modelData.key
          visible:entry.editing && !entry.modelData.section && (root.selectedKey===entry.modelData.key || grip.containsMouse || pressed)
          anchors.right:Commons.I18n.rightToLeft ? undefined : parent.right;anchors.left:Commons.I18n.rightToLeft ? parent.left : undefined;anchors.bottom:parent.bottom
          width:Style.space(24);height:width;preventStealing:true;cursorShape:Qt.SizeFDiagCursor
          property point start
          property int startWidth
          property int startHeight
          Island.PlainText {anchors.centerIn:parent;text:"⌟";typeRole:"caption";color:Island.Design.accent}
          onPressed:mouse=>{start=mapToItem(grid,mouse.x,mouse.y);startWidth=entry.modelData.width;startHeight=entry.modelData.height;root.selectedKey=entry.modelData.key;root.resizeKey=entry.modelData.key;root.previewWidth=startWidth;root.previewHeight=startHeight}
          function updateSize(px,py) {
            var end=mapToItem(grid,px,py)
            root.previewWidth=Model.span(startWidth+(Commons.I18n.rightToLeft ? -1 : 1)*Math.round((end.x-start.x)/(grid.unit+root.gridGap)),4,2)
            root.previewHeight=Model.span(startHeight+Math.round((end.y-start.y)/(root.rowHeight+root.gridGap)),4,1)
          }
          onPositionChanged:mouse=>{if(pressed) updateSize(mouse.x,mouse.y)}
          onReleased:mouse=>{updateSize(mouse.x,mouse.y);var key=root.resizeKey;root.resizeKey="";if(key) root.resize(key,root.previewWidth,root.previewHeight)}
          onCanceled:root.resizeKey=""
        }
        Island.FeedbackButton {
          objectName:"controlMore-"+entry.modelData.key
          visible:entry.editing && root.selectedKey===entry.modelData.key && root.editKey!==entry.modelData.key
          anchors.right:parent.right;anchors.top:parent.top
          width:Style.space(28);height:width;implicitHeight:height
          horizontalPadding:0;verticalPadding:0;iconText:"⋯";focusable:true
          tooltipText:root.host.strings.t("controls.tileActions")
          onClicked:root.showMenu(entry.modelData.key,entry)
        }
        Island.DesignTextField {
          id:inlineEditor
          objectName:"controlEdit-"+entry.modelData.key
          visible:root.editKey===entry.modelData.key
          anchors.verticalCenter:parent.verticalCenter
          height:Math.min(parent.height,implicitHeight)
          x:root.editKind==="icon" ? Island.Design.gap.small : entry.modelData.section || entry.modelData.width===1 ? 0 : Style.space(40)
          width:root.editKind==="icon" ? Math.min(parent.width,Style.space(72)) : Math.max(Style.space(48),parent.width-x)
          maximumLength:root.editKind==="icon" ? 16 : 80
          Accessible.name:root.host.strings.t(root.editKind==="icon" ? "controls.tileIcon" : "controls.tileName")
          onAccepted:root.saveEdit(text)
          onEditingFinished:if(root.editKey===entry.modelData.key) root.saveEdit(text)
          Keys.onEscapePressed:event=>{root.dismissEditor();event.accepted=true}
        }
        Rectangle {
          visible:root.resizeKey===entry.modelData.key
          width:root.previewWidth*grid.unit+(root.previewWidth-1)*root.gridGap
          height:root.previewHeight*root.rowHeight+(root.previewHeight-1)*root.gridGap
          x:root.resizePlacement ? (Commons.I18n.rightToLeft ? 4-root.resizePlacement.column-root.previewWidth : root.resizePlacement.column)*(grid.unit+root.gridGap)-entry.x : 0
          y:root.resizePlacement ? root.resizePlacement.row*(root.rowHeight+root.gridGap)-entry.y : 0
          color:"transparent";border.width:2;border.color:Island.Design.accent;radius:Island.Design.controlRadius;z:10
          Island.PlainText {anchors.centerIn:parent;text:Commons.I18n.formatNumber(root.previewWidth)+" × "+Commons.I18n.formatNumber(root.previewHeight)}
        }
      }
    }
    Rectangle {
      visible:root.dragKey!=="";z:20
      x:Math.max(0,Math.min(grid.width-width,root.dragPoint.x-width/2));y:root.dragPoint.y-height/2
      width:grid.unit*2;height:root.rowHeight
      color:Island.Design.raised;radius:Island.Design.controlRadius;border.width:2;border.color:Island.Design.accent;opacity:0.9
      Island.PlainText {anchors.fill:parent;anchors.margins:root.gridGap;verticalAlignment:Text.AlignVCenter;text:root.host.controlTitle(root.dragKey);elide:Text.ElideRight}
    }
  }
  Controls.Popup {
    id:menu
    parent:root
    x:Math.max(0,Math.min(root.width-width,root.menuPoint.x))
    y:root.menuPoint.y
    width:Math.min(root.width,Style.space(220));padding:Island.Design.gap.small
    focus:true
    closePolicy:Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    onClosed:if(!root.editKey) root.focusTile(root.menuKey)
    background:Rectangle {color:Island.Design.opaqueCanvas;radius:Island.Design.controlRadius;border.width:1;border.color:Island.Design.fieldBorder}
    contentItem:ColumnLayout {
      spacing:0
      Island.FeedbackButton {
        objectName:"controlRename";Layout.fillWidth:true;leftAlign:true
        text:root.host.strings.t("controls.rename");iconText:"✎";focusable:true
        onClicked:root.beginEdit(root.menuKey,"name")
      }
      Island.FeedbackButton {
        visible:!Model.sectionKey(root.menuKey);Layout.fillWidth:true;leftAlign:true
        text:root.host.strings.t("controls.tileIcon");iconText:"◇";focusable:true
        onClicked:root.beginEdit(root.menuKey,"icon")
      }
      RowLayout {
        visible:Model.sectionKey(root.menuKey)
        Island.PlainText {Layout.fillWidth:true;text:root.host.strings.t("controls.spacing");typeRole:"caption"}
        Island.FeedbackButton {objectName:"controlGapLess";iconText:"−";focusable:true;tooltipText:root.host.strings.t("controls.lessSpacing");enabled:((root.layout.sections[root.menuKey] || {}).gap || 0)>0;onClicked:root.setGap((root.layout.sections[root.menuKey] || {}).gap-1)}
        Island.FeedbackButton {objectName:"controlGapMore";iconText:"+";focusable:true;tooltipText:root.host.strings.t("controls.moreSpacing");enabled:((root.layout.sections[root.menuKey] || {}).gap || 0)<4;onClicked:root.setGap(((root.layout.sections[root.menuKey] || {}).gap || 0)+1)}
      }
      Island.FeedbackButton {
        objectName:"controlFavoriteToggle";visible:!Model.sectionKey(root.menuKey);Layout.fillWidth:true;leftAlign:true
        text:root.host.strings.t("controls.favorite");iconText:root.layout.favorites.indexOf(root.menuKey)>=0 ? "★" : "☆";focusable:true
        onClicked:{root.backend.favorite(root.menuKey);menu.close()}
      }
      Island.FeedbackButton {
        objectName:"controlHide";Layout.fillWidth:true;leftAlign:true;focusable:true
        text:root.host.strings.t(Model.sectionKey(root.menuKey) ? "controls.deleteSection" : "overview.hide");iconText:"−"
        onClicked:{var key=root.menuKey;menu.close();if(Model.sectionKey(key)) root.backend.removeSection(key);else root.backend.toggle(key);root.focusFirst()}
      }
      Island.FeedbackButton {
        objectName:"controlLayoutReset";Layout.fillWidth:true;leftAlign:true;focusable:true
        text:root.host.strings.t("controls.resetLayout");iconText:"󰑓"
        onClicked:{menu.close();root.backend.reset();root.focusFirst()}
      }
    }
  }
}
