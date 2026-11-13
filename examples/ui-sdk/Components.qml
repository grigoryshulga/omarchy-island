import QtQuick
import QtQuick.Layouts
import qs.Island.sdk 1.0 as UI

// Host supplies translations and optional click feedback. No services or I/O.
UI.Surface {
  id: root
  required property var strings
  property var feedback: null
  property bool effectsActive: visible
  property real progress: 0.5
  implicitHeight: content.implicitHeight + 2 * UI.Design.cardPadding
  ColumnLayout {
    id: content
    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    anchors.margins: UI.Design.cardPadding
    spacing: UI.Design.gap.medium
    UI.SectionHeading { Layout.fillWidth: true; title: root.strings.t("example.title") }
    UI.PlainText { text: root.strings.t("example.summary"); Layout.fillWidth: true; wrapMode: Text.Wrap; elide: Text.ElideNone }
    UI.DesignTextField { objectName: "sdkField"; Layout.fillWidth: true; placeholderText: root.strings.t("example.draft") }
    UI.DesignDropdown {
      id: dropdown
      objectName: "sdkDropdown"
      Layout.fillWidth: true
      options: [{value: "summary", label: root.strings.t("example.summary")}, {value: "details", label: root.strings.t("example.details")}]
      value: "summary"
      onChanged: value => dropdown.value = value
    }
    UI.ChoiceButton { Layout.fillWidth: true; label: root.strings.t("example.details"); selected: false; onClicked: selected = !selected; feedback: root.feedback }
    UI.ControlSwitch { objectName: "sdkSwitch"; effectsActive: root.effectsActive; onToggled: checked = !checked; Accessible.name: root.strings.t("settings.exampleEnabled") }
    UI.BrailleProgress { objectName: "sdkProgress"; Layout.fillWidth: true; value: root.progress }
    UI.IslandSlider { objectName: "sdkSlider"; Layout.fillWidth: true; value: root.progress; onMoved: value => root.progress = value }
    UI.BrailleGauge { Layout.fillWidth: true; value: root.progress; glyph: "◉" }
    UI.Spinner { objectName: "sdkSpinner"; active: root.effectsActive }
    UI.FeedbackButton { objectName: "sdkButton"; text: root.strings.t("example.increment"); focusable: true; feedback: root.feedback; onClicked: root.progress = Math.min(1, root.progress + 0.1) }
  }
}
