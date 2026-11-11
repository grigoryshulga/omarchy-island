import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root
  required property var dictation
  required property Item anchorItem
  required property QtObject bar
  property bool open:dictation.showing
  readonly property var anchorWindow:anchorItem ? anchorItem.QsWindow.window : null
  readonly property string position:bar ? bar.position : "top"
  readonly property real thickness:bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property point anchorPosition: {
    anchorWatcher.transform
    return anchorWindow ? anchorItem.mapToItem(anchorWindow.contentItem,0,0) : Qt.point(0,0)
  }
  TransformWatcher {id:anchorWatcher;a:root.anchorWindow ? root.anchorWindow.contentItem : null;b:root.anchorItem}
  property real shown: 0
  Component.onCompleted:shown=Qt.binding(function(){return root.open ? 1 : 0})
  Behavior on shown {NumberAnimation {duration:Preferences.duration(root.open ? 220 : 180);easing.type:Easing.OutCubic}}
  Commons.Translations {id:strings;directory:Qt.resolvedUrl("i18n")}
  PanelWindow {
    id: panel
    objectName:"islandDictationSurface"
    visible:root.open || root.shown>0
    screen:root.anchorWindow ? root.anchorWindow.screen : null
    anchors {top:true;bottom:true;left:true;right:true}
    color:"transparent"
    exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"island-dictation"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
    mask:Region {}
    BorderSurface {
      id:card
      objectName:"islandDictationOsd"
      readonly property bool vertical:root.position==="left" || root.position==="right"
      readonly property real gap:Style.gapsOut
      x:Math.round(Math.max(gap,Math.min(parent.width-width-gap,vertical ? (root.position==="right" ? parent.width-root.thickness-gap-width : root.thickness+gap) : root.anchorPosition.x+root.anchorItem.width/2-width/2)))
      y:Math.round(Math.max(gap,Math.min(parent.height-height-gap,vertical ? root.anchorPosition.y+root.anchorItem.height/2-height/2 : (root.position==="bottom" ? parent.height-root.thickness-gap-height : root.thickness+gap))))-Style.space(6)*(1-root.shown)
      width:Math.min(Style.space(320),parent.width-Style.space(24))
      height:Style.space(88)
      radius:Style.cornerRadius
      color:Util.alpha(Commons.Color.background,0.97)
      borderSpec:Border.surfaceSpec("popups","border",Commons.Color.popups.border,Math.max(1,Style.space(1)))
      opacity:panel.screen && panel.width===panel.screen.width && panel.height===panel.screen.height ? root.shown : 0
      ColumnLayout {
        anchors.fill:parent
        anchors.margins:Style.space(14)
        spacing:Style.space(5)
        RowLayout {
          Layout.fillWidth:true
          spacing:Style.space(7)
          PlainText {text:root.dictation.recording ? "󰍬" : "󰔟";color:Commons.Color.accent;font.pixelSize:Style.font.icon}
          PlainText {
            objectName:"islandDictationLabel"
            Layout.fillWidth:true
            text:strings.t(root.dictation.recording ? "dictation.listening" : "dictation.transcribing")
            font.pixelSize:Style.font.bodySmall
          }
          PlainText {
            text:Math.floor(root.dictation.elapsed/60)+":"+String(root.dictation.elapsed%60).padStart(2,"0")
            color:Commons.Color.accent
            font.pixelSize:Style.font.bodySmall
          }
        }
        DictationField {
          objectName:"islandDictationField"
          Layout.fillWidth:true
          Layout.fillHeight:true
          history:root.dictation.history
          processing:!root.dictation.recording
          active:panel.visible
        }
      }
    }
  }
}
