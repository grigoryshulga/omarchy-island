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
  property bool compact: false
  property bool showLed: !drillDown
  property color glyphColor: selected ? Commons.Color.accent : Commons.Color.foreground
  implicitWidth:Style.space(compact ? 120 : 190)
  implicitHeight:Style.space(compact ? 60 : 72)
  focusable:true
  background:Style.normalFillFor(Commons.Color.foreground,Commons.Color.accent)
  Rectangle {
    visible:root.showLed
    anchors.right:parent.right;anchors.top:parent.top
    anchors.margins:Style.space(9)
    width:Style.space(5);height:width;radius:width/2
    color:root.selected ? root.glyphColor : Commons.Color.muted
    opacity:root.selected ? 1 : 0.35
    IndicatorGlow {anchors.centerIn:parent;active:root.selected && root.visible;accent:root.glyphColor;width:Style.space(34);height:width}
  }
  RowLayout {
    anchors.fill:parent
    anchors.margins:Style.space(root.compact ? 10 : 12)
    spacing:Style.space(root.compact ? 7 : 10)
    PlainText {
      id:glyph
      text:root.glyph;font.pixelSize:root.compact ? Style.font.icon : Style.font.iconLarge;color:root.glyphColor
      IndicatorGlow {anchors.centerIn:parent;active:root.selected && root.visible;accent:root.glyphColor;z:-1}
    }
    ColumnLayout {
      Layout.fillWidth:true
      spacing:Style.space(4)
      PlainText {Layout.fillWidth:true;text:root.title;font.pixelSize:root.compact ? Style.font.bodySmall : Style.font.body;elide:Text.ElideRight}
      PlainText {Layout.fillWidth:true;text:root.description;font.pixelSize:Style.font.caption;color:Commons.Color.muted;elide:Text.ElideRight}
    }
    PlainText {visible:root.drillDown;text:Commons.I18n.rightToLeft ? "󰅁" : "󰅂";color:Commons.Color.muted;font.pixelSize:Style.font.iconSmall}
  }
}
