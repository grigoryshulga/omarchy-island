import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "../.." as Island

ColumnLayout {
  id: root
  required property var backend
  required property var strings
  signal finished()
  function focusFirst() {fields.itemAt(0).spin.forceActiveFocus()}
  spacing:Island.Design.gap.small
  function t(key) {return strings.t("timers."+key)}
  RowLayout {
    Layout.fillWidth:true
    Island.SectionHeading {Layout.fillWidth:true; title:root.t("plan")}
    Island.ActionButton {
      objectName:"planDone"; iconText:"󰄬"; tooltipText:root.strings.t("overview.done")
      onClicked:root.finished()
    }
  }
  Repeater {
    id:fields; model:["rounds","focus","shortBreak","longBreak"]
    RowLayout {
      id:row
      readonly property alias spin:number.field
      required property string modelData
      readonly property string label:root.t(modelData==="rounds" ? "rounds" : "minutesLabel").replace("%1",root.t(modelData))
      Layout.fillWidth:true
      Island.PlainText {Layout.fillWidth:true; wrapMode:Text.Wrap; text:row.label}
      Ui.NumberField {
        id:number; objectName:"plan-"+row.modelData
        fieldWidth:Style.space(100)
        from:1; to:row.modelData==="rounds" ? 16 : 1440
        value:root.backend.pomodoroPlan[row.modelData]
        field.locale:Qt.locale(Commons.I18n.formatLocale)
        foreground:Island.Design.text; accent:Island.Design.accent
        Component.onCompleted:field.Accessible.name=Qt.binding(function(){return row.label})
        onModified:value=>root.backend.changePlan(row.modelData,value)
      }
    }
  }
  Island.PlainText {
    Layout.fillWidth:true; wrapMode:Text.Wrap; color:Island.Design.secondaryText; typeRole:"caption"
    visible:root.backend.records.pomodoro.status!=="idle" || root.backend.records.pomodoro.step!==0
    text:root.t("nextCycle")
  }
}
