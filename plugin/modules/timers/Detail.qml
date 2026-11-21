import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../.." as Island
import "." as Timers
import "Time.mjs" as Time

Island.ModuleView {
  id: root
  property string mode: "timer"
  property bool editingPlan:false
  readonly property var record:backend && backend.records[mode] || Time.initial()
  readonly property bool shown:visible && !!presentation && presentation.active
  onShownChanged:if(!shown) editingPlan=false
  onModeChanged:editingPlan=false
  function back() {
    if (!editingPlan) return false
    editingPlan=false
    planButton.forceActiveFocus()
    return true
  }
  readonly property var cyclePlan:record.plan || Time.defaultPlan
  readonly property bool editableDuration: mode === "timer" && (record.status === "idle" || record.status === "done")
  available: !!backend && !!presentation
  implicitHeight: body.implicitHeight
  function t(key) { return presentation && presentation.strings ? presentation.strings.t("timers."+key) : "" }
  function reading(mode) {
    return backend && backend.records[mode] ? Time.format(Time.reading(mode,backend.records[mode],backend.now), Commons.I18n.formatNumber) : ""
  }
  readonly property bool stopwatchVisible: mode === "stopwatch" && visible && !!presentation && presentation.active
  property double sampleTime: 0
  Timer {
    interval: 100; repeat: true; triggeredOnStart: true
    running: root.stopwatchVisible && root.record.status === "running"
    onTriggered: root.sampleTime = root.backend.clock()
  }
  readonly property double elapsedMs: backend ? Time.elapsed(record, backend.now) : 0
  readonly property real fraction: mode === "world" ? 0 : mode === "stopwatch" ? (Math.floor(elapsedMs/1000)%60)/60
      : Math.min(1,elapsedMs / Time.limit(mode,record))
  function focusActivity(navigation) {
    editingPlan=false
    var target = presentation.activityTarget
    if (target && Time.modes.includes(target.mode)) mode = target.mode
    navigation.focusItem(mode==="world" ? tabs.itemAt(3) : editableDuration && !target ? duration : primary)
    return true
  }
  ColumnLayout {
    id: body
    width: parent.width; spacing: Island.Design.gap.medium
    RowLayout {
      Layout.fillWidth: true; spacing: Island.Design.gap.tight
      Repeater {
        id:tabs; model: Time.modes.concat(["world"])
        Island.ActionButton {
          id:tab
          required property string modelData
          objectName: "timeMode-"+modelData
          Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.minimumWidth: 0
          implicitHeight:Math.max(Island.Design.controlHeight,tabLabel.implicitHeight+2*Island.Design.gap.tight)
          tooltipText:root.t(modelData)
          Accessible.name:tooltipText
          Column {
            id:tabLabel; anchors.centerIn:parent; width:parent.width
            Island.PlainText {
              width:parent.width; horizontalAlignment:Text.AlignHCenter
              text:Time.glyphs[tab.modelData]; color:tab.selected ? Island.Design.selectedText : Island.Design.secondaryText
              Accessible.ignored:true
            }
            Island.PlainText {
              visible:root.width>=Style.space(300); width:parent.width
              typeRole:"caption"; horizontalAlignment:Text.AlignHCenter
              text:root.t(tab.modelData==="world" ? "worldShort" : tab.modelData)
              Accessible.ignored:true
            }
          }
          selected:root.mode===modelData; bordered:selected
          Accessible.role: Accessible.RadioButton; Accessible.checked: selected
          feedback: root.presentation ? root.presentation.feedback : null
          onClicked: root.mode = modelData
        }
      }
    }
    Loader {
      Layout.fillWidth:true
      Layout.preferredHeight:active ? Math.max(Style.space(160),root.presentation.pageHeight-Style.space(112)) : 0
      active:root.shown && root.mode==="world" && !!root.backend && root.backend.ready
      visible:active
      sourceComponent:Timers.WorldClock {
        backend:root.backend; presentation:root.presentation
        onReturnToTabs:tabs.itemAt(3).forceActiveFocus()
        onClosed:root.closeRequested()
      }
    }
    Loader {
      Layout.fillWidth:true
      active:root.editingPlan && !!root.backend; visible:active
      sourceComponent:Timers.PomodoroSettings {
        backend:root.backend; strings:root.presentation.strings
        onFinished:root.back()
      }
      onLoaded:Qt.callLater(function(){if(item) item.focusFirst()})
    }
    Rectangle {
      visible:root.mode!=="world" && !root.editingPlan
      Layout.fillWidth:true
      implicitHeight:Math.max(meter.implicitHeight,readout.implicitHeight,actions.implicitHeight) + 2*Island.Design.gap.medium
      color:Island.Design.surface
      radius:Island.Design.cardRadius
      MouseArea {
        anchors.fill:parent
        enabled:duration.visible && duration.enabled
        cursorShape:Qt.IBeamCursor
        onClicked:{duration.forceActiveFocus(Qt.MouseFocusReason); duration.selectAll()}
      }
      RowLayout {
        anchors.fill:parent; anchors.margins:Island.Design.gap.medium
        spacing:Island.Design.gap.medium
        Timers.TimePrint {
          id:meter; objectName:"timePrint"
          implicitWidth:Style.space(88); implicitHeight:implicitWidth
          Layout.preferredWidth:Math.min(implicitWidth,root.width*0.24)
          Layout.preferredHeight:Layout.preferredWidth
          mode:root.mode; step:root.record.step; rounds:root.cyclePlan.rounds
          live:root.shown && visible
          fraction: {
            if (!Island.Preferences.reduceMotion || root.record.status !== "running") return root.fraction
            return root.mode === "stopwatch" ? 0 : Math.floor(root.fraction*4)/4
          }
        }
        ColumnLayout {
          id:readout
          Layout.fillWidth:true; Layout.minimumWidth:0; spacing:Island.Design.gap.micro
          RowLayout {
            Layout.fillWidth:true; spacing:Island.Design.gap.micro
            Island.PlainText {
            Layout.fillWidth:true; typeRole:"caption"; color:Island.Design.secondaryText; wrapMode:Text.Wrap
            text:root.mode === "pomodoro" ? root.t(Time.phase(root.record))+" · "+root.t("round").arg(Commons.I18n.formatNumber(1+Math.floor(root.record.step/2))).arg(Commons.I18n.formatNumber(root.cyclePlan.rounds))
                : root.t(root.record.status === "done" ? "timerDone" : root.record.status === "paused" ? "paused" : root.mode === "stopwatch" ? "elapsed" : root.editableDuration ? "duration" : "remaining")
            }
            Island.ActionButton {
              id:planButton; objectName:"pomodoroSettings"
              visible:root.mode==="pomodoro"; iconText:"󰒓"; tooltipText:root.t("plan")
              implicitWidth:Island.Design.compactControlHeight; horizontalPadding:0
              onClicked:root.editingPlan=true
            }
          }
          Island.DesignTextField {
            id:duration; objectName:"timeDuration"
            Layout.fillWidth:true; Layout.minimumWidth:0
            visible:root.editableDuration
            enabled:!!root.backend && root.backend.ready
            property int savedDuration:root.backend ? root.backend.records.timer.duration : 300000
            readonly property int milliseconds:Time.parseDuration(text,Commons.I18n.zeroDigit)
            text:Time.durationInput(savedDuration,Commons.I18n.formatNumber)
            maximumLength:7
            inputMethodHints:Qt.ImhPreferNumbers
            font.pixelSize:Island.Design.type.hero; font.weight:Island.Design.weight("hero")
            font.features:({"tnum":1})
            implicitHeight:Island.Design.lineHeight("hero")
            leftPadding:0; rightPadding:0; topPadding:0; bottomPadding:0
            invalid:milliseconds===0
            Accessible.name:root.t("duration")
            Accessible.description:root.t("durationHint")
            onActiveFocusChanged:if(activeFocus) Qt.callLater(function(){if(duration.activeFocus) duration.selectAll()})
            onAccepted:if(primary.enabled) primary.clicked()
            background:Item {
              Rectangle {
                anchors.bottom:parent.bottom; width:parent.width; height:1
                color:duration.invalid ? Island.Design.danger : Island.Design.focusRing
                visible:duration.hovered || duration.activeFocus || duration.invalid
              }
            }
          }
          Island.PlainText {
            visible:!root.editableDuration
            objectName:"timeReading"; Layout.fillWidth:true; Layout.minimumWidth:0
            typeRole:"hero"; font.features:({"tnum":1})
            fontSizeMode:Text.HorizontalFit; minimumPixelSize:Island.Design.type.title
            text: {
              if (root.mode === "stopwatch" && root.backend) {
                var ms=Time.elapsed(root.record,Math.max(root.sampleTime,root.backend.now))
                return Time.format(Math.floor(ms/1000),Commons.I18n.formatNumber) + Commons.I18n.decimal
                    + Commons.I18n.formatNumber(Math.floor(ms/100)%10)
              }
              return root.reading(root.mode)
            }
          }
        }
        ColumnLayout {
          id:actions; spacing:Island.Design.gap.tight
          Island.ActionButton {
            id:primary; objectName:"timePrimary"
            implicitWidth:Island.Design.controlHeight; implicitHeight:implicitWidth
            horizontalPadding:0; verticalPadding:0; iconSize:Style.font.iconLarge
            iconText:root.record.status === "running" ? Time.glyphs.pause : Time.glyphs.play
            variant:"primary"
            enabled:!!root.backend && root.backend.ready && (!root.editableDuration || !duration.invalid)
            tooltipText:root.t(root.record.status === "running" ? "pause" : root.record.status === "paused" ? "resume" : "start")
            feedback:root.presentation ? root.presentation.feedback : null
            onClicked:{
              forceActiveFocus()
              root.backend.toggle(root.mode,duration.milliseconds)
            }
          }
          Island.ActionButton {
            objectName:"timeReset"
            implicitWidth:Island.Design.controlHeight; implicitHeight:implicitWidth
            horizontalPadding:0; verticalPadding:0; iconSize:Style.font.iconLarge
            enabled:!!root.backend && root.backend.ready && (root.record.status !== "idle" || root.record.step > 0)
            iconText:Time.glyphs.reset; tooltipText:root.t("reset")
            feedback:root.presentation ? root.presentation.feedback : null
            onClicked:root.backend.reset(root.mode)
          }
        }
      }
    }
  }
}
