import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
import "Island/sdk" 1.0 as UI
import "Island/ModuleCatalog.mjs" as Catalog
import "Island/SettingsModel.mjs" as Settings

ShellRoot {
  Island.ModuleRegistry { id: registry; definitions: [Catalog.definition("example")] }
  ModuleHost { id: service; registry: registry }
  Commons.Translations { id: translations; directory: Qt.resolvedUrl("Island/i18n") }
  QtObject {
    id: feedback
    property int pulses: 0
    function pulseFrom(item) { pulses++ }
  }
  FloatingWindow {
    visible: true; implicitWidth: 1000; implicitHeight: 900
    Island.IslandContent { id: first; width: 320; height: 900; service: service; strings: translations; expanded: true }
    Island.IslandContent { id: second; x: 330; width: 320; height: 900; service: service; strings: translations; expanded: true }
    Components { id: components; x: 660; width: 320; strings: translations; feedback: feedback }
    Island.KeyboardNavigation { id: navigation; scope: components; containers: [components] }
    Island.ModuleSlot {
      id: inert
      viewSource: Catalog.definition("example").overview
      backend: null
      presentation: null
      visible: false
    }
    Island.ModuleSlot {
      id: indicator
      viewSource: Catalog.definition("example").indicator
      backend: registry.backends.example || null
      presentation: QtObject { property var strings: translations }
    }
    TestCase {
      id: test; when: false
      function test_sdk() {
        // Compile the real host without instantiating services or desktop surfaces.
        var host = Qt.createComponent(Qt.resolvedUrl("Island/BarWidget.qml"))
        var errors = host.errorString().trim().split("\n")
        // Offscreen cannot create layer-shell types. Accept only that dependency
        // error; syntax errors such as a duplicate moduleStrings must fail.
        verify(host.status === Component.Ready || (errors.length === 2
            && errors[0].endsWith("Type IslandPopup unavailable")
            && errors[1].endsWith("No PanelWindow backend loaded.")), host.errorString())
        tryVerify(function() { return !!registry.backends.example })
        var state = registry.backends.example
        tryVerify(function() { return !!inert.item })
        compare(inert.item.backend, null); verify(!inert.available)
        verify(!findChild(inert, "exampleAction").enabled)
        compare(UI.Settings.get("exampleEnabled"), false)
        verify(Settings.valid("exampleEnabled", true))
        verify(!indicator.available)
        state.increment(); compare(state.count, 0)
        Island.Preferences.values = {exampleEnabled: true}
        tryVerify(function() { return indicator.available })
        compare(indicator.tooltip, translations.t("example.title"))
        var left = findChild(first, "exampleOverview"), right = findChild(second, "exampleOverview")
        verify(left !== right); compare(left.backend, right.backend)
        var button = findChild(left, "exampleAction")
        first.expanded = false; first.hovering = false
        for (var kind of ["notification", "t3", "media", ""]) {
          first.alertKind = kind; wait(30)
          verify(!left.visible && !left.available, "Template leaked into toast: " + kind)
          compare(first.implicitHeight, 0)
        }
        first.hovering = true; wait(30)
        verify(left.visible && left.available); verify(!button.enabled)
        first.hovering = false; first.alertKind = ""
        first.expanded = true; wait(30); verify(button.enabled)
        button.forceActiveFocus(); button.clicked(); wait(40)
        compare(first.detailPage, "example"); compare(second.detailPage, "")
        var draft = findChild(left, "exampleDraft")
        draft.text = "keep <b>draft</b>"
        button.clicked(); compare(state.count, 1)
        compare(findChild(right, "exampleDraft").text, "")
        verify(first.back()); wait(40); verify(button.activeFocus)
        button.clicked(); wait(40); compare(draft.text, "keep <b>draft</b>")
        Island.Preferences.values = {exampleEnabled: false}; wait(40)
        compare(first.detailPage, ""); verify(!indicator.available)
        state.increment(); compare(state.count, 1)
        Island.Preferences.values = {exampleEnabled: true}; wait(40)
        compare(registry.backends.example, state); compare(state.count, 1)
        compare(service.actions.length, 0)

        var input = findChild(components, "sdkField")
        input.text = "draft"; input.forceActiveFocus()
        var oldHeight = input.implicitHeight
        Commons.Style.fontOverrides = ({})
        Commons.Style.fontBaseSize *= 1.5; wait(30)
        verify(input.implicitHeight > oldHeight)
        Commons.Color.popups.background = "#f5f5ef"; Commons.Color.popups.text = "#22222a"
        wait(30); compare(UI.Design.surface, Island.Design.surface); compare(components.color, UI.Design.surface)
        compare(input.text, "draft"); verify(input.activeFocus)
        Commons.Style.cornerRadius = 0; compare(components.radius, 0)
        var spinner = findChild(components, "sdkSpinner")
        tryVerify(function() { return spinner.animating })
        components.visible = false; wait(30); verify(!spinner.animating)
        components.visible = true
        Island.Preferences.values = {animationsEnabled: false}
        wait(30); verify(UI.Motion.reduceMotion); compare(UI.Motion.duration(200), 0)
        compare(UI.Design.transitionDuration, 0); verify(!spinner.animating)
        var toggle = findChild(components, "sdkSwitch")
        var slider = findChild(components, "sdkSlider")
        toggle.interactive = false; wait(30)
        verify(!toggle.activeFocusOnTab)
        verify(navigation.candidates().indexOf(toggle) < 0)
        slider.forceActiveFocus(); navigation.tab(-1)
        verify(!toggle.activeFocus, "Tab must skip a noninteractive switch")
        toggle.interactive = true; wait(30)
        slider.forceActiveFocus(); navigation.tab(-1); verify(toggle.activeFocus)
        toggle.interactive = false; wait(30)
        verify(slider.activeFocus, "Disabling interaction must move focus to the next control")
        verify(!toggle.activeFocusOnTab && navigation.candidates().indexOf(toggle) < 0)
        toggle.interactive = true; wait(30)
        toggle.forceActiveFocus(); keyClick(Qt.Key_Space); verify(toggle.checked)
        toggle.busy = true; keyClick(Qt.Key_Space); verify(toggle.checked)
        toggle.busy = false; keyClick(Qt.Key_Return); verify(!toggle.checked)
        slider.forceActiveFocus(); var before = components.progress
        keyClick(Qt.Key_Right); verify(components.progress > before)
        var action = findChild(components, "sdkButton")
        action.forceActiveFocus(); keyClick(Qt.Key_Return); compare(feedback.pulses, 1)
        var dropdown = findChild(components, "sdkDropdown")
        dropdown.open(); tryVerify(function() { return dropdown.popupOpen })
        keyClick(Qt.Key_Escape); tryVerify(function() { return !dropdown.popupOpen })
        console.log("UI_SDK_PASS"); Qt.quit()
      }
    }
    Timer { interval: 150; running: true; onTriggered: { try { test.test_sdk() } catch(error) { console.log("MODULES_FAIL", error.stack); Qt.quit() } } }
    Timer { interval: 9000; running: true; onTriggered: { console.log("MODULES_FAIL timeout"); Qt.quit() } }
  }
}
