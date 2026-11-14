import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root
  required property var player
  required property var strings
  property var bar: null
  property var feedback: null
  property real availableWidth: Style.space(420)
  property bool opened: false
  readonly property bool controllable: player !== null && player.volumeSupported
  readonly property bool hovering: trigger.hot || trigger.activeFocus || volume.activeFocus || flyoutHover.hovered || volume.dragging
  implicitWidth: Style.space(30)
  implicitHeight: Style.space(32)
  z: 10
  onHoveringChanged: {
    if (hovering && controllable) { closeGrace.stop(); opened = true }
    else closeGrace.restart()
  }
  onVisibleChanged: if (!visible) opened = false
  onControllableChanged: if (!controllable) opened = false
  Timer { id: closeGrace; interval: 180; onTriggered: if (!root.hovering) root.opened = false }
  FeedbackButton {
    id: trigger
    feedback: root.feedback
    objectName: "mediaVolumeTrigger"
    anchors.fill: parent
    radius: Design.controlRadius
    iconText: root.player && root.player.volumeSupported && root.player.volume === 0 ? "󰝟" : "󰕾"
    tooltipText: root.controllable ? "" : root.strings.t("noVolume")
    focusable: true
    enabled: root.player !== null
    onClicked: if (root.controllable) root.opened = !root.opened
    Keys.onEscapePressed: root.opened = false
  }
  PopupReveal {
    id: reveal
    open: root.opened
    targetWidth: Math.min(Style.space(225),Math.max(Style.space(120),root.availableWidth-root.width-Style.space(8)))
    targetHeight: root.height
    seedWidth: Style.space(30)
    seedHeight: Style.space(20)
    fallDistance: Style.space(8)
  }
  ContainerSurface {
    id: flyout
    objectName: "mediaVolumePopover"
    readonly property real shown: reveal.shown
    width: reveal.drawnWidth
    height: reveal.drawnHeight
    x: -reveal.targetWidth/2-width/2-Style.space(6)
    y: reveal.offsetY
    color: Design.canvas
    radius: Math.min(Style.cornerRadius,Style.space(6),height/2)
    borderSpec: Design.popupBorder
    opacity: shown
    visible: shown > 0
    clip: true
    HoverHandler { id: flyoutHover }
    RowLayout {
      x: (flyout.width-reveal.targetWidth)/2+Style.space(5)
      y: Style.space(5)
      width: reveal.targetWidth-Style.space(10)
      height: reveal.targetHeight-Style.space(10)
      opacity: reveal.contentShown
      spacing:Design.gap.small
      IslandSlider {
        id: volume
        objectName: "mediaVolume"
        Layout.fillWidth: true
        Layout.preferredHeight: parent.height
        bar: root.bar
        enabled: root.controllable
        value: root.controllable ? root.player.volume : 0
        onClicked: position => { if(root.feedback) root.feedback.pulseFrom(volume,position) }
        onMoved: value => { if (root.controllable) root.player.volume = value }
      }
      PlainText {
        Layout.preferredWidth: Style.space(38)
        horizontalAlignment: Text.AlignRight
        text: root.controllable ? Commons.I18n.formatNumber(Math.round(root.player.volume*100))+"%" : "—"
        typeRole:"caption"
      }
    }
  }
}
