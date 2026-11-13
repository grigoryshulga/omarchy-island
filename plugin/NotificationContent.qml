import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

ColumnLayout {
  id:root
  objectName:"notificationContent"
  required property var service
  required property var strings
  property bool expanded:false
  property bool hovering:false
  property bool detailOpen:false
  readonly property string detailPage:detailOpen ? "notifications" : ""
  property string alertKind:""
  property bool radialBraille:true
  property var externalFeedback:null
  property real pageHeight:520
  readonly property bool compactNotifications:!expanded && !hovering && alertKind==="notification"
  property bool historyOpen:false
  property var notificationIcon:null
  signal expandRequested()
  signal detailsRequested()
  onExpandedChanged:if(!expanded) historyOpen=false
  onDetailOpenChanged:if(!detailOpen) historyOpen=false
  readonly property var rows: service ? (historyOpen && expanded ? service.historyEntries : service.activeEntries) : []
  readonly property var displayedRows: !expanded && !hovering && service && service.latest ? (service.latest.downloadPath ? [] : [service.latest]) : rows
  readonly property int notificationLimit:expanded ? (detailPage==="notifications" ? 100 : 3) : hovering ? 3 : 1
  readonly property var groups: Model.previewGroups(displayedRows,100)
  function syncGroups() {
    Model.syncKeys(groupItems,groups.map(function(group){return group.source}))
    Qt.callLater(updateNotificationIcon)
  }
  function updateNotificationIcon() {
    var item=notificationGroups.itemAt(0)
    notificationIcon=item ? item.notificationIcon : null
  }
  onGroupsChanged: syncGroups()
  Component.onCompleted: syncGroups()
  ListModel {id:groupItems}
  RowLayout {
    Layout.fillWidth:true
    visible:root.expanded && !root.detailOpen
    SectionHeading {Layout.fillWidth:true;title:root.strings.t("notifications.active");detail:Commons.I18n.formatNumber(root.rows.length)}
    FeedbackButton {objectName:"overviewDnd";iconText:root.service && root.service.doNotDisturb ? "󰂛" : "󰂚";selected:root.service && root.service.doNotDisturb;tooltipText:root.strings.t("dnd");compact:true;focusable:true;onClicked:root.service.setDoNotDisturb(!root.service.doNotDisturb)}
    FeedbackButton {
      objectName:"notificationsOpenDetails"
      iconText:Commons.I18n.rightToLeft ? "󰁍" : "󰁔"
      iconSize:Style.font.iconLarge
      implicitWidth:Design.compactControlHeight;implicitHeight:Design.compactControlHeight
      horizontalPadding:0;verticalPadding:0
      tooltipText:root.strings.t("notifications.active")
      compact:true;focusable:true;feedback:root.externalFeedback
      onClicked:root.detailsRequested()
    }
  }
  RowLayout {
    Layout.fillWidth: true
    visible: root.expanded && root.detailPage==="notifications"
    FeedbackButton {
      objectName: "notificationsActive"
      text: root.strings.t("notifications.active")
      selected: !root.historyOpen
      focusable: true
      onClicked: root.historyOpen = false
    }
    FeedbackButton {
      objectName: "notificationsHistory"
      text: root.strings.t("notifications.history")
      selected: root.historyOpen
      focusable: true
      onClicked: root.historyOpen = true
    }
    Item { Layout.fillWidth: true }
    FeedbackButton { objectName: "notificationsClear"; radius: Design.controlRadius; visible: root.expanded && root.rows.length > 0; text: root.strings.t("clear"); focusable: true; verticalPadding: 0; onClicked: root.historyOpen ? root.service.clearHistory() : root.service.clear() }
    FeedbackButton { objectName: "notificationsDnd"; radius: Design.controlRadius; visible: root.expanded; text: root.service && root.service.doNotDisturb ? "󰂛" : "󰂚"; selected: root.service && root.service.doNotDisturb; tooltipText: root.strings.t("dnd"); focusable: true; verticalPadding: 0; onClicked: root.service.setDoNotDisturb(!root.service.doNotDisturb) }
  }
  RowLayout {
    Layout.fillWidth: true
    visible: root.detailPage==="notifications" && root.rows.length > 0 && !root.compactNotifications && (root.expanded || root.hovering || root.alertKind === "notification")
    Item { Layout.fillWidth: true; visible: root.rows.length === 0 }
    PlainText { objectName: "notificationCount"; visible: root.rows.length > 0; Layout.fillWidth: true; text: root.strings.tn("notifications", root.rows.length).arg(Commons.I18n.formatNumber(root.rows.length)); color: Design.secondaryText; typeRole:"caption" }
  }
  Controls.ScrollView {
    id: scroll
    objectName: "notificationsScroll"
    visible: (!root.detailOpen || root.detailPage==="notifications") && (root.expanded || (root.hovering && (root.rows.length > 0)) || (!root.hovering && root.alertKind === "notification"))
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(cards.implicitHeight,(root.detailPage==="notifications" ? Math.max(Style.space(96),root.pageHeight-Style.space(180)) : Style.space(root.compactNotifications ? 96 : root.expanded ? 220 : 330)))
    clip: true
    contentWidth: availableWidth
    Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
    Column {
      id: cards
      width: scroll.availableWidth
      spacing: Style.space(root.compactNotifications ? 4 : 8)
      Repeater {
        id:notificationGroups
        model: groupItems
        NotificationGroup {
          required property string entryKey
          width: cards.width
          group: root.groups.find(function(group){return group.source===entryKey}) || ({source:entryKey,rows:[],positions:[],total:0})
          strings: root.strings
          service: root.service
          radialBraille: root.radialBraille
          expanded: root.expanded
          compact: root.compactNotifications
          externalFeedback: root.externalFeedback
          limit: root.notificationLimit
          visible: group.positions[0] < limit
          onExpandRequested: root.expanded ? root.detailsRequested() : root.expandRequested()
        }
      }
      PlainText {
        width: parent.width
        visible: root.hovering && !root.expanded && root.rows.length > 3
        text: root.strings.tn("more",Math.max(0,root.rows.length-3)).arg(Commons.I18n.formatNumber(Math.max(0,root.rows.length-3)))
        color: Design.secondaryText
        horizontalAlignment: Text.AlignHCenter
        topPadding: Style.space(4)
        bottomPadding: Style.space(4)
      }
      Column {
        objectName: "notificationsEmpty"
        width: parent.width
        visible: root.expanded && root.rows.length === 0
        spacing:Design.gap.tight
        PlainText {
          width: parent.width
          text: root.strings.t(root.historyOpen ? "notifications.historyEmpty" : "empty")
          color: Design.secondaryText
          horizontalAlignment: Text.AlignHCenter
          height: Style.space(32)
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }
  Flow {
    visible: root.detailPage==="notifications" && root.expanded && root.service && root.service.mutedSources.length > 0
    Layout.fillWidth: true
    spacing:Design.gap.tight
    Repeater {
      model: root.service ? root.service.mutedSources : []
      FeedbackButton { radius: Design.controlRadius; required property string modelData; text: "󰂛 " + modelData.replace(/[<>]/g,"") + " ×"; focusable: true; onClicked: root.service.mute(modelData) }
    }
  }
}
