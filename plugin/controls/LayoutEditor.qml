import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import ".." as Island

FocusScope {
  id:root
  property var backend:null
  required property var strings
  property var feedback:null
  property var catalog:[]
  property var titleFor:function(key){return key}
  property string dragKey:""
  property string dropKey:""
  property string dragGroup:""
  property real dragY:0
  function finishDrag() {
    var key=dragKey,target=dropKey,group=dragGroup
    dragKey="";dropKey=""
    Qt.callLater(function(){
      if(target && root.backend) root.backend.move(group,key,target)
      root.focusRow(key,group)
    })
  }
  function toggleKey(key,group) {
    if(group==="favorites") backend.favorite(key);else backend.toggle(key)
    Qt.callLater(function(){root.focusRow(key,group)})
  }
  function updateDrop(y) {
    dropKey=""
    for(var i=0;i<entries.count;i++) {
      var candidate=entries.itemAt(i)
      if(candidate.modelData.group===dragGroup && y>=candidate.y && y<candidate.y+candidate.height) {dropKey=candidate.modelData.key;break}
    }
  }
  function favoriteKey(key,group) {
    backend.favorite(key)
    Qt.callLater(function(){root.focusRow(key,group,"favorite")})
  }
  function reveal(item) {
    if(!item.activeFocus) return
    var point=item.mapToItem(content,0,0)
    if(point.y<viewport.contentY) viewport.contentY=point.y
    else if(point.y+item.height>viewport.contentY+viewport.height) viewport.contentY=point.y+item.height-viewport.height
  }
  function rows() {
    if(!backend) return []
    return backend.layout.favorites.map(function(key){return {key:key,group:"favorites"}}).concat(backend.layout.main.map(function(key){return {key:key,group:"main"}}),
      backend.layout.quick.map(function(key){return {key:key,group:"quick"}}))
  }
  function moveBy(group,key,delta) {
    var rows=backend.layout[group],index=rows.indexOf(key),target=index+delta
    if(target>=0 && target<rows.length) backend.move(group,key,rows[target])
    Qt.callLater(function(){focusRow(key,group,delta<0 ? "up" : "down")})
  }
  function focusRow(key,group,action) {
    for(var i=0;i<entries.count;i++) if(entries.itemAt(i).modelData.key===key && (!group || entries.itemAt(i).modelData.group===group)) {
      var row=entries.itemAt(i)
      var button=action==="up" ? row.upButton : action==="down" ? row.downButton : action==="favorite" ? row.favoriteButton : row.focusButton
      if(!button.enabled) button=row.upButton.enabled ? row.upButton : row.downButton
      button.forceActiveFocus()
      viewport.contentY=Math.max(0,Math.min(row.y,viewport.contentHeight-viewport.height));break
    }
  }
  Timer {
    interval:40;repeat:true;running:root.visible && root.dragKey!=="" && root.dropKey!==""
    onTriggered:{
      var step=root.dragY<32 ? -12 : root.dragY>viewport.height-32 ? 12 : 0
      viewport.contentY=Math.max(0,Math.min(Math.max(0,viewport.contentHeight-viewport.height),viewport.contentY+step))
      if(step) root.updateDrop(viewport.contentY+root.dragY)
    }
  }
  onVisibleChanged:if(!visible) {dragKey="";dropKey=""}
  Flickable {
    id:viewport
    objectName:"controlLayoutViewport"
    anchors.fill:parent;clip:true
    contentWidth:width;contentHeight:content.implicitHeight
    boundsBehavior:Flickable.StopAtBounds
    Controls.ScrollBar.vertical:Controls.ScrollBar {}
    ColumnLayout {
      id:content;width:viewport.width;spacing:Island.Design.gap.small
      Island.PlainText {Layout.fillWidth:true;text:root.strings.t("controls.customizeHint");wrapMode:Text.Wrap;typeRole:"caption"}
      Island.PlainText {Layout.fillWidth:true;visible:!!root.backend && !!root.backend.error;text:root.strings.t("controls.unavailable");color:Island.Design.danger;wrapMode:Text.Wrap}
      Repeater {
        id:entries
        model:root.rows()
        ColumnLayout {
          id:entry
          required property var modelData
          required property int index
          property alias focusButton:toggle
          property alias upButton:up
          property alias downButton:down
          property alias favoriteButton:favorite
          Layout.fillWidth:true;spacing:Island.Design.gap.tight
          Island.PlainText {
            visible:entry.index===0 || entry.modelData.group!==root.rows()[entry.index-1].group
            text:root.strings.t(entry.modelData.group==="favorites" ? "controls.favorites" : entry.modelData.group==="main" ? "controls.panels" : "controls.quick")
            typeRole:"section"
          }
          RowLayout {
            id:row
            Layout.fillWidth:true;spacing:Island.Design.gap.tight
            Item {
              Layout.preferredWidth:Island.Design.controlHeight
              Layout.preferredHeight:Island.Design.controlHeight
              Island.PlainText {anchors.centerIn:parent;text:"⠿";color:root.dropKey===entry.modelData.key ? Island.Design.accent : Island.Design.secondaryText}
              MouseArea {
                id:grip
                objectName:(entry.modelData.group==="favorites" ? "controlFavoriteDrag-" : "controlDrag-")+entry.modelData.key
                anchors.fill:parent;preventStealing:true
                cursorShape:pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onPressed:{root.dragY=mapToItem(viewport,0,0).y;root.dragKey=entry.modelData.key;root.dragGroup=entry.modelData.group;root.dropKey=""}
                onPositionChanged:mouse=>{
                  if(!pressed) return
                  root.dragY=mapToItem(viewport,mouse.x,mouse.y).y
                  root.updateDrop(mapToItem(content,mouse.x,mouse.y).y)
                }
                onReleased:root.finishDrag()
                onCanceled:{root.dragKey="";root.dropKey=""}
              }
            }
            Island.FeedbackButton {
              id:toggle
              objectName:(entry.modelData.group==="favorites" ? "controlFavoriteRemove-" : "controlVisibility-")+entry.modelData.key
              Layout.fillWidth:true;leftAlign:true;focusable:true;feedback:root.feedback
              enabled:!!root.backend && root.backend.ready && (entry.modelData.group==="favorites" || entry.modelData.key!=="settings")
              text:root.titleFor(entry.modelData.key)
              selected:entry.modelData.group==="favorites" || root.backend && root.backend.layout.hidden.indexOf(entry.modelData.key)<0
              iconText:selected ? "󰄲" : "󰄱"
              onActiveFocusChanged:root.reveal(this)
              onClicked:root.toggleKey(entry.modelData.key,entry.modelData.group)
            }
            Island.FeedbackButton {
              id:favorite
              objectName:"controlFavoriteToggle-"+entry.modelData.key
              visible:entry.modelData.group!=="favorites"
              iconText:selected ? "★" : "☆";tooltipText:root.strings.t("controls.favorite")
              focusable:true;feedback:root.feedback
              enabled:!!root.backend && root.backend.ready
              selected:!!root.backend && root.backend.layout.favorites.indexOf(entry.modelData.key)>=0
              onActiveFocusChanged:root.reveal(this)
              onClicked:root.favoriteKey(entry.modelData.key,entry.modelData.group)
            }
            Island.FeedbackButton {
              id:up
              objectName:(entry.modelData.group==="favorites" ? "controlFavoriteUp-" : "controlMoveUp-")+entry.modelData.key
              iconText:"↑";tooltipText:root.strings.t("controls.moveUp");focusable:true;feedback:root.feedback
              enabled:!!root.backend && root.backend.ready && root.backend.layout[entry.modelData.group].indexOf(entry.modelData.key)>0
              onActiveFocusChanged:root.reveal(this)
              onClicked:root.moveBy(entry.modelData.group,entry.modelData.key,-1)
            }
            Island.FeedbackButton {
              id:down
              objectName:(entry.modelData.group==="favorites" ? "controlFavoriteDown-" : "controlMoveDown-")+entry.modelData.key
              iconText:"↓";tooltipText:root.strings.t("controls.moveDown");focusable:true;feedback:root.feedback
              enabled:!!root.backend && root.backend.ready && root.backend.layout[entry.modelData.group].indexOf(entry.modelData.key)<root.backend.layout[entry.modelData.group].length-1
              onActiveFocusChanged:root.reveal(this)
              onClicked:root.moveBy(entry.modelData.group,entry.modelData.key,1)
            }
          }
          Rectangle {Layout.fillWidth:true;implicitHeight:1;color:Island.Design.accent;opacity:root.dropKey===entry.modelData.key ? 1 : 0}
        }
      }
      Island.PlainText {text:root.strings.t("controls.plugins");typeRole:"section"}
      Island.PlainText {Layout.fillWidth:true;text:root.strings.t("controls.pluginsHint");wrapMode:Text.Wrap;typeRole:"caption"}
      Repeater {
        model:root.catalog.filter(function(row){return !root.backend || root.backend.layout.main.indexOf(row.key)<0})
        Island.FeedbackButton {
          required property var modelData
          objectName:"controlAdd-"+modelData.key
          Layout.fillWidth:true;text:modelData.name;iconText:"+";focusable:true;feedback:root.feedback
          enabled:!!root.backend && root.backend.ready
          onActiveFocusChanged:root.reveal(this)
          onClicked:root.backend.add(modelData.key)
        }
      }
      Island.FeedbackButton {
        objectName:"controlLayoutReset"
        text:root.strings.t("controls.resetLayout");focusable:true;feedback:root.feedback
        enabled:!!root.backend && root.backend.ready
        onActiveFocusChanged:root.reveal(this)
        onClicked:root.backend.reset()
      }
    }
  }
}
