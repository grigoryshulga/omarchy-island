import QtQuick
import qs.Commons
import "../.." as Island
Island.ModuleView {
  id:root
  readonly property bool toast:!presentation.expanded && !presentation.hovering && presentation.alertKind==="media"
  available:!!backend && backend.hasMedia && (presentation.expanded || presentation.hovering || toast)
  implicitHeight:content.implicitHeight
  interactionHovered:card.hovered
  Column {
    id:content;width:parent.width;spacing:Island.Design.gap.small
    Island.SectionHeading {
      objectName:"mediaSectionHeading";width:parent.width;visible:!root.toast && !card.compactOverview
      title:root.backend && root.backend.player && /spotify/i.test(root.backend.player.identity || "") ? "Spotify" : root.presentation.strings.t("media.title")
    }
    Island.MediaCard {
      id:card;objectName:"islandMediaPlayer";width:parent.width
      color:root.toast ? "transparent" : Island.Design.surface
      externalFeedback:root.presentation.feedback
      service:root.backend;strings:root.presentation.strings;bar:root.presentation.bar
      expanded:root.presentation.expanded;compactOverview:!root.toast
      active:root.presentation.active;radialBraille:root.presentation.radialBraille
      onExpandRequested:root.expandRequested()
      onCloseRequested:root.closeRequested()
    }
  }
}
