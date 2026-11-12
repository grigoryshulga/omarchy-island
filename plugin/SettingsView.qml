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
  property bool active:true
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
    spacing:Design.gap.micro
    Repeater {
      id:tabs
      model:Settings.sections
      TabButton {
        required property var modelData
        required property int index
        objectName:"settingsTab-"+modelData.id
        label:root.strings.t("settings.tab."+modelData.id)
        tabActive:root.category===index

        fontSize:Design.type.label
        radius:Design.controlRadius
        focusable:true
        feedback:root.feedback
        onClicked:root.category=index
      }
    }
  }

  Flickable {
    id:viewport
    objectName:"settingsViewport"
    anchors.left:parent.left;anchors.right:parent.right
    anchors.top:tabFlow.bottom;anchors.bottom:parent.bottom
    anchors.topMargin:Design.gap.large
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
          readonly property bool percent:modelData.type==="percent"
          readonly property bool delay:key==="hoverDelay"
          width:body.width
          implicitHeight:layout.implicitHeight+Design.gap.section
          enabled:!modelData.fixed && (!delay || Settings.get(root.settings,"hoverPreview")) && (key!=="t3Responses" || Settings.get(root.settings,"t3Enabled"))
          opacity:enabled ? 1 : Design.disabledOpacity
          ColumnLayout {
            id:layout
            anchors.left:parent.left;anchors.right:parent.right
            anchors.rightMargin:Design.gap.small
            anchors.verticalCenter:parent.verticalCenter
            spacing:Design.gap.small
            RowLayout {
              Layout.fillWidth:true
              spacing:Design.gap.small
              PlainText {
                Layout.fillWidth:true
                text:root.strings.t("settings."+row.key)
                typeRole:"title"
                wrapMode:Text.Wrap
              }
              ControlSwitch {
                effectsActive:root.active
                objectName:"setting-"+row.key
                Accessible.name:root.strings.t("settings."+row.key)
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
                visible:row.delay || row.percent
                text:row.percent ? Commons.I18n.formatNumber(Settings.get(root.settings,row.key))+"%" :root.strings.t("settings.milliseconds").arg(Commons.I18n.formatNumber(Settings.get(root.settings,"hoverDelay")))
                color:Design.secondaryText;typeRole:"caption"
              }
            }
            DesignDropdown {
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
              visible:row.delay || row.percent
              value:row.delay || row.percent ? Settings.get(root.settings,row.key) : 0
              minimum:0;maximum:row.percent ? 100 : 1000;step:row.percent ? 5 : 20;integer:true
              onMoved:value=>root.settingRequested(row.key,Math.round(value))
            }
          }

        }
      }
    }
  }
}
