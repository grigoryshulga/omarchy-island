import QtQuick
import ".."

// Preserve a borrowed panel's layout/visibility bindings without painting a line.
Item {
  property color foreground: Design.text
  implicitWidth: parent ? parent.width : 0
  implicitHeight: Design.gap.small
}
