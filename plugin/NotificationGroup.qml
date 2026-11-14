import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Rectangle {
  id: root
  readonly property bool islandSpotlightSurface: !compact
  required property var group
  required property var strings
  required property var service
  property bool expanded: false
  KeyboardNavigation {id:focusWatch;scope:root}
  readonly property bool keyboardFocused:focusWatch.contains(root,focusWatch.focused)
  property alias notificationIcon: sourceIcon
  property bool compact: false
  property real toolsShown:!compact && (hover.hovered || keyboardFocused) ? 1 : 0
  Behavior on toolsShown {NumberAnimation {duration:Preferences.duration(150);easing.type:Easing.OutCubic}}
  property var externalFeedback: null
  property bool radialBraille: true
  property int limit: 3
  readonly property var mergedRows: Model.coalesceNotifications(group.rows)
  function syncRows() {Model.syncKeys(rowItems,mergedRows.map(Model.notificationKey))}
  onMergedRowsChanged: syncRows()
  Component.onCompleted: syncRows()
  ListModel {id:rowItems}
  readonly property var feedback: externalFeedback || brailleFeedback
  signal expandRequested()
  function dismissGroup() {
    var backend=service,keys=group.rows.map(function(row){return row.key})
    keys.forEach(function(key){backend.remove(key)})
  }
  objectName: "notificationGroup-" + group.source
  color: compact ? "transparent" : Design.surface
  border.width: 0
  radius: Design.cardRadius
  readonly property real verticalPadding:compact ? Design.gap.micro : Design.gap.medium
  implicitHeight: content.implicitHeight + 2*verticalPadding
  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mouse => { root.feedback.pulseFrom(root,Qt.point(mouse.x,mouse.y)); root.expandRequested() } }
  HoverHandler { id: hover }
  BrailleFeedback { id: brailleFeedback; surface: root; effect: glow; hover: hover }
  BrailleSpotlight { id: glow; surfaceRoot: root; objectName: "groupSpotlight"; anchors.fill: parent; active: !root.externalFeedback && hover.hovered; pointer: hover.point.position; adaptive: root.radialBraille }
  ColumnLayout {
    id: content
    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    anchors.margins: root.compact ? Design.gap.micro : Design.cardPadding
    anchors.topMargin:root.verticalPadding
    spacing:Design.gap.tight
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight:root.compact ? Design.lineHeight("caption") : Design.inlineControlHeight
      Item {
        id:sourceIcon
        objectName:"notificationSourceIcon"
        Layout.preferredWidth: Style.space(root.compact ? 12 : 16); Layout.preferredHeight: width
        PlainText { anchors.centerIn: parent; text: "󰂚"; font.pixelSize: root.compact ? Style.font.caption : Style.font.body; color: Design.accent; visible: icon.status !== Image.Ready }
        Image { id: icon; anchors.fill: parent; source: root.group.rows.length && root.group.rows[0].appIcon ? Quickshell.iconPath(root.group.rows[0].appIcon,true) : ""; asynchronous: true; fillMode: Image.PreserveAspectFit }
      }
      PlainText { Layout.fillWidth: true; Layout.minimumWidth:0; text: root.group.source; color: Design.accent; typeRole:"caption" }
      PlainText { objectName:"groupTime";visible: root.compact || root.mergedRows.length===1; text: root.group.rows.length ? new Date(root.group.rows[0].ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm") : ""; color: Design.secondaryText; typeRole:"caption" }
      Item {
        visible:root.toolsShown>0
        Layout.preferredWidth:tools.implicitWidth*root.toolsShown
        Layout.minimumWidth:0;Layout.maximumWidth:Layout.preferredWidth
        Layout.preferredHeight:tools.implicitHeight
        clip:true
        RowLayout {id:tools;anchors.right:parent.right;spacing:Design.gap.tight
      ActionButton {
        feedback: root.feedback
        objectName: "groupMute"
        visible: !root.compact
        opacity: hover.hovered || root.keyboardFocused ? 1 : 0
        enabled: hover.hovered || root.keyboardFocused
        iconText: root.service.mutedSources.indexOf(root.group.source) >= 0 ? "󰂚" : "󰂛"
        tooltipText: root.service.mutedSources.indexOf(root.group.source) >= 0 ? root.strings.t("unmute") : root.strings.t("mute")
        horizontalPadding:Design.gap.small; verticalPadding: 0; implicitHeight:Design.inlineControlHeight
        onClicked: root.service.mute(root.group.source)
        Behavior on opacity { NumberAnimation { duration: Preferences.duration(120) } }
      }
      ActionButton {
        objectName: "groupDismiss"
        feedback: root.feedback
        visible: !root.compact
        opacity: hover.hovered || root.keyboardFocused ? 1 : 0
        enabled: hover.hovered || root.keyboardFocused
        iconText: "󰅖"
        tooltipText: root.strings.t("deleteGroup")
        horizontalPadding:Design.gap.small; verticalPadding: 0; implicitHeight:Design.inlineControlHeight
        onClicked: root.dismissGroup()
        Behavior on opacity { NumberAnimation { duration: Preferences.duration(120) } }
      }
        }
      }
    }
    Repeater {
      model: rowItems
      Loader {
        required property string entryKey
        required property int index
        readonly property var modelData: root.mergedRows.find(function(row){return Model.notificationKey(row)===entryKey}) || ({key:"",app:root.group.source,summary:"",body:"",ts:0})
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: item ? item.implicitHeight : 0
        Layout.maximumHeight: item ? item.implicitHeight : 0
        visible: root.group.positions[root.group.rows.findIndex(function(r) { return r.key === modelData.key })] < root.limit
        active: visible
        sourceComponent: NotificationCard {
          row: {
            var members = modelData.members || [modelData]
            var visible = members.filter(function(member) {
              return root.group.positions[root.group.rows.findIndex(function(r) { return r.key === member.key })] < root.limit
            })
            return Model.coalesceNotifications(visible)[0] || modelData
          }
          service: root.service
          strings: root.strings
          expanded: root.expanded
          grouped: true
          compact: root.compact
          separated: index>0 && !root.compact
          individualDismiss: root.mergedRows.length>1
          showTimestamp: root.mergedRows.length>1
          radialBraille: root.radialBraille
          feedback: root.feedback
          onExpandRequested: root.expandRequested()
        }
      }
    }
  }
}
