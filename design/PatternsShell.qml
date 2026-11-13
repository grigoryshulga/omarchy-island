import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons as Commons
import "Island" as Island

ShellRoot {
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  FloatingWindow {
    id: window
    title: "Island · UI patterns"
    implicitWidth: 740; implicitHeight: 1100
    color: Island.Design.opaqueCanvas
    Controls.ScrollView {
      id: viewport
      anchors.fill: parent
      contentWidth: availableWidth
      Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
      Patterns { id: gallery; width: Math.min(viewport.availableWidth, window.previewWidth); height: implicitHeight; strings: strings }
    }
    Timer { interval:15000; running:Quickshell.env("ISLAND_DESIGN_CAPTURE")!==""; onTriggered:{console.log("PATTERNS_CAPTURE_FAIL timeout");Qt.quit()} }
    property int previewWidth: 740
    property int captureIndex: 0
    property var captures: ["dark-ready", "dark-focus", "dark-loading", "dark-error", "dark-empty", "dark-disabled", "light-ready", "narrow-large", "square-mono", "reduced-motion"]
    function prepare(name) {
      gallery.setTheme(name === "light-ready" ? "light" : name === "square-mono" ? "mono" : "dark")
      Commons.Style.fontBaseSize = name === "narrow-large" ? 15 : 12
      Commons.Style.cornerRadius = name === "square-mono" ? 0 : 12
      Commons.Style.reduceMotion = name === "reduced-motion"
      window.previewWidth = name === "narrow-large" ? 380 : 740
      gallery.longText = name === "narrow-large"
      gallery.row.selected = name === "dark-focus"
      gallery.row.focus = false; gallery.editor.focus = false
      gallery.setMode(name === "reduced-motion" ? "loading" : name.indexOf("dark-") === 0 && name !== "dark-focus" ? name.slice(5) : "ready")
      if (name === "dark-focus") gallery.row.forceActiveFocus()
    }
    Timer {
      id: capture; interval: 100; running: Quickshell.env("ISLAND_DESIGN_CAPTURE") !== ""
      onTriggered: {
        if (window.captureIndex >= window.captures.length) { console.log("PATTERNS_CAPTURE_PASS"); Qt.quit(); return }
        window.prepare(window.captures[window.captureIndex]); settle.start()
      }
    }
    Timer {
      id: settle; interval: 250
      onTriggered: gallery.grabToImage(function(result) {
        if (!result.saveToFile(Quickshell.env("ISLAND_DESIGN_CAPTURE") + "/" + window.captures[window.captureIndex] + ".png")) {console.log("PATTERNS_CAPTURE_FAIL");Qt.quit();return}
        window.captureIndex++; capture.restart()
      })
    }
  }
}
