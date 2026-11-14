import QtQuick
import "../.." as Island

Island.ModuleView {
  id:root
  implicitHeight:label.implicitHeight
  Island.PlainText {
    id:label;width:parent.width;wrapMode:Text.Wrap;typeRole:"caption";color:Island.Design.secondaryText
    text:root.presentation.strings.t("herdr.help")
  }
}
