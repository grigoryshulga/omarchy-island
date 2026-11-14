import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "HerdrModel.js" as Herdr

ContainerSurface {
  id:root
  required property var row
  required property var strings
  property bool expanded:false
  property bool active:false
  property bool compactOverview:false
  property var feedback:null
  readonly property bool working:row.status==="working"
  readonly property bool needsInput:row.status==="blocked"
  readonly property color statusColor:Design[Herdr.statusRole(row.status)]
  readonly property string statusText:strings.t("herdr.status."+row.status)
  readonly property var statusIcon:working ? workingIcon : stateIcon
  readonly property bool islandSpotlightSurface:true
  readonly property var viewport: {
    var item=parent
    while(item && !("contentY" in item && "contentItem" in item)) item=item.parent
    return item
  }
  readonly property bool inViewport: {
    if(!viewport) return true
    var top=viewport.contentY,position=mapToItem(viewport.contentItem,0,0).y
    return position+height>top && position<top+viewport.height
  }
  signal expandRequested()
  signal overviewDetailsRequested()
  objectName:"herdrSession-"+(row.id || "")
  color:Design.surface
  border.width:0
  radius:Design.cardRadius
  implicitHeight:body.implicitHeight+2*Design.cardPadding
  FeedbackButton {
    id:detailsSurface
    objectName:"herdrDetails"
    anchors.fill:parent
    visible:root.compactOverview || !root.expanded
    tooltipText:root.strings.t(root.expanded ? "herdr.details" : "herdr.expand")
    Accessible.name:root.row.title+" · "+tooltipText
    focusable:root.expanded;feedback:root.feedback
    radius:root.radius;borderSpec:Border.none()
    color:hot ? Design.hover : "transparent"
    onClicked:root.expanded ? root.overviewDetailsRequested() : root.expandRequested()
    Rectangle {
      objectName:"herdrFocusUnderline"
      x:Design.cardPadding;y:parent.height-Design.gap.small
      width:Math.min(Style.space(48),parent.width-2*Design.cardPadding)
      height:Math.max(1,Style.space(1));color:Design.focusRing;visible:detailsSurface.activeFocus
    }
  }
  ColumnLayout {
    id:body
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Design.cardPadding
    spacing:Design.gap.medium
    RowLayout {
      Layout.fillWidth:true;spacing:Design.gap.medium
      Item {
        id:statusSlot
        objectName:"herdrStatusSlot"
        implicitWidth:Math.max(Style.space(20),Style.font.iconLarge)
        implicitHeight:titleRow.height
        Layout.minimumWidth:implicitWidth;Layout.maximumWidth:implicitWidth
        Layout.alignment:Qt.AlignTop
        T3Spinner {
          id:workingIcon;objectName:"herdrSessionSpinner"
          anchors.centerIn:parent;visible:root.working
          active:root.active && root.visible && root.inViewport
          tint:root.statusColor
        }
        PlainText {
          id:stateIcon
          anchors.fill:parent;visible:!root.working
          text:root.needsInput ? "󰋗" : root.row.status==="done" ? "✓" : "·"
          font.pixelSize:Style.font.iconLarge
          Accessible.name:root.statusText
          color:root.statusColor
          horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
        }
      }
      ColumnLayout {
        Layout.fillWidth:true;Layout.minimumWidth:0
        spacing:Design.gap.tight
        RowLayout {
          id:titleRow
          Layout.minimumHeight:root.compactOverview ? Design.controlHeight : 0
          Layout.fillWidth:true;spacing:Design.gap.small
          // Match T3's title target geometry without implying an unsupported action.
          Item {
            Layout.fillWidth:true;Layout.minimumWidth:0
            implicitHeight:titleLabel.implicitHeight+Style.space(4)
            PlainText {
              id:titleLabel;objectName:"herdrSessionTitle"
              anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter
              text:root.row.title;typeRole:"body";font.weight:Font.DemiBold;elide:Text.ElideRight
            }
          }
          PlainText {
            visible:root.compactOverview && root.needsInput
            text:root.statusText;typeRole:"caption";color:root.statusColor
            Layout.maximumWidth:root.width*0.3;elide:Text.ElideRight
          }
        }
        RowLayout {
          visible:!root.compactOverview
          Layout.fillWidth:true;spacing:Design.gap.medium
          ProjectIcon {objectName:"herdrSourceIcon";Layout.alignment:Qt.AlignVCenter}
          PlainText {
            objectName:"herdrSourceLabel"
            Layout.fillWidth:true;Layout.minimumWidth:0
            text:root.row.source+" · "+root.row.pane;typeRole:"caption";color:Design.secondaryText;elide:Text.ElideRight
          }
          PlainText {
            objectName:"herdrStatusLabel"
            Layout.maximumWidth:Math.max(Style.space(80),(root.width-Style.space(48))*0.65)
            text:root.statusText;typeRole:"caption";color:root.statusColor;horizontalAlignment:Text.AlignRight;elide:Text.ElideRight
          }
        }
      }
    }
  }
}
