import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../.." as Island
import "Time.mjs" as Time

Island.ModuleView {
  id: root
  property string mode: "timer"
  readonly property var record: backend ? backend.records[mode] : Time.initial()
  readonly property bool detail: !!presentation && presentation.detail
  readonly property bool editableDuration: mode === "timer" && (record.status === "idle" || record.status === "done")
  available: !!backend && !!presentation && (presentation.expanded || (presentation.hovering && !!backend.activeMode))
  implicitHeight: body.implicitHeight
  function t(key) { return presentation && presentation.strings ? presentation.strings.t("timers."+key) : "" }
  function reading(mode) {
    return backend ? Time.format(Time.reading(mode,backend.records[mode],backend.now), Commons.I18n.formatNumber) : ""
  }
  readonly property bool stopwatchVisible: mode === "stopwatch" && detail && visible && presentation.active
  property double sampleTime: 0
  Timer {
    interval: 100; repeat: true; triggeredOnStart: true
    running: root.stopwatchVisible && root.record.status === "running"
    onTriggered: root.sampleTime = root.backend.clock()
  }
  function focusActivity(navigation) {
    var target = presentation.activityTarget
    if (target && Time.modes.includes(target.mode)) mode = target.mode
    navigation.focusItem(primary)
    return true
  }
  ColumnLayout {
    id: body
    width: parent.width; spacing: Island.Design.gap.medium
    Island.SectionLink {
      objectName: "openTimeTools"
      visible: !root.detail; Layout.fillWidth: true
      title: root.t("title")
      detail: root.backend && root.backend.activeMode ? root.t(root.backend.activeMode)+" · "+root.reading(root.backend.activeMode) : "›"
      Accessible.name: [title,detail === "›" ? "" : detail].filter(Boolean).join(" · ")
      focusable: !!root.presentation && root.presentation.expanded
      feedback: root.presentation ? root.presentation.feedback : null
      onClicked: root.presentation.expanded ? root.detailsRequested() : root.expandRequested()
    }
    RowLayout {
      visible: root.detail; Layout.fillWidth: true; spacing: Island.Design.gap.tight
      Repeater {
        model: Time.modes
        Island.ActionButton {
          required property string modelData
          objectName: "timeMode-"+modelData
          Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.minimumWidth: 0
          text: root.t(modelData); selected: root.mode === modelData; bordered: selected
          Accessible.role: Accessible.RadioButton; Accessible.checked: selected
          feedback: root.presentation ? root.presentation.feedback : null
          onClicked: root.mode = modelData
        }
      }
    }
    Island.PlainText {
      Layout.fillWidth: true; visible: root.detail && (root.mode === "pomodoro" || root.record.status === "paused" || root.record.status === "done")
      text: root.mode === "pomodoro" ? root.t(Time.phase(root.record.step))+" · "+root.t("round").arg(Commons.I18n.formatNumber(1+Math.floor(root.record.step/2)))
          : root.t(root.record.status === "done" ? "timerDone" : "paused")
      typeRole: "label"; color: Island.Design.secondaryText; horizontalAlignment: Text.AlignHCenter
    }
    Island.PlainText {
      objectName: "timeReading"; Layout.fillWidth: true; visible: root.detail
      text: {
        if (root.mode === "stopwatch" && root.backend) {
          var ms = Time.elapsed(root.record, Math.max(root.sampleTime,root.backend.now))
          return Time.format(Math.floor(ms/1000),Commons.I18n.formatNumber) + Commons.I18n.decimal
              + Commons.I18n.formatNumber(Math.floor(ms/100)%10)
        }
        if (root.editableDuration && root.record.status === "idle" && !duration.invalid)
          return Time.format(Time.parseDuration(duration.text)/1000,Commons.I18n.formatNumber)
        return root.reading(root.mode)
      }
      horizontalAlignment: Text.AlignHCenter; typeRole: "hero"
    }
    RowLayout {
      visible: root.detail && root.editableDuration; Layout.fillWidth: true; spacing: Island.Design.gap.small
      Island.PlainText {Layout.fillWidth:true; text:root.t("duration"); wrapMode:Text.Wrap; typeRole:"label"}
      Island.DesignTextField {
        id: duration
        objectName: "timeDuration"
        Layout.preferredWidth: Style.space(94)
        property int savedDuration: root.backend ? root.backend.records.timer.duration : 300000
        text: Time.durationInput(savedDuration)
        Accessible.name: root.t("duration")
        maximumLength: 7
        validator: RegularExpressionValidator { regularExpression: /[0-9]{1,4}(:[0-5][0-9])?/ }
        invalid: !acceptableInput || !Time.parseDuration(text)
        onAccepted: if (root.backend && !invalid) {
          root.backend.toggle("timer",Time.parseDuration(text))
          primary.forceActiveFocus()
        }
      }
    }
    RowLayout {
      visible: root.detail; Layout.fillWidth: true; spacing: Island.Design.gap.small
      Island.ActionButton {
        id: primary; objectName: "timePrimary"; Layout.fillWidth:true
        variant: "primary"; compact:false
        enabled: !!root.backend && root.backend.ready && (!root.editableDuration || !duration.invalid)
        text: root.t(root.record.status === "running" ? "pause" : root.record.status === "paused" ? "resume" : "start")
        feedback: root.presentation ? root.presentation.feedback : null
        onClicked: root.backend.toggle(root.mode, Time.parseDuration(duration.text))
      }
      Island.ActionButton {
        objectName: "timeReset"; compact:false
        enabled: !!root.backend && root.backend.ready && (root.record.status !== "idle" || root.record.step > 0)
        text: root.t("reset"); feedback: root.presentation ? root.presentation.feedback : null
        onClicked: root.backend.reset(root.mode)
      }
    }
  }
}
