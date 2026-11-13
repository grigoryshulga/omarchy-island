import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../.." as Island

Island.ModuleView {
  id:root
  available:true
  implicitHeight:button.implicitHeight
  readonly property alias focusTarget:button
  readonly property bool reveal:root.presentation.selected && (hover.hovered || button.activeFocus || gear.activeFocus)
  HoverHandler {id:hover}
  Island.TabButton {
    id:button
    anchors.fill:parent
    objectName:root.presentation.objectName
    label:root.presentation.title
    Accessible.name:label
    tabActive:root.presentation.selected
    feedback:root.presentation.feedback
    fontSize:Island.Design.type.label
    radius:Island.Design.controlRadius
    focusable:true
    trailingInset:gear.visible ? gear.width : 0
    onClicked:root.detailsRequested()
  }
  Island.FeedbackButton {
    id:gear
    objectName:"overviewCustomize"
    visible:root.reveal
    x:Commons.I18n.rightToLeft ? 0 : parent.width-width
    anchors.verticalCenter:parent.verticalCenter
    width:Math.min(parent.width,button.height)
    height:button.height
    horizontalPadding:0;verticalPadding:0
    iconText:"󰒓"
    iconSize:Style.font.icon
    foreground:Island.Design.selectedText
    tooltipText:root.presentation.strings.t("overview.customize")
    focusable:true;compact:true
    feedback:root.presentation.feedback
    onClicked:root.customizeRequested()
  }
}
