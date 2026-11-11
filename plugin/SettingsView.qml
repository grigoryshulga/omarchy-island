import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "controls"
import "SettingsModel.js" as Settings

Item {
  id:root
  required property var strings
  property var settings:({})
  property var feedback:null
  property int category:0
  property bool ownsKeys:false
  signal settingRequested(string key,var value)
  function focusContent() { if(tabs.itemAt(category)) tabs.itemAt(category).forceActiveFocus() }
  function options(key) {
    return Settings.choices[key].filter(function(value){return key!=="openingPage" || value!=="overview" || Settings.get(root.settings,"overviewEnabled")}).map(function(value){return {value:value,label:root.strings.t("settings.option."+value)}})
  }
  function closeEditors() {
    for(var i=0;i<rows.count;i++) {var row=rows.itemAt(i);if(row && row.editor) row.editor.close()}
    ownsKeys=false
  }
  onVisibleChanged: if(!visible) closeEditors()
  onCategoryChanged: {closeEditors();viewport.contentY=0}
  Flow {
    id:tabFlow
    width:parent.width
    spacing:Style.space(2)
    Repeater {
      id:tabs
      model:Settings.sections
      TabButton {
        required property var modelData
        required property int index
        objectName:"settingsTab-"+modelData.id
        label:root.strings.t("settings.tab."+modelData.id)
        tabActive:root.category===index
        color:"transparent";borderSpec:Border.none()
        fontSize:Style.font.bodySmall
        radius:Math.min(Style.cornerRadius,Style.space(6))
        focusable:true
        feedback:root.feedback
        onClicked:root.category=index
      }
    }
  }
  PanelSeparator {id:divider;width:parent.width;anchors.top:tabFlow.bottom;anchors.topMargin:Style.space(8)}
  Flickable {
    id:viewport
    objectName:"settingsViewport"
    anchors.left:parent.left;anchors.right:parent.right
    anchors.top:divider.bottom;anchors.bottom:parent.bottom
    anchors.topMargin:Style.space(8)
    contentWidth:width;contentHeight:body.implicitHeight
    clip:true;boundsBehavior:Flickable.StopAtBounds
    Controls.ScrollBar.vertical:Controls.ScrollBar {policy:Controls.ScrollBar.AsNeeded}
    Column {
      id:body
      width:viewport.width
      Repeater {
        id:rows
        model:Settings.sections[root.category].rows
        Item {
          id:row
          required property var modelData
          property alias editor:choice
          readonly property string key:modelData.key
          readonly property bool delay:key==="hoverDelay"
          width:body.width
          implicitHeight:layout.implicitHeight+Style.space(22)
          enabled:!modelData.fixed && (!delay || Settings.get(root.settings,"hoverPreview")) && (key!=="t3Responses" || Settings.get(root.settings,"t3Enabled"))
          opacity:enabled ? 1 : 0.45
          ColumnLayout {
            id:layout
            anchors.left:parent.left;anchors.right:parent.right
            anchors.rightMargin:Style.space(8)
            anchors.verticalCenter:parent.verticalCenter
            spacing:Style.space(6)
            RowLayout {
              Layout.fillWidth:true
              spacing:Style.space(8)
              PlainText {
                Layout.fillWidth:true
                text:root.strings.t("settings."+row.key)
                font.pixelSize:Style.font.bodySmall
                wrapMode:Text.Wrap
              }
              ControlSwitch {
                objectName:"setting-"+row.key
                visible:!row.modelData.type
                activeFocusOnTab:true
                hasCursor:activeFocus
                checked:row.modelData.fixed || Settings.get(root.settings,row.key)===true
                onToggled:root.settingRequested(row.key,!checked)
                Keys.onReturnPressed:toggled()
                Keys.onEnterPressed:toggled()
                Keys.onSpacePressed:toggled()
              }
              PlainText {
                visible:row.delay
                text:root.strings.t("settings.milliseconds").arg(Commons.I18n.formatNumber(Settings.get(root.settings,"hoverDelay")))
                color:Commons.Color.muted;font.pixelSize:Style.font.caption
              }
            }
            Dropdown {
              id:choice
              objectName:row.modelData.type==="choice" ? "setting-"+row.key : ""
              Layout.fillWidth:true
              visible:row.modelData.type==="choice"
              value:String(Settings.get(root.settings,row.key))
              options:visible ? root.options(row.key) : []
              showLabel:false
              onChanged:value=>root.settingRequested(row.key,value)
              onPopupOpenChanged:root.ownsKeys=popupOpen
            }
            IslandSlider {
              objectName:row.delay ? "setting-hoverDelay" : ""
              Layout.fillWidth:true
              visible:row.delay
              value:Settings.get(root.settings,"hoverDelay")
              minimum:0;maximum:1000;step:20;integer:true
              onMoved:value=>root.settingRequested("hoverDelay",Math.round(value))
            }
          }
          PanelSeparator {width:parent.width;anchors.bottom:parent.bottom}
        }
      }
    }
  }
}
