import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

RowLayout {
  id: root
  property string kind: "volume"
  property real value: 0
  property bool muted: false
  property real progress: Math.max(0,Math.min(1,value))
  spacing: Style.space(6)
  implicitHeight: Style.space(18)
  Behavior on progress {NumberAnimation {duration:Style.duration(90);easing.type:Easing.OutCubic}}
  PlainText {text:root.kind==="brightness" ? "󰃠" : root.muted || root.value<=0 ? "󰝟" : "󰕾";font.pixelSize:Style.font.icon;color:Commons.Color.accent}
  ShaderEffect {
    objectName:"brailleGaugeField"
    Layout.fillWidth:true
    Layout.preferredWidth:Style.space(100)
    Layout.preferredHeight:Style.space(14)
    property vector2d size:Qt.vector2d(width,height)
    property real amount:root.progress
    property color accent:Commons.Color.accent
    vertexShader:Qt.resolvedUrl("shaders/gauge.vert.qsb")
    fragmentShader:Qt.resolvedUrl("shaders/gauge.frag.qsb")
  }
  PlainText {Layout.preferredWidth:percentMeasure.implicitWidth;horizontalAlignment:Text.AlignRight;text:Commons.I18n.formatNumber(Math.round(root.value*100))+"%";font.pixelSize:Style.font.bodySmall}
  PlainText {id:percentMeasure;visible:false;text:Commons.I18n.formatNumber(100)+"%";font.pixelSize:Style.font.bodySmall}
}
