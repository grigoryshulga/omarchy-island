import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import ".." as Island
import "../controls/ControlFocus.js" as Focus

// A row owns presentation only; the caller owns selection and actions.
Island.Surface {
  id: root
  property string title: ""
  property string description: ""
  property string iconText: ""
  property string statusText: ""
  property string statusKind: "neutral"
  property bool selected: false
  property bool interactive: false
  property var feedback: null
  property alias actions: actions.data
  readonly property bool stacked: width < Island.Design.gap.spacious * 8
  readonly property bool islandNavigationContainer: true
  readonly property color statusColor: statusKind === "error" ? Island.Design.danger : statusKind === "warning" ? Island.Design.warning : statusKind === "success" ? Island.Design.success : Island.Design.secondaryText
  signal clicked()
  implicitHeight: content.implicitHeight + 2 * Island.Design.gap.medium
  color: selected ? Island.Design.selection : Island.Design.surface
  opacity: enabled ? 1 : Island.Design.disabledOpacity
  LayoutMirroring.enabled: Commons.I18n.rightToLeft
  LayoutMirroring.childrenInherit: true
  Accessible.role: interactive ? Accessible.Button : Accessible.Grouping
  Accessible.name: title
  Accessible.description: [description, statusText].filter(function(text) { return !!text }).join(". ")
  onInteractiveChanged: Focus.sync(root, interactive)
  Component.onCompleted: Focus.sync(root, interactive)
  Keys.onReturnPressed: if (interactive) clicked()
  Keys.onEnterPressed: if (interactive) clicked()
  Keys.onSpacePressed: if (interactive) clicked()
  Connections { target: root; function onClicked() { if (root.feedback) root.feedback.pulseFrom(root) } }
  HoverHandler { id: hover }
  MouseArea {
    anchors.fill: parent
    enabled: root.interactive
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(Qt.MouseFocusReason); root.clicked() }
  }
  Rectangle { anchors.fill: parent; radius: root.radius; color: Island.Design.hover; visible: root.activeFocus || (root.interactive && hover.hovered) }
  Rectangle { anchors.fill: parent; color: "transparent"; radius: root.radius; border.width: 2; border.color: Island.Design.focusRing; visible: root.activeFocus }
  GridLayout {
    id: content
    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
    anchors.margins: Island.Design.gap.medium
    columns: root.stacked ? 1 : 2
    rowSpacing: Island.Design.gap.small; columnSpacing: Island.Design.gap.medium
    RowLayout {
      Layout.fillWidth: true; Layout.minimumWidth: 0
      spacing: Island.Design.gap.small
      Island.PlainText { visible: text !== ""; text: root.iconText; color: Island.Design.accent; typeRole: "title"; Layout.alignment: Qt.AlignTop }
      ColumnLayout {
        Layout.fillWidth: true; Layout.minimumWidth: 0
        spacing: Island.Design.gap.tight
        Island.PlainText { Layout.fillWidth: true; text: root.title; color: root.selected ? Island.Design.selectedText : Island.Design.text; typeRole: "title"; wrapMode: Text.Wrap; elide: Text.ElideNone }
        Island.PlainText { Layout.fillWidth: true; visible: text !== ""; text: root.description; typeRole: "caption"; color: root.selected ? Island.Design.selectedSecondaryText : Island.Design.secondaryText; wrapMode: Text.Wrap; elide: Text.ElideNone }
        Island.PlainText { Layout.fillWidth: true; visible: text !== ""; text: root.statusText; typeRole: "caption"; color: root.statusColor; wrapMode: Text.Wrap; elide: Text.ElideNone }
      }
    }
    RowLayout {
      id: actions
      visible: implicitWidth > 0
      Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
      spacing: Island.Design.gap.small
    }
  }
}
