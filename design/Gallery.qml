import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons as Commons
import "Island" as Island
import "Island/controls" as IslandControls

// This is the production QML kit, not a second HTML implementation.
Rectangle {
  id: root
  color: Island.Design.opaqueCanvas
  property string previewTheme: "system"
  property var original: null
  property bool narrow: false
  property bool sdkExample: false
  property bool largeText: false
  property int originalFontSize: 12
  property bool answered: false
  property string status: ""
  readonly property var strings: translations
  Commons.Translations {id:translations;directory:Qt.resolvedUrl("i18n")}
  function setTheme(name) {
    if(!original) original={background:Commons.Color.background,foreground:Commons.Color.foreground,
      accent:Commons.Color.accent,muted:Commons.Color.muted,urgent:Commons.Color.urgent,
      popup:Commons.Color.popups.background,popupText:Commons.Color.popups.text}
    var presets={
      dark:{background:"#16191d",foreground:"#e5e8ed",accent:"#9bb9ff",muted:"#8e98a6",urgent:"#f6a6ad"},
      light:{background:"#f6f4ef",foreground:"#252932",accent:"#335bb1",muted:"#707684",urgent:"#a7344c"},
      mono:{background:"#111111",foreground:"#eeeeee",accent:"#c0c0c0",muted:"#555555",urgent:"#aaaaaa"}
    }
    var value=presets[name] || original
    Commons.Color.background=value.background;Commons.Color.foreground=value.foreground
    Commons.Color.accent=value.accent;Commons.Color.muted=value.muted;Commons.Color.urgent=value.urgent
    Commons.Color.popups.background=value.popup || value.background;Commons.Color.popups.text=value.popupText || value.foreground
    previewTheme=name
  }
  QtObject {
    id:bridge
    property bool connected:true
    property bool canRespond:true
    property bool responsesEnabled:true
    function response(id) {return root.answered ? "sent" : ""}
    function openThread(id) {root.status=translations.t("design.opened")}
    function submit(thread,request,answers) {root.answered=true;root.status=JSON.stringify(answers)}
  }
  Controls.ScrollView {
    id:viewport
    anchors.fill:parent
    contentWidth:availableWidth
    Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
    ColumnLayout {
      id:content
      width:viewport.availableWidth
      spacing:Island.Design.gap.section
      RowLayout {
        Layout.fillWidth:true
        Layout.margins:Island.Design.gap.large
        ColumnLayout {
          Layout.fillWidth:true;spacing:Island.Design.gap.tight
          Island.PlainText {text:"Island";typeRole:"page"}
          Island.PlainText {text:translations.t("design.title");typeRole:"caption";color:Island.Design.secondaryText}
        }
        Repeater {
          model:["system","dark","light","mono"]
          Island.ActionButton {
            required property string modelData
            text:translations.t("design."+modelData);selected:root.previewTheme===modelData
            onClicked:root.setTheme(modelData)
          }
        }
      }
      RowLayout {
        Layout.fillWidth:true;Layout.leftMargin:Island.Design.gap.large;Layout.rightMargin:Island.Design.gap.large
        spacing:Island.Design.gap.small
        Island.ActionButton {text:translations.t("design.square");selected:Commons.Style.cornerRadius===0;onClicked:Commons.Style.cornerRadius=Commons.Style.cornerRadius===0 ? 12 : 0}
        Island.ActionButton {text:translations.t("design.largeText");selected:root.largeText;onClicked:{if(!root.largeText) root.originalFontSize=Commons.Style.fontBaseSize;root.largeText=!root.largeText;Commons.Style.fontBaseSize=root.largeText ? Math.round(root.originalFontSize*1.25) : root.originalFontSize}}
        Island.ActionButton {text:translations.t("design.reduceMotion");selected:Commons.Style.reduceMotion;onClicked:Commons.Style.reduceMotion=!Commons.Style.reduceMotion}
        Island.ActionButton {text:translations.t("design.narrow");selected:root.narrow;onClicked:root.narrow=!root.narrow}
        Item {Layout.fillWidth:true}
      }
      Components {
        visible:root.sdkExample
        Layout.fillWidth:!root.narrow
        Layout.preferredWidth:root.narrow ? 340 : -1
        Layout.maximumWidth:root.narrow ? 340 : Infinity
        Layout.margins:Island.Design.gap.large
        strings:translations
      }
      GridLayout {
        visible:!root.sdkExample
        Layout.fillWidth:true;Layout.margins:Island.Design.gap.large
        columns:root.width>850 ? 2 : 1
        columnSpacing:Island.Design.gap.section;rowSpacing:Island.Design.gap.section
        uniformCellWidths:true
        ColumnLayout {
          Layout.fillWidth:true;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop
          spacing:Island.Design.gap.medium
          Island.SectionHeading {Layout.fillWidth:true;title:translations.t("design.type")}
          Repeater {
            model:["page","section","title","body","label","caption"]
            RowLayout {
              required property string modelData
              Layout.fillWidth:true
              Island.PlainText {Layout.fillWidth:true;text:translations.t("design.typeSample");typeRole:parent.modelData}
              Island.PlainText {text:parent.modelData+"  "+Island.Design.fontSize(parent.modelData)+" / "+Island.Design.lineHeight(parent.modelData);typeRole:"caption";color:Island.Design.secondaryText}
            }
          }
          Island.SectionHeading {Layout.fillWidth:true;Layout.topMargin:Island.Design.gap.medium;title:translations.t("design.palette")}
          GridLayout {
            Layout.fillWidth:true;columns:4;uniformCellWidths:true
            rowSpacing:Island.Design.gap.small;columnSpacing:Island.Design.gap.small
            Repeater {
              model:["surface","raised","text","secondaryText","accent","danger","selection","focusRing"]
              ColumnLayout {
                required property string modelData
                Layout.fillWidth:true;Layout.minimumWidth:0
                Rectangle {Layout.fillWidth:true;implicitHeight:32;radius:Island.Design.controlRadius;color:Island.Design[parent.modelData]}
                Island.PlainText {Layout.fillWidth:true;text:parent.modelData;typeRole:"caption"}
              }
            }
          }
          Island.SectionHeading {Layout.fillWidth:true;Layout.topMargin:Island.Design.gap.medium;title:translations.t("design.rhythm")}
          RowLayout {
            Layout.fillWidth:true;spacing:Island.Design.gap.small
            Repeater {
              model:[4,8,12,16,24,32,48]
              ColumnLayout {
                required property int modelData
                Rectangle {width:Commons.Style.space(parent.modelData);height:24;color:Island.Design.accent;radius:Island.Design.controlRadius}
                Island.PlainText {text:parent.modelData;typeRole:"caption"}
              }
            }
          }
          Island.PlainText {Layout.fillWidth:true;text:translations.t("design.noDividers");typeRole:"caption";wrapMode:Text.Wrap;color:Island.Design.secondaryText}
        }
        ColumnLayout {
          Layout.fillWidth:true;Layout.minimumWidth:0;Layout.alignment:Qt.AlignTop
          spacing:Island.Design.gap.medium
          Island.SectionHeading {Layout.fillWidth:true;title:translations.t("design.controls")}
          Flow {
            Layout.fillWidth:true;spacing:Island.Design.gap.small
            Island.FeedbackButton {text:translations.t("design.primary");variant:"primary";focusable:true}
            Island.FeedbackButton {text:translations.t("design.secondary");variant:"soft";focusable:true}
            Island.FeedbackButton {text:translations.t("design.quiet");focusable:true}
            Island.FeedbackButton {text:translations.t("design.disabled");enabled:false;variant:"soft"}
          }
          RowLayout {
            Layout.fillWidth:true
            Island.DesignTextField {objectName:"galleryInput";Layout.fillWidth:true;placeholderText:translations.t("design.input");Accessible.name:placeholderText}
            IslandControls.ControlSwitch {checked:true;onToggled:checked=!checked}
            Island.T3Spinner {objectName:"gallerySpinner";active:root.visible}
          }
          Island.IslandSlider {id:demoSlider;Layout.fillWidth:true;value:0.65;onMoved:next=>demoSlider.value=next}
          Island.DesignDropdown {id:demoDropdown;Layout.fillWidth:true;value:"visible";options:[{value:"visible",label:translations.t("settings.option.visible")},{value:"off",label:translations.t("settings.option.off")}];onChanged:next=>demoDropdown.value=next}
          RowLayout {
            Layout.fillWidth:true
            Island.TabButton {Layout.fillWidth:true;label:translations.t("tabs.overview");tabActive:true;focusable:true}
            Island.TabButton {Layout.fillWidth:true;label:translations.t("tabs.controls");focusable:true}
            Island.TabButton {Layout.fillWidth:true;label:translations.t("calendar.open");focusable:true}
          }
          RowLayout {
            Layout.fillWidth:true;spacing:Island.Design.gap.small
            Island.ControlTile {Layout.fillWidth:true;Layout.preferredWidth:1;title:translations.t("controls.audio");tooltipText:translations.t("controls.audioHint");glyph:"󰕾";drillDown:true}
            Island.ControlTile {Layout.fillWidth:true;Layout.preferredWidth:1;title:translations.t("controls.dndShort");tooltipText:translations.t("controls.on");glyph:"󰂛";selected:true;onClicked:selected=!selected}
          }
          Island.SectionHeading {Layout.fillWidth:true;Layout.topMargin:Island.Design.gap.medium;title:translations.t("design.states")}
          RowLayout {
            Layout.fillWidth:true;spacing:Island.Design.gap.small
            Island.ChoiceButton {Layout.fillWidth:true;Layout.preferredWidth:1;label:translations.t("design.selected");selected:true;onClicked:selected=!selected}
            Island.ChoiceButton {Layout.fillWidth:true;Layout.preferredWidth:1;label:translations.t("design.choice");multiSelect:true;onClicked:selected=!selected}
          }
        }
        ColumnLayout {
          Layout.columnSpan:parent.columns;Layout.fillWidth:true
          spacing:Island.Design.gap.medium
          Island.SectionHeading {Layout.fillWidth:true;title:"T3 Code";detail:translations.t("design.interactive")}
          Island.T3SessionCard {
            objectName:"galleryQuestion"
            Layout.fillWidth:!root.narrow;Layout.preferredWidth:root.narrow ? 340 : -1
            Layout.maximumWidth:root.narrow ? 340 : Infinity
            strings:translations;bridge:bridge;expanded:true
            row:({id:"sample",title:translations.t("design.thread"),project:"Island",status:"running",startedAt:Date.now()/1000-82,summary:"",requestId:"preview",requestKind:"user_input",
              request:{id:"preview",revision:"1",canRespond:true,questions:[{id:"mode",text:translations.t("design.question"),required:true,multiSelect:false,allowCustomAnswer:true,options:[
                {label:translations.t("design.optionLocal"),description:translations.t("design.optionLocalDetail"),value:"local"},
                {label:translations.t("design.optionRemote"),description:translations.t("design.optionRemoteDetail"),value:"remote"}]}]}})
          }
          Island.T3SessionCard {
            Layout.fillWidth:true;strings:translations;bridge:bridge;expanded:true
            row:({id:"working",title:translations.t("design.working"),project:"Island",status:"running",startedAt:Date.now()/1000-142,summary:"",requestId:"",request:null})
          }
          Island.PlainText {Layout.fillWidth:true;visible:text!=="";text:root.status;wrapMode:Text.Wrap;typeRole:"caption";color:Island.Design.secondaryText}
          Island.ActionButton {visible:root.answered;text:translations.t("design.reset");onClicked:{root.answered=false;root.status=""}}
        }
      }
    }
  }
}
