pragma Singleton
import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "DesignTokens.js" as Tokens

QtObject {
  id: root
  function color(value) { return Qt.rgba(value[0],value[1],value[2],value[3]===undefined ? 1 : value[3]) }
  function fontSize(role) {
    var spec=Tokens.typography[role] || Tokens.typography.body
    return Math.max(1,Math.round(Style.font[spec.source]*(spec.factor || 1)))
  }
  function lineHeight(role) {
    var spec=Tokens.typography[role] || Tokens.typography.body
    return Math.round(fontSize(role)*spec.line/spec.size)
  }
  function weight(role) { return (Tokens.typography[role] || Tokens.typography.body).weight }
  readonly property string fontFamily: Style.font.family
  readonly property var typography: Tokens.typography
  readonly property var spacing: Tokens.spacing
  readonly property QtObject type: QtObject {
    readonly property int caption: root.fontSize("caption")
    readonly property int label: root.fontSize("label")
    readonly property int body: root.fontSize("body")
    readonly property int title: root.fontSize("title")
    readonly property int section: root.fontSize("section")
    readonly property int page: root.fontSize("page")
    readonly property int metric: root.fontSize("metric")
    readonly property int hero: root.fontSize("hero")
    readonly property int bar: root.fontSize("bar")
    readonly property int iconSmall: Style.font.iconSmall
    readonly property int icon: Style.font.icon
    readonly property int iconLarge: Style.font.iconLarge
  }
  readonly property QtObject gap: QtObject {
    readonly property int micro: Style.space(Tokens.spacing.micro)
    readonly property int tight: Style.space(Tokens.spacing.tight)
    readonly property int small: Style.space(Tokens.spacing.small)
    readonly property int medium: Style.space(Tokens.spacing.medium)
    readonly property int large: Style.space(Tokens.spacing.large)
    readonly property int section: Style.space(Tokens.spacing.section)
    readonly property int page: Style.space(Tokens.spacing.page)
    readonly property int spacious: Style.space(Tokens.spacing.spacious)
  }
  readonly property int controlHeight: Math.max(Style.space(Tokens.geometry.control),lineHeight("label")+gap.medium)
  readonly property int compactControlHeight: Math.max(Style.space(Tokens.geometry.compactControl),lineHeight("label")+gap.small)
  readonly property int inlineControlHeight: Math.max(Style.space(24),lineHeight("caption")+gap.tight)
  readonly property int fieldHeight: Math.max(Style.space(Tokens.geometry.field),lineHeight("body")+gap.large)
  readonly property int optionHeight: Style.space(Tokens.geometry.option)
  readonly property int cardPadding: Style.space(Tokens.geometry.cardPadding)
  readonly property int panelPadding: Style.space(Tokens.geometry.panelPadding)
  readonly property real cardRadius: Math.max(0,Style.cornerRadius)
  readonly property real controlRadius: Math.min(cardRadius,Style.space(Tokens.geometry.controlRadius))
  readonly property int feedbackDuration: Preferences.duration(Tokens.motion.feedback)
  readonly property int transitionDuration: Preferences.duration(Tokens.motion.transition)
  readonly property int revealDuration: Preferences.duration(Tokens.motion.reveal)
  readonly property int spinnerDuration: Tokens.motion.spinner
  readonly property real disabledOpacity: 0.45

  // Color owns parsing colors.toml, shell.toml, user overrides and live updates.
  // Island reads it; it never writes the system palette or a private theme file.
  readonly property var popupBorder: Border.surfaceSpec("popups","border",Commons.Color.popups.border,Math.max(1,Style.space(2)))
  readonly property color canvas: Commons.Color.popups.background
  readonly property color opaqueCanvas: color(Tokens.opaque(canvas,Commons.Color.background))
  readonly property color surface: color(Tokens.mix(opaqueCanvas,Commons.Color.popups.text,0.045))
  readonly property color raised: color(Tokens.mix(opaqueCanvas,Commons.Color.popups.text,0.08))
  readonly property color text: color(Tokens.readable(Commons.Color.popups.text,raised,7))
  readonly property color secondaryText: color(Tokens.readable(Commons.Color.muted,raised,4.5))
  readonly property color accent: color(Tokens.readable(Commons.Color.accent,raised,4.5))
  readonly property color info: color(Tokens.readable(ThemePalette.values.blue || Commons.Color.accent,raised,4.5))
  readonly property color success: color(Tokens.readable(ThemePalette.values.green || Commons.Color.accent,raised,4.5))
  readonly property color warning: color(Tokens.readable(ThemePalette.values.yellow || Commons.Color.accent,raised,4.5))
  readonly property color danger: color(Tokens.readable(Commons.Color.urgent,raised,4.5))
  readonly property color onAccent: color(Tokens.readable(opaqueCanvas,accent,4.5))
  readonly property color fieldBorder: color(Tokens.readable(Commons.Color.muted,raised,3))
  readonly property color focusRing: accent
  readonly property color selection: color(Tokens.mix(opaqueCanvas,accent,0.14))
  readonly property color hover: Style.hoverFillFor(text,accent,danger)
  readonly property color pressed: Style.pressedFillFor(text,accent,danger)
  readonly property color selectedText: color(Tokens.readable(accent,selection,4.5))
  readonly property color selectedSecondaryText: color(Tokens.readable(secondaryText,selection,4.5))
  readonly property color barText: Commons.Color.bar.text
  readonly property color barAccent: color(Tokens.readable(Commons.Color.accent,Commons.Color.background,4.5))
  readonly property color barDanger: color(Tokens.readable(Commons.Color.urgent,Commons.Color.background,4.5))
}
