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
  readonly property bool showInstrument: shown && !editingPlan && mode !== "world"
  property double sampleTime: 0
  Timer {
    interval: 100; repeat: true; triggeredOnStart: true
    running: root.showInstrument && root.record.status === "running" && (root.mode === "stopwatch" || !Island.Preferences.reduceMotion)
    onTriggered: root.sampleTime = root.backend.clock()
  }
  readonly property double elapsedMs: backend ? Time.elapsed(record, Math.max(sampleTime,backend.now)) : 0
  function focusActivity(navigation) {
    editingPlan=false
    var target = presentation.activityTarget
    if (target && Time.modes.includes(target.mode)) mode = target.mode
    navigation.focusItem(mode==="world" ? tabs.itemAt(3) : editableDuration && !target ? duration : primary)
    return true
  }
  component TransportButton: Island.ActionButton {
    implicitWidth:Island.Design.controlHeight; implicitHeight:implicitWidth
    horizontalPadding:0; verticalPadding:0; iconSize:Style.font.iconLarge
    feedback:root.presentation ? root.presentation.feedback : null
  }
  ColumnLayout {
    id: body
    width: parent.width; spacing: Island.Design.gap.medium
    RowLayout {
      id:modeTabs
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
      Layout.preferredHeight:active ? Math.min(implicitHeight,Math.max(1,root.presentation.pageHeight-modeTabs.implicitHeight-body.spacing)) : 0
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
      implicitHeight:readout.implicitHeight + meter.implicitHeight + 3*Island.Design.gap.medium
      color:Island.Design.surface
      radius:Island.Design.cardRadius
      MouseArea {
        anchors.fill:parent
        enabled:duration.visible && duration.enabled
        cursorShape:Qt.IBeamCursor
        onClicked:{duration.forceActiveFocus(Qt.MouseFocusReason); duration.selectAll()}
      }
      Timers.BrailleTimeField {
        id:meter; objectName:"timeField"
        anchors.left:parent.left; anchors.right:parent.right; anchors.bottom:parent.bottom
        anchors.margins:Island.Design.gap.medium
        height:implicitHeight
        live:root.showInstrument
        mode:root.mode; onBreak:root.record.step%2===1
        seconds:Island.Preferences.reduceMotion ? 0 : root.elapsedMs/1000
        fraction:{
          if (root.mode!=="timer") return 0
          const progress=Math.min(1,root.elapsedMs/root.record.duration)
          return Island.Preferences.reduceMotion ? Math.floor(progress*4)/4 : progress
        }
      }
      ColumnLayout {
        id:readout
        anchors.top:parent.top; anchors.left:parent.left; anchors.right:parent.right
        anchors.margins:Island.Design.gap.medium
        spacing:Island.Design.gap.micro
        Island.PlainText {
          Layout.fillWidth:true; typeRole:"caption"; color:Island.Design.secondaryText; wrapMode:Text.Wrap
          text:root.mode === "pomodoro" ? root.t(Time.phase(root.record))+" · "+root.t("round").arg(Commons.I18n.formatNumber(1+Math.floor(root.record.step/2))).arg(Commons.I18n.formatNumber(root.cyclePlan.rounds))
              : root.t(root.record.status === "done" ? "timerDone" : root.record.status === "paused" ? "paused" : root.mode === "stopwatch" ? "elapsed" : root.editableDuration ? "duration" : "remaining")
        }
        RowLayout {
          Layout.fillWidth:true; spacing:Island.Design.gap.tight
          Item {
            Layout.fillWidth:true; Layout.minimumWidth:0
            implicitHeight:Math.max(Island.Design.lineHeight("hero"),Math.ceil(digitMetrics.height))
            FontMetrics { id:digitMetrics; font:reading.font }
            Island.DesignTextField {
              id:duration; objectName:"timeDuration"
              anchors.fill:parent; verticalAlignment:TextInput.AlignVCenter
              visible:root.editableDuration
              enabled:!!root.backend && root.backend.ready
              property int savedDuration:root.backend ? root.backend.records.timer.duration : 300000
              readonly property int milliseconds:Time.parseDuration(text,Commons.I18n.zeroDigit)
              text:Time.durationInput(savedDuration,Commons.I18n.formatNumber)
              inputMask:"99:99:99;_"
              inputMethodHints:Qt.ImhDigitsOnly
              TextMetrics {
                id:maskMetrics
                font.family:duration.font.family; font.weight:duration.font.weight
                font.pixelSize:Island.Design.type.hero; font.features:({"tnum":1})
                text:Time.durationInput(0,Commons.I18n.formatNumber)
              }
              font.pixelSize:Math.max(1,Math.min(Island.Design.type.hero,Math.floor(Island.Design.type.hero*(width-2)/Math.max(1,maskMetrics.advanceWidth))))
              font.weight:Island.Design.weight("hero")
              font.features:({"tnum":1})
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
              id:reading; objectName:"timeReading"
              anchors.fill:parent; verticalAlignment:Text.AlignVCenter
              typeRole:"hero"; font.features:({"tnum":1})
              fontSizeMode:Text.HorizontalFit; minimumPixelSize:Island.Design.type.title
              text: {
                if (root.mode === "stopwatch" && root.backend) {
                  var ms=root.elapsedMs
                  return Time.format(Math.floor(ms/1000),Commons.I18n.formatNumber) + Commons.I18n.decimal
                      + Commons.I18n.formatNumber(Math.floor(ms/100)%10)
                }
                return root.reading(root.mode)
              }
            }
          }
          TransportButton {
            id:planButton; objectName:"pomodoroSettings"
            visible:root.mode==="pomodoro"; iconText:"󰒓"; tooltipText:root.t("plan")
            onClicked:root.editingPlan=true
          }
          TransportButton {
            id:primary; objectName:"timePrimary"
            iconText:root.record.status === "running" ? Time.glyphs.pause : Time.glyphs.play
            variant:"primary"
            enabled:!!root.backend && root.backend.ready && (!root.editableDuration || !duration.invalid)
            tooltipText:root.t(root.record.status === "running" ? "pause" : root.record.status === "paused" ? "resume" : "start")
            onClicked:{
              forceActiveFocus()
              root.backend.toggle(root.mode,duration.milliseconds)
            }
          }
          TransportButton {
            objectName:"timeReset"
            enabled:!!root.backend && root.backend.ready && (root.record.status !== "idle" || root.record.step > 0)
            iconText:Time.glyphs.reset; tooltipText:root.t("reset")
            onClicked:root.backend.reset(root.mode)
          }
        }
      }
    }
  }
}
