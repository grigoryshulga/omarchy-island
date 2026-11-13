import QtQuick
import qs.Commons as Commons
import "../../sdk" 1.0 as UI

UI.ModuleView {
  id: root
  available: !!backend && backend.allowed
  tooltip: presentation && presentation.strings ? presentation.strings.t("example.title") : ""
  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight
  UI.PlainText {
    id: label
    text: Commons.I18n.formatNumber(root.backend ? root.backend.count : 0)
    typeRole: "bar"
    color: UI.Design.barText
  }
}
