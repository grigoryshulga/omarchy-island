import QtQuick
import QtQuick.Layouts
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
  readonly property var feedback: externalFeedback || brailleFeedback
  readonly property bool hovered: hover.hovered
  property bool expanded: false
  property bool radialBraille: true
  readonly property var player: service ? service.player : null
  signal expandRequested()
  implicitHeight: body.implicitHeight
  MouseArea { anchors.fill: parent; onClicked: mouse => { root.feedback.pulseFrom(root,Qt.point(mouse.x,mouse.y)); root.expandRequested() } }
  HoverHandler { id: hover }
  BrailleFeedback { id: brailleFeedback; surface: root; effect: glow; hover: hover }
  BrailleSpotlight {
    id: glow
    objectName: "mediaSpotlight"
    anchors.fill: parent
    active: !root.externalFeedback && hover.hovered
    pointer: hover.point.position
    adaptive: root.radialBraille
    artworkUrl: root.player ? root.player.trackArtUrl : ""
  }
  Timer {
    interval: 500
    repeat: true
    running: root.visible && root.expanded && root.player !== null && root.player.isPlaying && root.player.positionSupported
    onTriggered: if (root.player) root.player.positionChanged()
  }
  ColumnLayout {
    id: body
    width: parent.width
    spacing: Style.space(10)
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(12)
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        PlainText { objectName: "mediaTitle"; Layout.fillWidth: true; text: root.player ? root.player.trackTitle || root.strings.t("untitled") : root.strings.t("noMusic"); font.pixelSize: Math.round(Style.font.title*1.25) }
        PlainText { Layout.fillWidth: true; text: root.player ? root.player.trackArtist || root.player.identity : root.strings.t("musicApps"); color: root.player ? Commons.Color.accent : Commons.Color.muted; font.pixelSize: Style.font.bodySmall }
        PlainText { Layout.fillWidth: true; visible: root.expanded && root.player !== null; text: root.player ? root.player.identity : ""; font.pixelSize: Style.font.caption; color: Commons.Color.accent }
      }
      RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: Style.space(2)
        FeedbackButton { feedback: root.feedback; iconText: "󰒮"; tooltipText: root.strings.t("previous"); radius: Math.min(Style.cornerRadius,Style.space(6)); iconSize: Style.font.iconLarge; horizontalPadding: Style.space(6); verticalPadding: Style.space(5); focusable: true; enabled: root.player !== null && root.player.canGoPrevious; onClicked: root.service.media("previous") }
        PlayPauseButton { feedback: root.feedback; objectName: "mediaToggle"; playing: root.player !== null && root.player.isPlaying; tooltipText: root.strings.t("playPause"); enabled: root.player !== null && root.player.canTogglePlaying; onClicked: root.service.media("toggle") }
        FeedbackButton { feedback: root.feedback; iconText: "󰒭"; tooltipText: root.strings.t("next"); radius: Math.min(Style.cornerRadius,Style.space(6)); iconSize: Style.font.iconLarge; horizontalPadding: Style.space(6); verticalPadding: Style.space(5); focusable: true; enabled: root.player !== null && root.player.canGoNext; onClicked: root.service.media("next") }
      }
    }
    Item {
      Layout.fillWidth: true
      property real reveal: root.expanded && root.player !== null ? 1 : 0
      implicitHeight: details.implicitHeight * reveal
      visible: reveal > 0
      clip: true
      Behavior on reveal { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      ColumnLayout {
        id: details
        width: parent.width
        opacity: parent.reveal
        spacing: Style.space(6)
        RowLayout {
          id: timeline
          Layout.fillWidth: true
          spacing: Style.space(4)
          IslandSlider {
            id: seek
            objectName: "mediaSeek"
            Layout.fillWidth: true
            bar: root.bar
            maximum: root.player && root.player.lengthSupported ? Math.max(1,root.player.length) : 1
            value: root.player && root.player.positionSupported ? root.player.position : 0
            enabled: root.player !== null && root.player.canSeek && root.player.lengthSupported && root.player.positionSupported
            step: 1
            onClicked: position => root.feedback.pulseFrom(seek,position)
            onReleased: value => { if (root.player && root.player.canSeek) root.player.position = value }
          }
          VolumePopover {
            id: volumeControl
            feedback: root.feedback
            player: root.player
            strings: root.strings
            bar: root.bar
            availableWidth: timeline.width
          }
        }
        RowLayout {
          Layout.fillWidth: true
          Layout.rightMargin: volumeControl.implicitWidth+timeline.spacing
          PlainText { objectName: "mediaElapsed"; text: Model.time(seek.liveValue); font.pixelSize: Style.font.body; font.bold: true; color: Commons.Color.foreground }
          Item { Layout.fillWidth: true }
          PlainText { objectName: "mediaDuration"; text: Model.time(seek.maximum); font.pixelSize: Style.font.body; font.bold: true; color: Commons.Color.foreground }
        }
        Flow {
          Layout.fillWidth: true
          spacing: Style.space(4)
          Repeater {
            model: root.service ? root.service.players : []
            FeedbackButton {
              feedback: root.feedback
              required property var modelData
              text: Model.plain(modelData.identity).slice(0,40)
              radius: Math.min(Style.cornerRadius,Style.space(6))
              selected: root.player === modelData
              focusable: true
              onClicked: root.service.selectPlayer(modelData.dbusName)
            }
          }
        }
      }
    }
  }
}
