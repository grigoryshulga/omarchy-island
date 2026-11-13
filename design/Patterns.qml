import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import "Island" as Island
import "Island/sdk" 1.0 as UI

Rectangle {
  id: root
  required property var strings
  property string mode: "ready"
  property bool longText: false
  property int actions: 0
  property int rowActions: 0
  property string previewTheme: "system"
  function setTheme(name) {
    var themes = {
      dark: {bg:"#16191d", fg:"#e5e8ed", accent:"#9bb9ff", muted:"#8e98a6", urgent:"#f6a6ad"},
      light: {bg:"#f6f4ef", fg:"#252932", accent:"#335bb1", muted:"#707684", urgent:"#a7344c"},
      mono: {bg:"#111111", fg:"#eeeeee", accent:"#c0c0c0", muted:"#888888", urgent:"#eeeeee"}
    }
    var theme = themes[name]
    if (!theme) return
    Commons.Color.background = theme.bg; Commons.Color.foreground = theme.fg
    Commons.Color.popups.background = theme.bg; Commons.Color.popups.text = theme.fg
    Commons.Color.accent = theme.accent; Commons.Color.muted = theme.muted; Commons.Color.urgent = theme.urgent
    previewTheme = name
  }
  readonly property var editor: address
  readonly property var row: calendarRow
  readonly property var stateView: dataState
  readonly property var fieldView: field
  color: UI.Design.opaqueCanvas
  implicitHeight: content.implicitHeight + 2 * UI.Design.gap.large
  function tr(key) { return strings.t("patterns." + key) }
  function setMode(value) {
    mode = value
    address.text = value === "error" ? "http://calendar.invalid/events" : "https://calendar.example/events.ics"
  }
  ColumnLayout {
    id: content
    x: UI.Design.gap.large; y: x
    width: parent.width - 2 * x
    spacing: UI.Design.gap.section
    UI.SectionHeading { Layout.fillWidth: true; title: root.tr("title"); detail: "SDK 1.0" }
    Flow {
      Layout.fillWidth: true
      spacing: UI.Design.gap.small
      Repeater {
        model: ["ready", "loading", "error", "empty", "disabled"]
        UI.FeedbackButton { required property string modelData; text: root.tr(modelData); compact: true; focusable: true; selected: root.mode === modelData; onClicked: root.setMode(modelData) }
      }
    }
    Flow {
      Layout.fillWidth: true; spacing: UI.Design.gap.small
      Repeater { model:["dark","light","mono"]; UI.FeedbackButton { required property string modelData; compact:true; focusable:true; text:root.strings.t("design."+modelData); selected:root.previewTheme===modelData; onClicked:root.setTheme(modelData) } }
      UI.FeedbackButton { compact:true; focusable:true; text:root.strings.t("design.square"); selected:Commons.Style.cornerRadius===0; onClicked:Commons.Style.cornerRadius=Commons.Style.cornerRadius===0 ? 12 : 0 }
      UI.FeedbackButton { compact:true; focusable:true; text:root.strings.t("design.largeText"); selected:Commons.Style.fontBaseSize===15; onClicked:Commons.Style.fontBaseSize=Commons.Style.fontBaseSize===15 ? 12 : 15 }
      UI.FeedbackButton { compact:true; focusable:true; text:root.strings.t("design.reduceMotion"); selected:Commons.Style.reduceMotion; onClicked:Commons.Style.reduceMotion=!Commons.Style.reduceMotion }
    }
    ColumnLayout {
      Layout.fillWidth: true; spacing: UI.Design.gap.small
      UI.SectionHeading { Layout.fillWidth: true; title: root.tr("rows") }
      UI.ListRow {
        id: calendarRow; objectName: "patternRow"
        Layout.fillWidth: true
        title: root.tr(root.longText ? "long" : "row")
        description: root.tr("description")
        iconText: "▦"
        statusText: root.tr(root.mode === "error" ? "cached" : "connected")
        statusKind: root.mode === "error" ? "warning" : "success"
        interactive: true; enabled: root.mode !== "disabled"
        onClicked: { selected = !selected; root.rowActions++ }
        actions: UI.FeedbackButton { objectName: "patternRowAction"; text: root.tr("edit"); compact: true; focusable: true; onClicked: { root.actions++; field.focusEditor() } }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true; spacing: UI.Design.gap.medium
      UI.SectionHeading { Layout.fillWidth: true; title: root.tr("states") }
      UI.DataState {
        id: dataState
        Layout.fillWidth: true
        kind: root.mode === "ready" || root.mode === "disabled" ? "stale" : root.mode
        title: root.tr(kind + "Title")
        description: root.tr(kind + "Hint")
        actionText: kind === "error" || kind === "stale" ? root.tr("retry") : ""
        actionEnabled: root.mode !== "disabled"
        onActionRequested: { root.actions++; root.setMode("loading") }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true; spacing: UI.Design.gap.small
      UI.SectionHeading { Layout.fillWidth: true; title: root.tr("validation") }
      UI.FormField {
        id: field; Layout.fillWidth: true
        label: root.tr("field"); hint: root.tr("hint")
        error: address.text && !/^https:\/\//.test(address.text) ? root.tr("invalid") : ""
        UI.DesignTextField {
          id: address; objectName: "patternEditor"; Layout.fillWidth: true
          text: "https://calendar.example/events.ics"
          enabled: root.mode !== "disabled" && root.mode !== "loading"
          Accessible.name: field.label; Accessible.description: field.message
          invalid: !!field.error
        }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true; spacing: UI.Design.gap.medium
      UI.SectionHeading { Layout.fillWidth: true; title: root.tr("controls") }
      Flow {
        Layout.fillWidth: true; spacing: UI.Design.gap.small
        UI.FeedbackButton { text: root.tr("primary"); variant: "primary"; focusable: true; enabled: root.mode !== "disabled" && root.mode !== "loading" && !field.error; onClicked: root.actions++ }
        UI.FeedbackButton { text: root.tr("secondary"); variant: "soft"; focusable: true; onClicked: root.actions++ }
        UI.FeedbackButton { text: root.tr("quiet"); focusable: true; onClicked: root.setMode("ready") }
        UI.ControlSwitch { objectName: "patternSwitch"; checked: true; enabled: root.mode !== "disabled"; onToggled: checked = !checked; Accessible.name: root.tr("switch") }
      }
      UI.IslandSlider { id: slider; Layout.fillWidth: true; value: 0.65; enabled: root.mode !== "disabled"; onMoved: next => slider.value = next }
      UI.DesignDropdown { id: dropdown; Layout.fillWidth: true; enabled: root.mode !== "disabled"; value: "ready"; options: [{value:"ready",label:root.tr("ready")},{value:"loading",label:root.tr("loading")},{value:"error",label:root.tr("error")}]; onChanged: next => { value = next; root.setMode(next) } }
      UI.PlainText { Layout.fillWidth: true; typeRole: "caption"; color: UI.Design.secondaryText; text: root.actions || root.rowActions ? root.tr("activated") + " · " + Commons.I18n.formatNumber(root.actions + root.rowActions) : " "; wrapMode: Text.Wrap }
    }
  }
}
