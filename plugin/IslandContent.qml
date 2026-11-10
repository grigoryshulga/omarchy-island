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
  property var externalFeedback: null
  readonly property bool musicHovered: mediaPlayer.visible && mediaPlayer.hovered
  property bool overviewActive: true
  property bool expanded: false
  property bool radialBraille: true
  property bool hovering: false
  property string alertKind: ""
  property var weather: null
  property bool compactNotifications: !expanded && !hovering && alertKind==="notification"
  signal expandRequested()
  signal calendarRequested()
  signal weatherRequested()
  signal closeRequested()
  readonly property bool showPlayer: service !== null && service.hasMedia && (expanded || hovering || alertKind === "media")
  property bool historyOpen: false
  onExpandedChanged: if (!expanded) historyOpen = false
  readonly property var rows: service ? (historyOpen && expanded ? service.historyEntries : service.activeEntries) : []
  readonly property var visibleRows: expanded ? rows : (hovering ? rows.slice(0,3) : service && service.latest ? [service.latest] : [])
  readonly property var displayedRows: !expanded && !hovering && service && service.latest ? (service.latest.downloadPath ? [] : [service.latest]) : rows
  readonly property var downloads: service && ("downloads" in service) ? service.downloads : []
  implicitHeight: body.implicitHeight
  MouseArea { anchors.fill: parent; onClicked: mouse => {if(root.externalFeedback) root.externalFeedback.pulseFrom(root,Qt.point(mouse.x,mouse.y));if(!root.expanded) root.expandRequested()} }
  ColumnLayout {
    id: body
    width: parent.width
    spacing: Style.space(root.compactNotifications ? 4 : 12)
  MediaCard {
    id: mediaPlayer
    externalFeedback: root.externalFeedback
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
  BatteryOverview {
    id:battery
    objectName:"islandBatteryOverview"
    Layout.fillWidth:true
    visible:present && (root.expanded || root.hovering)
    active:root.overviewActive && root.visible && (root.expanded || root.hovering)
    strings:root.strings
    externalFeedback:root.externalFeedback
    onExpandRequested:root.expandRequested()
  }
  RowLayout {
    Layout.fillWidth: true
    visible: root.expanded
    Button {
      objectName: "notificationsActive"
      text: root.strings.t("notifications.active")
      selected: !root.historyOpen
      focusable: true
      onClicked: root.historyOpen = false
    }
    Button {
      objectName: "notificationsHistory"
      text: root.strings.t("notifications.history")
      selected: root.historyOpen
      focusable: true
      onClicked: root.historyOpen = true
    }
    Item { Layout.fillWidth: true }
    Button { objectName: "notificationsClear"; radius: Math.min(Style.cornerRadius,Style.space(6)); visible: root.expanded && root.rows.length > 0; text: root.strings.t("clear"); focusable: true; verticalPadding: 0; onClicked: root.historyOpen ? root.service.clearHistory() : root.service.clear() }
    Button { objectName: "notificationsDnd"; radius: Math.min(Style.cornerRadius,Style.space(6)); visible: root.expanded; text: root.service && root.service.doNotDisturb ? "󰂛" : "󰂚"; selected: root.service && root.service.doNotDisturb; tooltipText: root.strings.t("dnd"); focusable: true; verticalPadding: 0; onClicked: root.service.setDoNotDisturb(!root.service.doNotDisturb) }
  }
  RowLayout {
    Layout.fillWidth: true
    visible: !root.compactNotifications && (root.expanded || root.hovering || root.alertKind === "notification")
    Item { Layout.fillWidth: true; visible: root.rows.length === 0 }
    PlainText { objectName: "notificationCount"; visible: root.rows.length > 0; Layout.fillWidth: true; text: root.strings.tn("notifications", root.rows.length).arg(Commons.I18n.formatNumber(root.rows.length)); color: Commons.Color.muted; font.pixelSize: Style.font.caption }
  }
  Controls.ScrollView {
    id: scroll
    visible: root.expanded || root.hovering || root.alertKind === "notification"
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(cards.implicitHeight,Style.space(root.compactNotifications ? 96 : root.expanded ? 360 : 330))
    clip: true
    contentWidth: availableWidth
    Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
    Column {
      id: cards
      width: scroll.availableWidth
      spacing: Style.space(root.compactNotifications ? 4 : 8)
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
          compact: root.compactNotifications
          externalFeedback: root.externalFeedback
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
      Column {
        objectName:"islandDownloads"
        width:parent.width
        spacing:Style.space(6)
        visible:(root.expanded || root.hovering) ? root.downloads.length>0 : !!(root.service && root.service.latest && root.service.latest.downloadPath)
        PlainText {visible:root.expanded || root.hovering;text:root.strings.t("downloads.title");color:Commons.Color.muted;font.pixelSize:Style.font.caption}
        DownloadList {
          width:parent.width
          rows:root.expanded || root.hovering ? root.downloads : root.service && root.service.latest && root.service.latest.downloadPath ? [root.service.latest] : []
          service:root.service;strings:root.strings;expanded:root.expanded
        }
      }
      Column {
        objectName: "notificationsEmpty"
        width: parent.width
        visible: root.rows.length === 0 && root.downloads.length === 0 && !(root.service && root.service.latest && root.service.latest.downloadPath && !root.expanded && !root.hovering)
        spacing: Style.space(4)
        BrailleClap {
          objectName: "notificationsEmptyClap"
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.min(parent.width,Style.space(220))
          height: Style.space(150)
          active: root.overviewActive && root.visible && (root.expanded || root.hovering)
        }
        PlainText {
          width: parent.width
          text: root.strings.t(root.historyOpen ? "notifications.historyEmpty" : "empty")
          color: Commons.Color.muted
          horizontalAlignment: Text.AlignHCenter
          height: Style.space(32)
          verticalAlignment: Text.AlignVCenter
        }
      }
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
  PlainText { Layout.fillWidth: true; visible: !root.compactNotifications && root.service && root.service.error !== ""; text: root.strings.t("error").arg(root.service ? root.service.error : ""); color: Commons.Color.urgent; wrapMode: Text.Wrap }
  }
}
