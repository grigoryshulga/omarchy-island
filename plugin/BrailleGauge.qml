import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

Item {
  id: root
  property string kind: "volume"
  property real value: 0
  property bool muted: false
  property bool hasProgress: true
  property string glyph: ""
  property string message: ""
  property string valueText: ""
  property real progress: Math.max(0,Math.min(1,value))
  property bool animateEvents: false
  property bool eventReady: false
  property bool eventWasProgress: true
  property var currentEvent: ({glyph:"",message:"",kind:"message"})
  property var pendingEvent: ({glyph:"",message:"",kind:"message"})
  property real eventShown: 1
  readonly property bool eventTransitioning: eventSwap.running
  readonly property string displayGlyph: glyph || (kind==="brightness" ? "󰃠" : muted || value<=0 ? "󰝟" : "󰕾")
  property real eventWidth: Math.min(width,eventRow.implicitWidth)
  Behavior on eventWidth {enabled:root.animateEvents && !root.hasProgress;NumberAnimation {duration:Preferences.duration(160);easing.type:Easing.OutCubic}}
  readonly property real contentWidth: hasProgress ? width : Math.min(width,eventWidth)
  implicitWidth: hasProgress ? progressRow.implicitWidth : eventRow.implicitWidth
  implicitHeight: Style.space(18)
  Behavior on progress {NumberAnimation {duration:Preferences.duration(90);easing.type:Easing.OutCubic}}
  function sameEvent(a,b) {return a.glyph===b.glyph && a.message===b.message && a.kind===b.kind}
  function syncEvent() {
    if(!eventReady) return
    var next={glyph:displayGlyph,message:message,kind:kind}
    pendingEvent=next
    var immediate=hasProgress || eventWasProgress || !animateEvents || Preferences.reduceMotion
    eventWasProgress=hasProgress
    // Let an in-flight message dissolve finish under the clock's exit fade;
    // resetting its opacity here would flash the new text at full strength.
    if(!animateEvents && eventSwap.running && !hasProgress && !Preferences.reduceMotion) return
    if(immediate) {eventSwap.stop();currentEvent=next;eventShown=1}
    else if(!eventSwap.running && !sameEvent(currentEvent,next)) eventSwap.start()
  }
  function scheduleEvent() {if(eventReady) Qt.callLater(syncEvent)}
  Component.onCompleted: {eventReady=true;syncEvent()}
  onDisplayGlyphChanged: scheduleEvent()
  onMessageChanged: scheduleEvent()
  onKindChanged: scheduleEvent()
  onHasProgressChanged: scheduleEvent()
  onAnimateEventsChanged: syncEvent()
  Connections {target:Preferences;function onReduceMotionChanged() {root.syncEvent()}}
  SequentialAnimation {
    id:eventSwap
    NumberAnimation {target:root;property:"eventShown";to:0;duration:Preferences.duration(80);easing.type:Easing.OutCubic}
    ScriptAction {script:root.currentEvent=root.pendingEvent}
    NumberAnimation {target:root;property:"eventShown";to:1;duration:Preferences.duration(120);easing.type:Easing.OutCubic}
    onFinished:Qt.callLater(root.syncEvent)
  }
  RowLayout {
    id: progressRow
    anchors.fill: parent
    visible: root.hasProgress
    spacing: Style.space(6)
    PlainText {text:root.displayGlyph;font.pixelSize:Style.font.icon;color:Commons.Color.accent}
    ShaderEffect {
      objectName:"brailleGaugeField"
      Layout.fillWidth:true
      Layout.preferredWidth:Style.space(100)
      Layout.preferredHeight:Style.space(14)
      property vector2d size:Qt.vector2d(width,height)
      property real amount:root.progress
      property color accent:Commons.Color.accent
      vertexShader:Qt.resolvedUrl("shaders/gauge.vert.qsb")
      fragmentShader:Qt.resolvedUrl("shaders/gauge.frag.qsb")
    }
    PlainText {Layout.maximumWidth:Style.space(70);Layout.preferredWidth:Math.min(Style.space(70),Math.max(percentMeasure.implicitWidth,implicitWidth));elide:Text.ElideRight;horizontalAlignment:Text.AlignRight;text:root.valueText || Commons.I18n.formatNumber(Math.round(root.value*100))+"%";font.pixelSize:Style.font.bodySmall}
  }
  RowLayout {
    id: eventRow
    objectName:"islandOsdEvent"
    anchors.centerIn: parent
    width: Math.min(parent.width,implicitWidth)
    height: parent.height
    visible: !root.hasProgress
    opacity: root.eventShown
    spacing: Style.space(6)
    layer.enabled: GraphicsInfo.api!==GraphicsInfo.Software
    layer.effect: root.eventTransitioning ? eventDissolve : null
    Component {id:eventDissolve;BrailleDissolve {amount:1-root.eventShown}}
    PlainText {
      objectName:"islandOsdEventIcon"
      text:root.currentEvent.glyph
      font.pixelSize:Style.font.icon
      color:Commons.Color.accent
    }
    PlainText {
      objectName:"islandOsdMessage"
      Layout.fillWidth:true
      Layout.minimumWidth:0
      visible:root.currentEvent.message!==""
      text:root.currentEvent.message
      font.bold:root.currentEvent.kind==="layout"
      font.pixelSize:Style.font.body
    }
  }
  PlainText {id:percentMeasure;visible:false;text:Commons.I18n.formatNumber(100)+"%";font.pixelSize:Style.font.bodySmall}
}
