import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "controls"
import "SettingsModel.mjs" as Settings

Item {
  id:root
  required property var spec
  required property var strings
  property var settings:({})
  property bool active:true
  property alias editor:choice
  readonly property string key:spec.key
  readonly property bool delay:spec.type==="delay"
  readonly property bool percent:spec.type==="percent"
  readonly property bool numeric:delay || percent
  readonly property bool dependent:!!spec.dependsOn
  readonly property bool available:!spec.fixed && (!dependent || Settings.get(settings,spec.dependsOn))
  readonly property bool stacked:spec.type==="choice" && title.implicitWidth+choiceWidth+Design.gap.large>content.width
  readonly property real choiceWidth:Math.min(content.width,Math.max(Style.space(160),choice.options.reduce(function(size,option){return Math.max(size,metrics.advanceWidth(option.label)+Design.gap.spacious)},0)))
  signal settingRequested(string key,var value)
  signal popupChanged()
  implicitHeight:content.implicitHeight
  enabled:available
  opacity:available ? 1 : Design.disabledOpacity

  FontMetrics {id:metrics;font.family:Design.fontFamily;font.pixelSize:Style.font.body}
  Item {
    id:content
    anchors.left:parent.left;anchors.right:parent.right
    anchors.leftMargin:root.dependent && !Commons.I18n.rightToLeft ? Design.gap.large : 0
    anchors.rightMargin:root.dependent && Commons.I18n.rightToLeft ? Design.gap.large : 0
    implicitHeight:root.numeric ? title.implicitHeight+Design.gap.small+slider.implicitHeight : root.stacked ? title.implicitHeight+Design.gap.small+choice.implicitHeight : Math.max(Design.controlHeight,title.implicitHeight,choice.visible ? choice.implicitHeight : toggle.implicitHeight)
    height:implicitHeight
    PlainText {
      id:title
      objectName:"settingLabel-"+root.key
      x:Commons.I18n.rightToLeft ? content.width-width : 0
      y:root.numeric || root.stacked ? 0 : (content.height-height)/2
      width:root.stacked ? content.width : Math.max(0,content.width-(choice.visible ? choice.width : toggle.visible ? toggle.width : delayValue.width)-Design.gap.large)
      text:root.strings.t("settings."+root.key)
      typeRole:"body"
      wrapMode:Text.Wrap
    }
    ControlSwitch {
      id:toggle
      effectsActive:root.active
      objectName:!root.spec.type ? "setting-"+root.key : ""
      Accessible.name:title.text
      visible:!root.spec.type
      x:Commons.I18n.rightToLeft ? 0 : content.width-width
      anchors.verticalCenter:parent.verticalCenter
      hasCursor:activeFocus
      checked:root.spec.fixed || Settings.get(root.settings,root.key)===true
      onToggled:root.settingRequested(root.key,!checked)
    }
    PlainText {
      id:delayValue
      visible:root.numeric
      x:Commons.I18n.rightToLeft ? 0 : content.width-width
      anchors.verticalCenter:title.verticalCenter
      text:root.percent ? Commons.I18n.formatNumber(Settings.get(root.settings,root.key))+"%" : root.strings.t("settings.milliseconds").arg(Commons.I18n.formatNumber(Settings.get(root.settings,"hoverDelay")))
      color:Design.secondaryText;typeRole:"caption"
    }
    DesignDropdown {
      id:choice
      objectName:root.spec.type==="choice" ? "setting-"+root.key : ""
      visible:root.spec.type==="choice"
      x:root.stacked || Commons.I18n.rightToLeft ? 0 : content.width-width
      y:root.stacked ? title.height+Design.gap.small : (content.height-height)/2
      width:root.stacked ? content.width : root.choiceWidth
      value:String(Settings.get(root.settings,root.key))
      options:visible ? Settings.choices[root.key].filter(function(value){return root.key!=="openingPage" || value!=="overview" || Settings.get(root.settings,"overviewEnabled")}).map(function(value){return {value:value,label:root.strings.t("settings.option."+value)}}) : []
      showLabel:false
      onChanged:value=>root.settingRequested(root.key,value)
      onPopupOpenChanged:root.popupChanged()
    }
    IslandSlider {
      id:slider
      objectName:root.numeric ? "setting-"+root.key : ""
      visible:root.numeric
      y:title.height+Design.gap.small
      width:content.width
      value:root.numeric ? Settings.get(root.settings,root.key) : 0
      minimum:0;maximum:root.percent ? 100 : 1000;step:root.percent ? 5 : 20;integer:true
      onMoved:value=>root.settingRequested(root.key,Math.round(value))
    }
  }
}
