import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Surface {
  id: root
  required property var service
  required property var strings
  property var bar: null
  property var externalFeedback: null
  readonly property var feedback: externalFeedback || brailleFeedback
  readonly property bool hovered: hover.hovered
  property bool expanded: false
  property bool compactOverview: false
  property bool active: true
  property bool radialBraille: true
  readonly property var player: service ? service.player : null
  signal expandRequested()
  signal closeRequested()
  implicitHeight: body.implicitHeight+2*Design.cardPadding
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
    artworkUrl: root.player ? root.player.trackArtUrl : ""
  }
  Timer {
    interval: 500
    repeat: true
    running: root.active && root.visible && root.expanded && root.player !== null && root.player.isPlaying && root.player.positionSupported
    onTriggered: if (root.player) root.player.positionChanged()
  }
  ColumnLayout {
    id: body
    anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Design.cardPadding
    spacing:Design.gap.medium
    RowLayout {
      Layout.fillWidth: true
      spacing:Design.gap.medium
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing:Design.gap.tight
        PlainText {visible:root.compactOverview;Layout.fillWidth:true;text:root.player ? root.player.identity : root.strings.t("media.title");typeRole:"caption";color:Design.secondaryText;elide:Text.ElideRight}
        PlainText { objectName: "mediaTitle"; Layout.fillWidth: true; Layout.minimumWidth: 0; text: root.player ? root.player.trackTitle || root.strings.t("untitled") : root.strings.t("noMusic"); typeRole: "section" }
        PlainText { Layout.fillWidth: true; Layout.minimumWidth: 0; text: root.player ? root.player.trackArtist || root.player.identity : root.strings.t("musicApps"); color: root.player ? Design.accent : Design.secondaryText; typeRole:"caption" }
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
      visible:root.compactOverview && root.player && root.player.lengthSupported && root.player.positionSupported
      Layout.fillWidth:true
      bar:root.bar
      fillColor:Design.accent
      maximum:root.player ? Math.max(1,root.player.length) : 1
      value:root.player ? root.player.position : 0
      enabled:root.expanded && root.player!==null && root.player.canSeek && root.player.lengthSupported && root.player.positionSupported
      step:1
      onReleased:value=>{if(root.player && root.player.canSeek) root.player.position=value}
    }
    Item {
      Layout.fillWidth: true
      property real reveal: root.expanded && !root.compactOverview && root.player !== null ? 1 : 0
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
          PlainText {objectName:"mediaElapsed";text:Model.time(seek.liveValue);typeRole:"caption";color:Design.text;Layout.alignment:Qt.AlignVCenter}
          IslandSlider {
            id: seek
            objectName: "mediaSeek"
            Layout.fillWidth: true
            bar: root.bar
            fillColor: Design.accent
            maximum: root.player && root.player.lengthSupported ? Math.max(1,root.player.length) : 1
            value: root.player && root.player.positionSupported ? root.player.position : 0
            enabled: root.player !== null && root.player.canSeek && root.player.lengthSupported && root.player.positionSupported
            step: 1
            onClicked: position => root.feedback.pulseFrom(seek,position)
            onReleased: value => { if (root.player && root.player.canSeek) root.player.position = value }
          }
          PlainText {objectName:"mediaDuration";text:Model.time(seek.maximum);typeRole:"caption";color:Design.text;Layout.alignment:Qt.AlignVCenter}
          VolumePopover {
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
