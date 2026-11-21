import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root
  readonly property bool islandSpotlightSurface: true
  required property var service
  required property var strings
  property var bar: null
  property var externalFeedback: null
  readonly property var feedback: externalFeedback || brailleFeedback
  readonly property bool hovered: hover.hovered
  property bool expanded: false
  property bool toast: false
  property bool compactOverview: false
  property string overviewSize:"standard"
  property bool active: true
  property bool radialBraille: true
  readonly property var player: service ? service.player : null
  readonly property bool hasTimeline: !!player && player.positionSupported && player.lengthSupported && isFinite(player.length) && player.length > 0
  readonly property bool showTimeline: hasTimeline && (!toast || player.canSeek)
  readonly property bool hasVolume: !!player && player.volumeSupported
  signal expandRequested()
  signal closeRequested()
  implicitHeight: body.implicitHeight
  MouseArea { anchors.fill: parent; acceptedButtons:Qt.LeftButton | Qt.RightButton; onClicked: mouse => {if(mouse.button===Qt.RightButton) {root.closeRequested();return} root.feedback.pulseFrom(root,Qt.point(mouse.x,mouse.y)); if(!root.expanded) root.expandRequested() } }
  HoverHandler { id: hover }
  BrailleFeedback { id: brailleFeedback; surface: root; effect: glow; hover: hover }
  BrailleSpotlight {
    id: glow
    surfaceRoot: root
    objectName: "mediaSpotlight"
    anchors.fill: parent
    active: !root.externalFeedback && hover.hovered
    pointer: hover.point.position
    adaptive: root.radialBraille
    artworkUrl: Preferences.get("musicVisualizationBackground")==="artwork" && root.player ? root.player.trackArtUrl : ""
  }
  Timer {
    interval: 500
    repeat: true
    running: root.active && root.visible && (root.expanded || root.toast) && root.showTimeline && root.player.isPlaying
    onTriggered: if (root.player) root.player.positionChanged()
  }
  ColumnLayout {
    id: body
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    spacing:Design.gap.medium
    RowLayout {
      Layout.fillWidth: true
      spacing:Design.gap.medium
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing:Design.gap.tight
        PlainText { objectName: "mediaTitle"; Layout.fillWidth: true; Layout.minimumWidth: 0; text: root.player ? root.player.trackTitle || root.strings.t("untitled") : root.strings.t("noMusic"); typeRole: "section" }
        PlainText { visible:root.overviewSize!=="minimal"; Layout.fillWidth: true; Layout.minimumWidth: 0; text: root.player ? root.player.trackArtist || root.player.identity : root.strings.t("musicApps"); color: root.player ? Design.accent : Design.secondaryText; typeRole:"caption" }
      }
      RowLayout {
        objectName:"mediaTransport"
        Layout.alignment: Qt.AlignVCenter
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        spacing:Design.gap.micro
        FeedbackButton { feedback: root.feedback; iconText: "󰒮"; tooltipText: root.strings.t("previous"); radius: Design.controlRadius; iconSize: Style.font.iconLarge; horizontalPadding:Design.gap.small; verticalPadding:Design.gap.small; focusable: true; enabled: root.player !== null && root.player.canGoPrevious; onClicked: root.service.media("previous") }
        PlayPauseButton { feedback: root.feedback; objectName: "mediaToggle"; playing: root.player !== null && root.player.isPlaying; tooltipText: root.strings.t("playPause"); enabled: root.player !== null && root.player.canTogglePlaying; onClicked: root.service.media("toggle") }
        FeedbackButton { feedback: root.feedback; iconText: "󰒭"; tooltipText: root.strings.t("next"); radius: Design.controlRadius; iconSize: Style.font.iconLarge; horizontalPadding:Design.gap.small; verticalPadding:Design.gap.small; focusable: true; enabled: root.player !== null && root.player.canGoNext; onClicked: root.service.media("next") }
      }
    }
    IslandSlider {
      objectName:"mediaCompactProgress"
      accessibleName:root.strings.t("media.playbackPosition")
      accessibleDescription:root.strings.t("media.seconds").arg(Commons.I18n.formatNumber(Math.floor(liveValue)))
      visible:root.compactOverview && root.overviewSize==="standard" && root.hasTimeline
      Layout.fillWidth:true
      bar:root.bar
      fillColor:Design.accent
      maximum:root.hasTimeline ? root.player.length : 1
      value:root.player ? root.player.position : 0
      enabled:root.expanded && root.hasTimeline && root.player.canSeek
      step:1
      onReleased:value=>{if(root.player && root.player.canSeek) root.player.position=value}
    }
    Item {
      Layout.fillWidth: true
      property real reveal: (root.expanded || root.toast) && !root.compactOverview && (root.showTimeline || root.hasVolume) ? 1 : 0
      implicitHeight: details.implicitHeight * reveal
      visible: reveal > 0
      clip: true
      Behavior on reveal { NumberAnimation { duration: Preferences.duration(180); easing.type: Easing.OutCubic } }
      ColumnLayout {
        id: details
        width: parent.width
        opacity: parent.reveal
        spacing:Design.gap.small
        RowLayout {
          id: timeline
          Layout.fillWidth: true
          spacing:Design.gap.tight
          PlainText {objectName:"mediaElapsed";visible:root.showTimeline;text:Model.time(seek.liveValue);typeRole:"caption";color:Design.text;Layout.alignment:Qt.AlignVCenter}
          IslandSlider {
            id: seek
            objectName: "mediaSeek"
            visible: root.showTimeline
            accessibleName: root.strings.t("media.playbackPosition")
            accessibleDescription: root.strings.t("media.seconds").arg(Commons.I18n.formatNumber(Math.floor(liveValue)))
            Layout.fillWidth: true
            bar: root.bar
            fillColor: Design.accent
            maximum: root.hasTimeline ? root.player.length : 1
            value: root.player && root.player.positionSupported ? root.player.position : 0
            enabled: root.hasTimeline && root.player.canSeek
            step: 1
            onClicked: position => root.feedback.pulseFrom(seek,position)
            onReleased: value => { if (root.player && root.player.canSeek) root.player.position = value }
          }
          PlainText {objectName:"mediaDuration";visible:root.showTimeline;text:root.hasTimeline ? Model.time(root.player.length) : "";typeRole:"caption";color:Design.text;Layout.alignment:Qt.AlignVCenter}
          Item { visible: !root.showTimeline; Layout.fillWidth: true }
          VolumePopover {
            visible: root.hasVolume
            id: volumeControl
            feedback: root.feedback
            player: root.player
            strings: root.strings
            bar: root.bar
            availableWidth: timeline.width
          }
        }
      }
    }
  }
}
