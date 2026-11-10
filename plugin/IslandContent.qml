import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root
  required property var service
  required property var strings
  property var bar: null
  property bool expanded: false
  property bool radialBraille: true
  property bool hovering: false
  property string alertKind: ""
  signal expandRequested()
  signal calendarRequested()
  signal closeRequested()
  readonly property bool showPlayer: service !== null && service.hasMedia && (expanded || hovering || alertKind === "media")
  readonly property var rows: service ? service.allEntries : []
  readonly property var visibleRows: expanded ? rows : (hovering ? rows.slice(0,3) : service && service.latest ? [service.latest] : [])
  readonly property var displayedRows: !expanded && !hovering && service && service.latest ? [service.latest] : rows
  implicitHeight: body.implicitHeight
  MouseArea { anchors.fill: parent; onClicked: if (!root.expanded) root.expandRequested() }
  ColumnLayout {
    id: body
    width: parent.width
    spacing: Style.space(12)
  MediaCard {
    objectName: "islandMediaPlayer"
    Layout.fillWidth: true
    visible: root.showPlayer
    service: root.service
    strings: root.strings
    bar: root.bar
    expanded: root.expanded
    radialBraille: root.radialBraille
    onExpandRequested: root.expandRequested()
  }
  PanelSeparator { objectName: "islandMediaSeparator"; Layout.fillWidth: true; visible: root.showPlayer && (root.expanded || root.hovering) }
  RowLayout {
    Layout.fillWidth: true
    visible: root.expanded || root.hovering || root.alertKind === "notification"
    Item { Layout.fillWidth: true; visible: root.rows.length === 0 }
    PlainText { objectName: "notificationCount"; visible: root.rows.length > 0; Layout.fillWidth: true; text: root.strings.tn("notifications", root.rows.length).arg(Commons.I18n.formatNumber(root.rows.length)); color: Commons.Color.muted; font.pixelSize: Style.font.caption }
    Button { objectName: "calendarOpen"; radius: Math.min(Style.cornerRadius,Style.space(6)); visible: root.expanded || root.hovering; iconText: "󰃭"; tooltipText: root.strings.t("calendar.open"); focusable: true; onClicked: root.calendarRequested() }
    Button { radius: Math.min(Style.cornerRadius,Style.space(6)); visible: root.expanded; text: root.service && root.service.doNotDisturb ? "󰂛" : "󰂚"; selected: root.service && root.service.doNotDisturb; tooltipText: root.strings.t("dnd"); focusable: true; verticalPadding: 0; onClicked: root.service.setDoNotDisturb(!root.service.doNotDisturb) }
    Button { radius: Math.min(Style.cornerRadius,Style.space(6)); visible: root.expanded && root.rows.length > 0; text: root.strings.t("clear"); focusable: true; verticalPadding: 0; onClicked: root.service.clear() }
  }
  Controls.ScrollView {
    id: scroll
    visible: root.expanded || root.hovering || root.alertKind === "notification"
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(cards.implicitHeight,Style.space(root.expanded ? 360 : 330))
    clip: true
    contentWidth: availableWidth
    Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
    Column {
      id: cards
      width: scroll.availableWidth
      spacing: Style.space(8)
      Repeater {
        model: Model.previewGroups(root.displayedRows,100)
        NotificationGroup {
          required property var modelData
          width: cards.width
          group: modelData
          strings: root.strings
          service: root.service
          radialBraille: root.radialBraille
          expanded: root.expanded
          limit: root.expanded ? 100 : root.hovering ? 3 : 1
          visible: group.positions[0] < limit
          onExpandRequested: root.expandRequested()
        }
      }
      PlainText {
        width: parent.width
        visible: root.hovering && !root.expanded && root.rows.length > 3
        text: root.strings.tn("more",Math.max(0,root.rows.length-3)).arg(Commons.I18n.formatNumber(Math.max(0,root.rows.length-3)))
        color: Commons.Color.muted
        horizontalAlignment: Text.AlignHCenter
        topPadding: Style.space(4)
        bottomPadding: Style.space(4)
      }
      PlainText { width: parent.width; visible: root.rows.length === 0; text: root.strings.t("empty"); color: Commons.Color.muted; horizontalAlignment: Text.AlignHCenter; height: visible ? Style.space(48) : 0; verticalAlignment: Text.AlignVCenter }
    }
  }
  // The folded cards hint at the depth of the stack without moving its front.
  Column {
    visible: !root.expanded && !root.hovering && root.rows.length > 1 && root.alertKind === "notification"
    Layout.fillWidth: true
    spacing: Style.space(3)
    Repeater {
      model: Math.max(0,Math.min(2,root.rows.length-1))
      Rectangle { required property int index; width: parent.width - Style.space(12)*(index+1); anchors.horizontalCenter: parent.horizontalCenter; height: Style.space(4); color: Commons.Color.accent; opacity: 0.22-index*0.07; radius: Style.cornerRadius }
    }
  }
  Flow {
    visible: root.expanded && root.service && root.service.mutedSources.length > 0
    Layout.fillWidth: true
    spacing: Style.space(4)
    Repeater {
      model: root.service ? root.service.mutedSources : []
      Button { radius: Math.min(Style.cornerRadius,Style.space(6)); required property string modelData; text: "󰂛 " + modelData.replace(/[<>]/g,"") + " ×"; focusable: true; onClicked: root.service.mute(modelData) }
    }
  }
  PlainText { Layout.fillWidth: true; visible: root.service && root.service.error !== ""; text: root.strings.t("error").arg(root.service ? root.service.error : ""); color: Commons.Color.urgent; wrapMode: Text.Wrap }
  }
}
