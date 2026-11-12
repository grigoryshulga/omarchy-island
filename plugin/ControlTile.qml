import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

FeedbackButton {
  id:root
  property string title: ""
  property string description: ""
  property string glyph: ""
  property bool drillDown: false
  property bool showLed: !drillDown
  property bool effectsActive: true
  property color glyphColor: selected ? Design.accent : Design.text
  implicitWidth:Style.space(compact ? 120 : 190)
  implicitHeight:Style.space(compact ? 72 : 88)
  focusable:true
  background:Design.surface
  Rectangle {
    visible:root.showLed
    anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Design.gap.medium
    width:Style.space(5);height:width;radius:width/2
    color:root.selected ? root.glyphColor : Design.secondaryText
    opacity:root.selected ? 1 : 0.35
    IndicatorGlow {anchors.centerIn:parent;active:root.effectsActive && root.selected && root.visible;accent:root.glyphColor;width:Style.space(34);height:width}
  }
  RowLayout {
    anchors.fill:parent
    anchors.margins:root.compact ? Design.gap.medium : Design.cardPadding
    spacing:Design.gap.medium
    PlainText {
      id:glyph
      text:root.glyph;font.pixelSize:root.compact ? Style.font.icon : Style.font.iconLarge;color:root.glyphColor
      IndicatorGlow {anchors.centerIn:parent;active:root.effectsActive && root.selected && root.visible;accent:root.glyphColor;z:-1}
    }
    ColumnLayout {
      Layout.fillWidth:true
      spacing:Design.gap.tight
      PlainText {Layout.fillWidth:true;text:root.title;typeRole:"title";font.pixelSize:root.compact ? Design.type.label : Design.type.title;elide:Text.ElideRight}
      PlainText {Layout.fillWidth:true;text:root.description;typeRole:"caption";color:root.selected ? Design.selectedSecondaryText : Design.secondaryText;elide:Text.ElideRight}
    }
    PlainText {visible:root.drillDown;text:Commons.I18n.rightToLeft ? "󰅁" : "󰅂";color:Design.secondaryText;font.pixelSize:Style.font.iconSmall}
  }
}
