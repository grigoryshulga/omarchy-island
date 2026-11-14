import QtQuick
import QtQuick.Layouts
import qs.Commons
import "OverviewModel.mjs" as Overview

Rectangle {
  id:root
  required property string entryKey
  required property var definition
  required property var config
  required property var strings
  required property var controller
  property var feedback:null
  property Item viewItem:null
  property bool available:false
  property bool editing:false
  readonly property alias contentItem:preview
  readonly property alias handleItem:handle
  readonly property string title:definition.title || strings.t(definition.titleKey)
  readonly property bool dragged:controller.dragKey===entryKey
  readonly property real padding:editing ? Design.gap.small : 0
  signal changed(var patch)
  signal stepped(int delta)
  color:editing ? (dragged ? Design.opaqueCanvas : Design.surface) : "transparent"
  radius:Design.cardRadius
  border.width:editing && (dragged || handle.activeFocus) ? Math.max(1,Style.space(1)) : 0
  border.color:Design.accent
  z:dragged ? 10 : 0
  transform:Translate {y:root.dragged ? root.controller.offsetY : 0}
  implicitHeight:contents.implicitHeight+2*padding
  ColumnLayout {
    id:contents
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:root.padding
    spacing:root.editing ? Design.gap.small : 0
    RowLayout {
      visible:root.editing
      Layout.fillWidth:true;spacing:Design.gap.tight
      FeedbackButton {
        id:handle;objectName:"overviewDrag-"+root.entryKey
        Layout.fillWidth:true;Layout.minimumWidth:0
        text:root.title;iconText:"⠿";leftAlign:true;horizontalPadding:0;compact:true
        fontSize:Design.type.caption
        tooltipText:root.strings.t("overview.reorder").arg(root.title)
        Accessible.name:tooltipText
        focusable:true;feedback:root.feedback
        // The module frame already indicates focus for this drag handle.
        borderSpec:Border.none()
        hasCursor:handleDrag.containsMouse
        Keys.onPressed:event=>{
          if(event.modifiers & Qt.ControlModifier && (event.key===Qt.Key_Up || event.key===Qt.Key_Down)) {
            root.stepped(event.key===Qt.Key_Up ? -1 : 1);event.accepted=true
          }
        }
        MoveArea {id:handleDrag;anchors.fill:parent}
      }
      DesignDropdown {
        objectName:"overviewSize-"+root.entryKey
        Layout.preferredWidth:Math.min(Style.space(128),root.width*0.35)
        visible:Overview.supported(root.definition).length>1
        showLabel:false;rowHeight:Design.compactControlHeight
        value:root.config.size
        options:Overview.supported(root.definition).map(function(size){return {value:size,label:root.strings.t("overview.size."+size)}})
        onChanged:value=>root.changed({size:value})
      }
      FeedbackButton {
        objectName:"overviewVisible-"+root.entryKey
        iconText:root.config.visible ? "󰈈" : "󰈉"
        tooltipText:root.strings.t(root.config.visible ? "overview.hide" : "overview.show")
        compact:true;focusable:true;feedback:root.feedback
        horizontalPadding:Design.gap.small;iconSize:Design.type.iconLarge
        onClicked:root.changed({visible:!root.config.visible})
      }
    }
    Item {
      id:preview
      Layout.fillWidth:true
      visible:!root.editing || root.config.visible
      implicitHeight:root.available && root.viewItem ? root.viewItem.implicitHeight : root.editing ? Design.controlHeight : 0
      PlainText {
        visible:root.editing && !root.available
        anchors.fill:parent;verticalAlignment:Text.AlignVCenter
        text:root.strings.t("overview.noData");typeRole:"caption";color:Design.secondaryText
      }
      MoveArea {
        objectName:"overviewModuleDrag-"+root.entryKey
        anchors.fill:parent;visible:root.editing;z:100
      }
    }
  }
  component MoveArea:MouseArea {
    property point pressPoint:Qt.point(0,0)
    property bool started:false
    anchors.fill:parent
    hoverEnabled:true;preventStealing:true
    cursorShape:pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    onPressed:mouse=>{started=false;handle.forceActiveFocus();pressPoint=mapToItem(root.controller.viewport,mouse.x,mouse.y)}
    onPositionChanged:mouse=>{
      if(!pressed) return
      var point=mapToItem(root.controller.viewport,mouse.x,mouse.y)
      if(!started && Math.abs(point.y-pressPoint.y)>=Qt.styleHints.startDragDistance) {
        started=true;root.controller.begin(root.entryKey,pressPoint)
      }
      root.controller.update(point)
    }
    onReleased:root.controller.finish()
    onCanceled:root.controller.cancel()
  }
}
