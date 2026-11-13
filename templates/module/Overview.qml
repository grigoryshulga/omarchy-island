import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import "../../sdk" 1.0 as UI

UI.ModuleView {
  id: root
  objectName: "exampleOverview"
  available: !!backend && backend.allowed && !!presentation && (presentation.expanded || presentation.hovering)
  implicitHeight: card.implicitHeight
  readonly property bool detail: !!presentation && presentation.detail
  readonly property var feedback: presentation ? presentation.feedback : null
  function tr(key) { return presentation && presentation.strings ? presentation.strings.t(key) : "" }

  UI.Surface {
    id: card
    width: parent.width
    implicitHeight: content.implicitHeight + 2 * UI.Design.cardPadding
    ColumnLayout {
      id: content
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: UI.Design.cardPadding
      spacing: UI.Design.gap.medium
      UI.SectionHeading {
        Layout.fillWidth: true
        title: root.tr("example.title")
        detail: Commons.I18n.formatNumber(root.backend ? root.backend.count : 0)
      }
      UI.PlainText {
        Layout.fillWidth: true
        text: root.tr(root.detail ? "example.description" : "example.summary")
        wrapMode: Text.Wrap; elide: Text.ElideNone
        color: UI.Design.secondaryText
      }
      UI.DesignTextField {
        objectName: "exampleDraft"
        Layout.fillWidth: true
        visible: root.detail
        placeholderText: root.tr("example.draft")
        // Local draft survives details navigation; it is not shared across monitors.
      }
      UI.FeedbackButton {
        objectName: "exampleAction"
        Layout.fillWidth: true
        focusable: true
        feedback: root.feedback
        text: root.tr(root.detail ? "example.increment" : "example.details")
        enabled: !!root.presentation && root.presentation.expanded && root.available
        onClicked: {
          if (root.detail) root.backend.increment()
          else root.detailsRequested()
        }
      }
    }
  }
}
