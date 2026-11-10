import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "Security.js" as Security

Rectangle {
  id: root
  objectName: "notification-" + row.key
  required property var row
  required property var service
  required property var strings
  property bool expanded: false
  property bool radialBraille: true
  property bool grouped: false
  property bool compact: false
  property bool separated: false
  property bool individualDismiss: true
  property var feedback: brailleFeedback
  property string copied: ""
  signal expandRequested()
  opacity: 0
  Component.onCompleted: opacity = 1
  Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
  color: grouped ? "transparent" : Style.normalFillFor(Commons.Color.foreground,Commons.Color.accent)
  border.width: grouped ? 0 : Math.max(1,Style.space(1))
  border.color: Style.hoverFillFor(Commons.Color.foreground,Commons.Color.accent)
  radius: Style.cornerRadius
  implicitHeight: content.implicitHeight + (grouped ? 0 : Style.space(20)) + (separated ? Style.space(12) : 0)
  PanelSeparator { objectName: "notificationDivider"; anchors.top: parent.top; visible: root.separated }
  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mouse => { root.feedback.pulseFrom(root,Qt.point(mouse.x,mouse.y)); root.service.activate(root.row) } }
  HoverHandler { id: hover }
  BrailleFeedback { id: brailleFeedback; surface: root; effect: glow; hover: hover }
  BrailleSpotlight { id: glow; objectName: "notificationSpotlight"; anchors.fill: parent; active: !root.grouped && root.feedback===brailleFeedback && hover.hovered; pointer: hover.point.position; adaptive: root.radialBraille }
  ColumnLayout {
    id: content
    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    anchors.margins: root.grouped ? 0 : Style.space(10)
    anchors.topMargin: root.separated ? Style.space(12) : root.grouped ? 0 : Style.space(10)
    spacing: Style.space(root.compact ? 2 : 4)
    RowLayout {
      visible: !root.grouped
      Layout.fillWidth: true
      Item {
        visible: !root.grouped
        Layout.preferredWidth: Style.space(18); Layout.preferredHeight: width
        PlainText { anchors.centerIn: parent; text: "󰂚"; color: Commons.Color.accent; visible: appIcon.status !== Image.Ready }
        Image { id: appIcon; anchors.fill: parent; source: root.row.appIcon ? Quickshell.iconPath(root.row.appIcon,true) : ""; asynchronous: true; fillMode: Image.PreserveAspectFit }
      }
      PlainText { visible: !root.grouped; Layout.fillWidth: true; text: Model.source(root.row); color: Commons.Color.accent; font.pixelSize: Style.font.caption }
      Item { visible: root.grouped; Layout.fillWidth: true }
      PlainText { text: new Date(root.row.ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm"); color: Commons.Color.muted; font.pixelSize: Style.font.caption }
      FeedbackButton { feedback: root.feedback; radius: Math.min(Style.cornerRadius,Style.space(4)); visible: root.expanded; opacity: hover.hovered ? 1 : 0; enabled: opacity > 0; iconText: "󰅖"; tooltipText: root.strings.t("delete"); horizontalPadding: Style.space(4); verticalPadding: 0; focusable: true; onClicked: root.service.remove(root.row.key) }
    }
    RowLayout {
      Layout.fillWidth: true
      PlainText { Layout.fillWidth: true; text: root.row.summary; font.pixelSize: root.compact ? Style.font.bodySmall : Style.font.body; wrapMode: Text.Wrap; maximumLineCount: root.expanded ? 8 : 1; elide: Text.ElideRight }
      FeedbackButton { feedback: root.feedback; radius: Math.min(Style.cornerRadius,Style.space(4)); visible: root.grouped && root.expanded && root.individualDismiss; opacity: hover.hovered ? 1 : 0; enabled: opacity > 0; iconText: "󰅖"; tooltipText: root.strings.t("delete"); horizontalPadding: Style.space(3); verticalPadding: 0; focusable: true; onClicked: root.service.remove(root.row.key) }
    }
    PlainText { Layout.fillWidth: true; visible: text !== ""; text: Model.plain(root.row.body); font.pixelSize: Style.font.caption; color: Commons.Color.muted; wrapMode: Text.Wrap; maximumLineCount: root.compact ? 1 : root.expanded ? 1000 : 2; elide: Text.ElideRight }
    Item {
      Layout.fillWidth: true
      property real reveal: !root.compact && hover.hovered ? 1 : 0
      implicitHeight: Math.max(stamp.visible ? stamp.implicitHeight : 0,actions.implicitHeight)
      visible: !root.compact
      clip: true
      Behavior on reveal { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }
      PlainText {
        id: stamp
        objectName: "notificationTime"
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        visible: root.grouped
        text: new Date(root.row.ts*1000).toLocaleTimeString(Qt.locale(Commons.I18n.formatLocale),"HH:mm")
        color: Commons.Color.muted
        font.pixelSize: Style.font.caption
      }
      Flow {
        id: actions
        anchors.right: parent.right
        property real naturalWidth: {
          var total=0, count=0
          for(var i=0;i<children.length;i++) {
            var child=children[i]
            if(child.visible && child.implicitWidth>0) { total+=child.implicitWidth; count++ }
          }
          return total+Math.max(0,count-1)*spacing
        }
        width: Math.max(0,Math.min(parent.width-(stamp.visible ? stamp.implicitWidth+Style.space(10) : 0),naturalWidth))
        opacity: parent.reveal
        enabled: parent.reveal>0
      spacing: Style.space(4)
      Repeater {
        model: String(root.row.codes || "").split(" ").filter(function(s) { return s !== "" })
        ActionButton {
          feedback: root.feedback
          required property string modelData
          objectName: "copyCode-" + modelData
          text: (root.copied === modelData ? "✓ " : "󰆏 ") + modelData
          focusable: true; bordered: true
          onClicked: { root.service.copyCode(root.row,modelData); root.copied = modelData }
        }
      }
      ActionButton {
        feedback: root.feedback
        visible: !!root.row.link
        text: root.strings.t("openLink")
        focusable: true
        onClicked: Security.openExternalUrl(root.row.link)
      }
      Repeater {
        model: root.service.actions(root.row).filter(function(a) { return a.id !== "default" })
        ActionButton {
          feedback: root.feedback
          required property var modelData
          text: Model.plain(modelData.text)
          focusable: true
          onClicked: root.service.invoke(root.row,modelData.id)
        }
      }
      Repeater {
        model: Security.parseExecActions(root.row.execActions) || []
        ActionButton {
          feedback: root.feedback
          required property var modelData
          required property int index
          text: Model.plain(modelData.label)
          focusable: true
          onClicked: root.service.execAction(root.row,index)
        }
      }
      ActionButton {
        feedback: root.feedback
        objectName: "muteSource"
        visible: !root.grouped
        iconText: root.service.mutedSources.indexOf(Model.source(root.row)) >= 0 ? "󰂚" : "󰂛"
        tooltipText: root.service.mutedSources.indexOf(Model.source(root.row)) >= 0 ? root.strings.t("unmute") : root.strings.t("mute")
        focusable: true
        onClicked: root.service.mute(Model.source(root.row))
      }
    }
  }
  }
}
