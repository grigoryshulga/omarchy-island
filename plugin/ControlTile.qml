import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

FeedbackButton {
  id:root
  property string title: ""
  property string glyph: ""
  property bool drillDown: false
  property bool showLed: !drillDown
  property bool effectsActive: true
  property color glyphColor: selected ? Design.accent : Design.text
  implicitWidth:Style.space(compact ? 120 : 190)
  implicitHeight:Math.max(Design.controlHeight,Style.space(compact ? 44 : 52))
  Accessible.name:title
  Accessible.description:tooltipText
  focusable:true
  background:Design.surface
  RowLayout {
    anchors.fill:parent
    anchors.leftMargin:Design.gap.medium;anchors.rightMargin:Design.gap.medium
    anchors.topMargin:Design.gap.tight;anchors.bottomMargin:Design.gap.tight
    spacing:Design.gap.small
    PlainText {
      id:glyph
      text:root.glyph;font.pixelSize:root.compact ? Style.font.icon : Style.font.iconLarge;color:root.glyphColor
      IndicatorGlow {anchors.centerIn:parent;active:root.effectsActive && root.selected && root.visible;accent:root.glyphColor;z:-1}
    }
    Rectangle {
      objectName:"controlStateLed"
      visible:root.showLed
      Layout.alignment:Qt.AlignVCenter
      width:Style.space(5);height:width;radius:width/2
      color:root.selected ? root.glyphColor : Design.secondaryText
      opacity:root.selected ? 1 : 0.35
      IndicatorGlow {anchors.centerIn:parent;active:root.effectsActive && root.selected && root.visible;accent:root.glyphColor;width:Style.space(34);height:width}
    }
    PlainText {Layout.fillWidth:true;text:root.title;typeRole:"title";font.pixelSize:root.compact ? Design.type.label : Design.type.title;elide:Text.ElideRight}
    PlainText {visible:root.drillDown;text:Commons.I18n.rightToLeft ? "󰅁" : "󰅂";color:Design.secondaryText;font.pixelSize:Style.font.iconSmall}
  }
}
