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
  signal settingRequested(string key,var value)
  signal expandRequested()
  signal calendarRequested()
  signal weatherRequested()
  signal closeRequested()
  readonly property bool limitsCenterOpen:limitsBlock.visible && limitsBlock.centerOpen
  function closeLimits() {if(!limitsCenterOpen) return false;limitsBlock.centerOpen=false;return true}
  readonly property bool showPlayer:!limitsCenterOpen && service !== null && service.hasMedia && (expanded || hovering || alertKind === "media")
  readonly property bool mediaToast:alertKind==="media" && !expanded && !hovering
  property bool historyOpen: false
  onExpandedChanged: if (!expanded) historyOpen = false
  readonly property var rows: service ? (historyOpen && expanded ? service.historyEntries : service.activeEntries) : []
  readonly property var visibleRows: expanded ? rows : (hovering ? rows.slice(0,3) : service && service.latest ? [service.latest] : [])
  readonly property var displayedRows: !expanded && !hovering && service && service.latest ? (service.latest.downloadPath ? [] : [service.latest]) : rows
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
  readonly property var downloads: service && ("downloads" in service) ? service.downloads : []
  readonly property var t3:service && ("t3" in service) ? service.t3 : null
  readonly property bool showT3:!limitsCenterOpen && !!t3 && t3.allowed && t3.connected && t3.rows.length>0 && (expanded || hovering)
  property var notificationIcon:null
  readonly property var toastIcon:alertKind==="t3" ? t3Toast.statusIcon : notificationIcon
  implicitHeight: body.implicitHeight
  MouseArea { anchors.fill: parent; acceptedButtons:Qt.LeftButton | Qt.RightButton; onClicked: mouse => {if(mouse.button===Qt.RightButton) {root.closeRequested();return}if(root.externalFeedback) root.externalFeedback.pulseFrom(root,Qt.point(mouse.x,mouse.y));if(!root.expanded) root.expandRequested()} }
  ColumnLayout {
    id: body
    width: parent.width
    spacing: root.compactNotifications ? Design.gap.tight : Design.gap.section
  T3SessionCard {
    id:t3Toast
    objectName:"t3ActivityToast"
    Layout.fillWidth:true
    visible:root.alertKind==="t3" && !root.expanded && !root.hovering && !!root.service && !!root.service.latestT3
    compactToast:true
    color:"transparent"
    row:root.service && root.service.latestT3 ? root.service.latestT3 : ({id:"",title:"",project:"",status:"idle",requestId:"",request:null,summary:""})
    bridge:root.t3;strings:root.strings;active:visible && root.visible
    feedback:root.externalFeedback
    onExpandRequested:root.expandRequested()
  }
  ColumnLayout {
    Layout.fillWidth:true
    visible:root.showPlayer
    spacing:Design.gap.small
    SectionHeading {
      objectName:"mediaSectionHeading"
      visible:!root.mediaToast
      Layout.fillWidth:true
      title:root.service && root.service.player && /spotify/i.test(root.service.player.identity || "") ? "Spotify" : root.strings.t("media.title")
    }
    MediaCard {
      id: mediaPlayer
      color:root.mediaToast ? "transparent" : Design.surface
      externalFeedback: root.externalFeedback
      objectName: "islandMediaPlayer"
      Layout.fillWidth: true
      service: root.service
      strings: root.strings
      bar: root.bar
      expanded: root.expanded
      active: root.overviewActive
      radialBraille: root.radialBraille
      onExpandRequested: root.expandRequested()
      onCloseRequested:root.closeRequested()
    }
  }

  BatteryOverview {
    id:battery
    objectName:"islandBatteryOverview"
    Layout.fillWidth:true
    visible:!root.limitsCenterOpen && present && (root.expanded || root.hovering)
    active:root.overviewActive && root.visible && (root.expanded || root.hovering)
    strings:root.strings
    externalFeedback:root.externalFeedback
    onExpandRequested:root.expandRequested()
  }
  AgentLimitsOverview {
    id:limitsBlock
    Layout.fillWidth:true
    backend:root.service && ("agentLimits" in root.service) ? root.service.agentLimits : null
    visible:!!backend && backend.allowed && (root.expanded || root.hovering)
    strings:root.strings;expanded:root.expanded;feedback:root.externalFeedback
    onExpandRequested:root.expandRequested()
    onSettingRequested:(key,value)=>root.settingRequested(key,value)
  }
  T3SessionList {
    id:t3Block
    Layout.fillWidth:true
    visible:root.showT3
    bridge:root.t3;strings:root.strings;expanded:root.expanded
    active:root.overviewActive && root.visible && root.showT3
    feedback:root.externalFeedback
    onExpandRequested:root.expandRequested()
  }

  RowLayout {
    Layout.fillWidth: true
    visible: root.expanded && !root.limitsCenterOpen
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
    visible: !root.limitsCenterOpen && root.rows.length > 0 && !root.compactNotifications && (root.expanded || root.hovering || root.alertKind === "notification")
    Item { Layout.fillWidth: true; visible: root.rows.length === 0 }
    PlainText { objectName: "notificationCount"; visible: root.rows.length > 0; Layout.fillWidth: true; text: root.strings.tn("notifications", root.rows.length).arg(Commons.I18n.formatNumber(root.rows.length)); color: Design.secondaryText; typeRole:"caption" }
  }
  Controls.ScrollView {
    id: scroll
    objectName: "notificationsScroll"
    visible: !root.limitsCenterOpen && (root.expanded || (root.hovering && (root.rows.length > 0 || root.downloads.length > 0)) || (!root.hovering && root.alertKind === "notification"))
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(cards.implicitHeight,root.showT3 ? Math.max(Style.space(96),Style.space(root.expanded ? 360 : 330)-t3Block.implicitHeight) : Style.space(root.compactNotifications ? 96 : root.expanded ? 360 : 330))
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
          limit: root.expanded ? 100 : root.hovering ? 3 : 1
          visible: group.positions[0] < limit
          onExpandRequested: root.expandRequested()
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
        objectName:"islandDownloads"
        width:parent.width
        spacing:Design.gap.small
        visible:root.alertKind!=="t3" && ((root.expanded || root.hovering) ? root.downloads.length>0 : !!(root.service && root.service.latest && root.service.latest.downloadPath))
        SectionHeading {width:parent.width;visible:root.expanded || root.hovering;title:root.strings.t("downloads.title")}
        DownloadList {
          width:parent.width
          active:root.overviewActive
          rows:root.expanded || root.hovering ? root.downloads : root.service && root.service.latest && root.service.latest.downloadPath ? [root.service.latest] : []
          service:root.service;strings:root.strings;expanded:root.expanded
        }
      }
      Column {
        objectName: "notificationsEmpty"
        width: parent.width
        visible: root.expanded && root.rows.length === 0 && root.downloads.length === 0
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
    visible: !root.limitsCenterOpen && root.expanded && root.service && root.service.mutedSources.length > 0
    Layout.fillWidth: true
    spacing:Design.gap.tight
    Repeater {
      model: root.service ? root.service.mutedSources : []
      FeedbackButton { radius: Design.controlRadius; required property string modelData; text: "󰂛 " + modelData.replace(/[<>]/g,"") + " ×"; focusable: true; onClicked: root.service.mute(modelData) }
    }
  }
  PlainText { Layout.fillWidth: true; visible: !root.compactNotifications && root.service && root.service.error !== ""; text: root.strings.t("error").arg(root.service ? root.service.error : ""); color: Design.danger; wrapMode: Text.Wrap }
  }
}
