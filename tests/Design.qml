import QtQuick
import QtQuick.Layouts
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/DesignTokens.js" as Tokens

ShellRoot {
  FloatingWindow {
    visible:true;implicitWidth:700;implicitHeight:700
    color:Island.Design.opaqueCanvas
    ColumnLayout {
      anchors.fill:parent;anchors.margins:16
      Island.PlainText {id:title;typeRole:"section";text:"Заголовок / Title"}
      Island.DesignTextField {id:input;Layout.fillWidth:true;text:"Черновик $ & <b>";placeholderText:"Answer"}
      Island.FeedbackButton {id:selectedButton;text:"Выбранный вариант";selected:true;focusable:true}
      Island.ChoiceButton {id:choice;Layout.fillWidth:true;label:"Длинный вариант с пояснением сохраняет все слова даже при увеличении размера шрифта";description:"Описание не обрезается многоточием";onClicked:selected=!selected}
      Island.T3Spinner {id:spinner;active:true}
      Island.Surface {id:surface;Layout.fillWidth:true;implicitHeight:60}
      Item {Layout.fillHeight:true}
    }
    TestCase {
      id:test;when:false
      function test_design() {
        var originalSize=Commons.Style.fontBaseSize
        input.forceActiveFocus();var draft=input.text
        // Deliberately bad native selected-color overrides must not leak into text.
        Commons.Style.styleOverrides=Object.assign({},Commons.Style.styleOverrides,{"selected-color":"#aaaaaa"})
        for(var palette of [
          {bg:"#11151a",fg:"#eeeef2",accent:"#9aaaff",muted:"#555555"},
          {bg:"#f5f5ef",fg:"#22222a",accent:"#3855a8",muted:"#aaaaaa"},
          {bg:"#191919",fg:"#eeeeee",accent:"#888888",muted:"#333333"}
        ]) {
          Commons.Color.background=palette.bg;Commons.Color.foreground=palette.fg
          Commons.Color.popups.background=palette.bg;Commons.Color.popups.text=palette.fg
          Commons.Color.accent=palette.accent;Commons.Color.muted=palette.muted
          wait(30)
          verify(Tokens.contrast(Island.Design.text,Island.Design.surface)>=4.5)
          verify(Tokens.contrast(Island.Design.secondaryText,Island.Design.raised)>=4.5,"Secondary contrast: "+Tokens.contrast(Island.Design.secondaryText,Island.Design.raised))
          verify(Tokens.contrast(selectedButton._selectedColor,Island.Design.selection)>=4.5,"Selected label lost contrast")
          verify(Tokens.contrast(Island.Design.selectedSecondaryText,Island.Design.selection)>=4.5,"Selected description lost contrast")
          compare(input.text,draft);verify(input.activeFocus,"Theme change stole editor focus")
          compare(surface.border.width,0)
        }
        // Exercise base scaling independently of explicit user/theme font sizes.
        Commons.Style.fontOverrides=({});wait(30)
        var before=title.font.pixelSize,height=input.implicitHeight
        Commons.Style.fontBaseSize=originalSize*1.5;wait(30)
        verify(title.font.pixelSize>before && input.implicitHeight>height,"Typography and controls must scale together")
        compare(input.text,draft)
        Commons.Style.cornerRadius=0
        compare(surface.radius,0);compare(selectedButton.radius,0);compare(input.background.radius,0)
        Commons.Style.cornerRadius=16
        verify(surface.radius>selectedButton.radius && selectedButton.radius>0)
        Commons.Style.reduceMotion=true
        verify(!spinner.animating && Island.Design.feedbackDuration===0)
        Commons.Style.reduceMotion=false
        verify(spinner.animating)
        spinner.visible=false;verify(!spinner.animating)
        choice.forceActiveFocus();keyClick(Qt.Key_Return);verify(choice.selected)
        choice.enabled=false;keyClick(Qt.Key_Return);verify(choice.selected,"Disabled choice accepted an action")
        compare(input.text,draft)
        console.log("DESIGN_PASS");Qt.quit()
      }
    }
    Timer {interval:300;running:true;onTriggered:{try {test.test_design()} catch(error) {console.log("DESIGN_FAIL",error.stack);Qt.quit()}}}
    Timer {interval:7000;running:true;onTriggered:{console.log("DESIGN_TIMEOUT");Qt.quit()}}
  }
}
