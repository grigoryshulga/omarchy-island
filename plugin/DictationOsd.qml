import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PanelGeometry.js" as Geometry

Item {
  id: root
  required property var dictation
  required property Item anchorItem
  required property QtObject bar
  property bool open:dictation.showing
  property bool dismissed:false
  readonly property bool presented:open && !dismissed
  onOpenChanged:if(!open) dismissed=false
  Connections {
    target:root.dictation
    function onSessionIdChanged() {root.dismissed=false}
  }
  readonly property var anchorWindow:anchorItem ? anchorItem.QsWindow.window : null
  readonly property string position:bar ? bar.position : "top"
  readonly property real thickness:bar ? ("panelSize" in bar ? bar.panelSize : bar.barSize) : Style.bar.sizeHorizontal
  readonly property point anchorPosition: {
    anchorWatcher.transform
    return anchorWindow ? anchorItem.mapToItem(anchorWindow.contentItem,0,0) : Qt.point(0,0)
  }
  TransformWatcher {id:anchorWatcher;a:root.anchorWindow ? root.anchorWindow.contentItem : null;b:root.anchorItem}
  readonly property real shown: Preferences.reduceMotion ? (presented ? 1 : 0) : animatedShown
  property real animatedShown: 0
  Component.onCompleted:animatedShown=Qt.binding(function(){return root.presented ? 1 : 0})
  Behavior on animatedShown {
    NumberAnimation {
      duration:Preferences.duration(root.presented ? 280 : 190)
      easing.type:root.presented ? Easing.OutCubic : Easing.InOutQuad
    }
  }
  property var visibleState: ({recording:true,elapsed:0})
  // A provider can reset its timer before clearing showing in the same turn.
  // Commit its updates together and retain the last displayed state on exit.
  Binding on visibleState {
    when: root.presented
    value: ({recording:root.dictation.recording,elapsed:root.dictation.elapsed})
    delayed: true
    restoreMode: Binding.RestoreNone
  }
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("i18n")}
  PanelWindow {
    id: panel
    objectName:"islandDictationSurface"
    visible:root.presented || root.shown>0
    screen:root.anchorWindow ? root.anchorWindow.screen : null
    anchors {top:true;bottom:true;left:true;right:true}
    color:"transparent"
    exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"omarchy-island-popup"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
    mask:Region {item:root.presented && card.opacity>0 ? card : null}
    ContainerSurface {
      id:card
      objectName:"islandDictationOsd"
      readonly property real gap:Style.gapsOut
      readonly property var available:Geometry.available(root.position,parent.width,parent.height,root.thickness,gap)
      readonly property var targetOrigin:Geometry.origin(root.position,parent.width,parent.height,root.thickness,gap,width,height,root.anchorPosition.x+root.anchorItem.width/2,root.anchorPosition.y+root.anchorItem.height/2)
      x:Math.round(targetOrigin.x)
      y:Math.round(targetOrigin.y)
      width:Math.min(Style.space(256),available.width)
      height:Math.min(Math.max(Style.space(40),Design.lineHeight("caption")+2*Design.gap.tight),available.height)
      radius:Design.cardRadius
      color:Design.canvas
      borderSpec:Design.popupBorder
      transformOrigin:Item.Center
      scale:0.93+0.07*root.shown
      opacity:panel.screen && panel.width===panel.screen.width && panel.height===panel.screen.height ? root.shown : 0
      RowLayout {
        anchors.fill:parent
        anchors.leftMargin:Design.gap.medium
        anchors.rightMargin:Design.gap.medium
        spacing:Design.gap.tight
        LayoutMirroring.enabled:Commons.I18n.rightToLeft
        OpticalGlyph {
          objectName:"islandDictationIcon"
          Layout.preferredWidth:paintedSize
          Layout.preferredHeight:paintedSize
          Layout.alignment:Qt.AlignVCenter
          text:root.visibleState.recording ? "󰍬" : "󰔟"
          color:root.visibleState.recording ? Design.danger : Design.accent
          fontSize:Design.type.iconSmall
          paintedSize:Design.type.iconSmall
          Accessible.role:Accessible.StaticText
          Accessible.name:strings.t(root.visibleState.recording ? "dictation.listening" : "dictation.transcribing")
        }
        DictationField {
          objectName:"islandDictationField"
          Layout.fillWidth:true
          Layout.preferredHeight:Math.max(0,Math.min(Style.space(28),card.height-2*Design.gap.tight))
          history:root.dictation.history
          processing:!root.visibleState.recording
          active:root.presented && card.opacity>0
          reveal:root.shown
        }
        PlainText {
          objectName:"islandDictationTime"
          Layout.preferredWidth:Math.max(implicitWidth,Style.space(30))
          horizontalAlignment:Text.AlignTrailing
          readonly property var locale:Qt.locale(Commons.I18n.formatLocale)
          readonly property int seconds:root.visibleState.elapsed%60
          text:Math.floor(root.visibleState.elapsed/60).toLocaleString(locale,"f",0)+":"
            +(seconds<10 ? (0).toLocaleString(locale,"f",0) : "")+seconds.toLocaleString(locale,"f",0)
          color:Design.secondaryText
          font.features:({"tnum":1})
          typeRole:"caption"
        }
      }
      MouseArea {
        anchors.fill:parent
        enabled:root.presented
        acceptedButtons:Qt.RightButton
        onClicked:root.dismissed=true
      }
    }
  }
}
