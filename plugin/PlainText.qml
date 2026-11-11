import QtQuick
import qs.Commons
import qs.Commons as Commons
Text {
  property string typeRole: "body"
  textFormat: Text.PlainText
  font.family: Design.fontFamily
  font.pixelSize: Design.fontSize(typeRole)
  font.weight: Design.weight(typeRole)
  lineHeightMode: Text.FixedHeight
  lineHeight: Design.lineHeight(typeRole)
  color: Design.text
  elide: Text.ElideRight
}
