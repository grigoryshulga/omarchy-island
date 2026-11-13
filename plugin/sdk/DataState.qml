import QtQuick
import QtQuick.Layouts
import ".." as Island

// No backend or retry policy: this is a view of the caller's data state.
Item {
  id: root
  property string kind: "empty"
  property string title: ""
  property string description: ""
  property string actionText: ""
  property bool actionEnabled: true
  property bool active: visible
  property var feedback: null
  signal actionRequested()
  implicitHeight: content.implicitHeight
  Accessible.role: Accessible.StaticText
  Accessible.name: title
  Accessible.description: description
  RowLayout {
    id: content
    width: parent.width
    spacing: Island.Design.gap.small
    Item {
      Layout.alignment: Qt.AlignTop
      implicitWidth: Island.Design.type.icon; implicitHeight: Island.Design.type.icon
      Island.T3Spinner { anchors.centerIn: parent; visible: root.kind === "loading"; active: root.active && root.visible }
      Island.PlainText {
        anchors.centerIn: parent
        visible: root.kind !== "loading"
        text: root.kind === "error" ? "!" : root.kind === "stale" ? "◷" : "·"
        color: root.kind === "error" ? Island.Design.danger : root.kind === "stale" ? Island.Design.warning : Island.Design.secondaryText
      }
    }
    ColumnLayout {
      Layout.fillWidth: true; Layout.minimumWidth: 0
      spacing: Island.Design.gap.small
      Island.PlainText { Layout.fillWidth: true; visible: text !== ""; text: root.title; typeRole: "label"; wrapMode: Text.Wrap; elide: Text.ElideNone }
      Island.PlainText { Layout.fillWidth: true; visible: text !== ""; text: root.description; typeRole: "caption"; color: Island.Design.secondaryText; wrapMode: Text.Wrap; elide: Text.ElideNone }
      Island.FeedbackButton { objectName: "dataStateAction"; visible: root.actionText !== ""; text: root.actionText; compact: true; focusable: true; feedback: root.feedback; enabled: root.actionEnabled; onClicked: root.actionRequested() }
    }
  }
}
