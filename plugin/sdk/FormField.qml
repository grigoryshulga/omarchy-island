import QtQuick
import QtQuick.Layouts
import ".." as Island

ColumnLayout {
  id: root
  property string label: ""
  property string hint: ""
  property string error: ""
  readonly property string message: error || hint
  readonly property Item control: editor.children.length ? editor.children[0] : null
  default property alias content: editor.data
  spacing: Island.Design.gap.tight
  Accessible.role: Accessible.Grouping
  Accessible.name: label
  Accessible.description: message
  function focusEditor() { if (control) control.forceActiveFocus(Qt.TabFocusReason) }
  data: [
    Island.PlainText {
      Layout.fillWidth: true
      visible: text !== ""; text: root.label; typeRole: "label"
      wrapMode: Text.Wrap; elide: Text.ElideNone
      MouseArea { anchors.fill: parent; onClicked: root.focusEditor() }
    },
    ColumnLayout { id: editor; Layout.fillWidth: true; spacing: Island.Design.gap.small },
    Island.PlainText {
      Layout.fillWidth: true
      visible: text !== ""; text: root.message; typeRole: "caption"
      color: root.error ? Island.Design.danger : Island.Design.secondaryText
      wrapMode: Text.Wrap; elide: Text.ElideNone
    }
  ]
}
