import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Rectangle {
  id: root
  required property var group
  required property var strings
  required property var service
  property bool expanded: false
  property bool compact: false
  property int overflow: 0
  property bool radialBraille: true
  property int limit: 3
  readonly property var feedback: brailleFeedback
  signal expandRequested()
  objectName: "notificationGroup-" + group.source
  color: compact ? "transparent" : Style.normalFillFor(Commons.Color.foreground,Commons.Color.accent)
  border.width: compact ? 0 : Math.max(1,Style.space(1))
  border.color: Style.hoverFillFor(Commons.Color.foreground,Commons.Color.accent)
  radius: Style.cornerRadius
  implicitHeight: content.implicitHeight + Style.space(compact ? 4 : 20)
  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mouse => { root.feedback.pulseFrom(root,Qt.point(mouse.x,mouse.y)); root.expandRequested() } }
  HoverHandler { id: hover }
  BrailleFeedback { id: brailleFeedback; surface: root; effect: glow; hover: hover }
  BrailleSpotlight { id: glow; objectName: "groupSpotlight"; anchors.fill: parent; active: hover.hovered; pointer: hover.point.position; adaptive: root.radialBraille }
  ColumnLayout {
    id: content
    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    anchors.margins: Style.space(root.compact ? 2 : 10)
    spacing: Style.space(root.compact ? 2 : 8)
    RowLayout {
      Layout.fillWidth: true
      Item {
        Layout.preferredWidth: Style.space(root.compact ? 12 : 16); Layout.preferredHeight: width
        PlainText { anchors.centerIn: parent; text: "󰂚"; font.pixelSize: root.compact ? Style.font.caption : Style.font.body; color: Commons.Color.accent; visible: icon.status !== Image.Ready }
        Image { id: icon; anchors.fill: parent; source: root.group.rows[0].appIcon ? Quickshell.iconPath(root.group.rows[0].appIcon,true) : ""; asynchronous: true; fillMode: Image.PreserveAspectFit }
      }
      PlainText { Layout.fillWidth: true; text: root.group.source; color: Commons.Color.accent; font.pixelSize: Style.font.caption }
      PlainText { visible: !root.compact || root.overflow>0; text: root.compact ? "+"+Commons.I18n.formatNumber(root.overflow) : Commons.I18n.formatNumber(root.group.total); color: Commons.Color.muted; font.pixelSize: Style.font.caption }
      PlainText { visible: root.compact; text: new Date(root.group.rows[0].ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm"); color: Commons.Color.muted; font.pixelSize: Style.font.caption }
      ActionButton {
        feedback: root.feedback
        objectName: "groupMute"
        visible: !root.compact
        opacity: hover.hovered ? 1 : 0
        enabled: hover.hovered
        iconText: root.service.mutedSources.indexOf(root.group.source) >= 0 ? "󰂚" : "󰂛"
        tooltipText: root.service.mutedSources.indexOf(root.group.source) >= 0 ? root.strings.t("unmute") : root.strings.t("mute")
        horizontalPadding: Style.space(5); verticalPadding: Style.space(2)
        onClicked: root.service.mute(root.group.source)
        Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }
      }
    }
    Repeater {
      model: root.group.rows
      Loader {
        required property var modelData
        required property int index
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: item ? item.implicitHeight : 0
        Layout.maximumHeight: item ? item.implicitHeight : 0
        visible: root.group.positions[index] < root.limit
        active: visible
        sourceComponent: NotificationCard {
          row: modelData
          service: root.service
          strings: root.strings
          expanded: root.expanded
          grouped: true
          compact: root.compact
          radialBraille: root.radialBraille
          feedback: root.feedback
          onExpandRequested: root.expandRequested()
        }
      }
    }
  }
}
